import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';

/// Source attribution for a config value.
enum ConfigValueSource { remote, defaultValue, forced, lastGood }

extension ConfigValueSourceWire on ConfigValueSource {
  String get wire {
    switch (this) {
      case ConfigValueSource.remote:
        return 'remote';
      case ConfigValueSource.defaultValue:
        return 'default';
      case ConfigValueSource.forced:
        return 'forced';
      case ConfigValueSource.lastGood:
        return 'last_good';
    }
  }
}

/// Wraps [FirebaseAnalytics] with the remote-config event vocabulary
/// described in the prompt's section C.5.
///
/// All emits are fire-and-forget — analytics failures must never block
/// gameplay. Use [logFetch], [logActivated], [logParseError],
/// [logSchemaMismatch], [logValueUsed], [logVariantAssigned].
class ConfigAnalytics {
  ConfigAnalytics({FirebaseAnalytics? analytics, Duration? dedupeWindow})
      : _analytics = analytics ?? FirebaseAnalytics.instance,
        _dedupeWindow = dedupeWindow ?? const Duration(seconds: 60);

  final FirebaseAnalytics _analytics;
  final Duration _dedupeWindow;

  /// In-memory dedupe map for `config_value_used`: tuple -> last emit time.
  final Map<String, DateTime> _valueUsedLastEmit = <String, DateTime>{};

  /// Set of experiment keys already reported for variant assignment this
  /// session.
  final Set<String> _variantsAssigned = <String>{};

  Future<void> logFetch({
    required bool success,
    required int durationMs,
    required String source,
    String? errorCode,
  }) {
    return _safe(() => _analytics.logEvent(
          name: 'remote_config_fetch',
          parameters: <String, Object>{
            'success': success ? 1 : 0,
            'duration_ms': durationMs,
            'source': source,
            if (errorCode != null) 'error_code': errorCode,
          },
        ));
  }

  Future<void> logActivated({
    required Map<String, int> schemaVersions,
    int? templateVersion,
  }) {
    return _safe(() => _analytics.logEvent(
          name: 'remote_config_activated',
          parameters: <String, Object>{
            'schema_versions': json.encode(schemaVersions),
            if (templateVersion != null)
              'config_template_version': templateVersion,
          },
        ));
  }

  Future<void> logParseError({
    required String namespace,
    int? schemaVersionSeen,
    required String error,
  }) {
    return _safe(() => _analytics.logEvent(
          name: 'remote_config_parse_error',
          parameters: <String, Object>{
            'namespace': namespace,
            if (schemaVersionSeen != null)
              'schema_version_seen': schemaVersionSeen,
            'error': _truncate(error, 100),
          },
        ));
  }

  Future<void> logSchemaMismatch({
    required String namespace,
    required int schemaVersionSeen,
    required int schemaVersionSupported,
  }) {
    return _safe(() => _analytics.logEvent(
          name: 'remote_config_schema_mismatch',
          parameters: <String, Object>{
            'namespace': namespace,
            'schema_version_seen': schemaVersionSeen,
            'schema_version_supported': schemaVersionSupported,
          },
        ));
  }

  /// Emit `config_value_used`. Dedupes identical (key, source, context)
  /// tuples to once per [_dedupeWindow] per session.
  Future<void> logValueUsed({
    required String key,
    required ConfigValueSource source,
    String? context,
  }) {
    final tuple = '$key|${source.wire}|${context ?? ''}';
    final now = DateTime.now();
    final last = _valueUsedLastEmit[tuple];
    if (last != null && now.difference(last) < _dedupeWindow) {
      return Future<void>.value();
    }
    _valueUsedLastEmit[tuple] = now;
    return _safe(() => _analytics.logEvent(
          name: 'config_value_used',
          parameters: <String, Object>{
            'key': key,
            'source': source.wire,
            if (context != null) 'context': context,
          },
        ));
  }

  /// Emit `ab_variant_assigned` only once per experiment per session.
  Future<void> logVariantAssigned({
    required String experiment,
    required String variant,
    required ConfigValueSource source,
  }) {
    if (_variantsAssigned.contains(experiment)) {
      return Future<void>.value();
    }
    _variantsAssigned.add(experiment);
    return _safe(() => _analytics.logEvent(
          name: 'ab_variant_assigned',
          parameters: <String, Object>{
            'experiment': experiment,
            'variant': variant,
            'source': source.wire,
          },
        ));
  }

  /// Drop session-scoped dedupe state. Call on logout or A/B reset.
  void resetSession() {
    _valueUsedLastEmit.clear();
    _variantsAssigned.clear();
  }

  Future<void> _safe(Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      developer.log(
        'analytics emit failed: $e',
        name: 'remote_config',
        level: 700,
        error: e,
        stackTrace: st,
      );
    }
  }

  String _truncate(String s, int n) =>
      s.length <= n ? s : s.substring(0, n);
}
