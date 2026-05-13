import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// QA / debug override layer that takes precedence over remote + default
/// values for feature flags, kill switches, and A/B experiments.
///
/// Storage is a single JSON-encoded `Map<String,String>` under the
/// `forced_variants` key in [SharedPreferences].
///
/// Only active when [kDebugMode] is true OR the build was launched with
/// `--dart-define=ENABLE_QA_OVERRIDES=true`. In release builds without
/// that define, all setters are no-ops and [all] is empty.
class ForcedVariants {
  static const String _prefsKey = 'forced_variants';
  static const bool _enableInRelease = bool.fromEnvironment(
    'ENABLE_QA_OVERRIDES',
    defaultValue: false,
  );

  ForcedVariants._(this._prefs, this._cache);

  final SharedPreferences _prefs;
  final Map<String, String> _cache;

  /// True when forced overrides are honored. Always true in debug mode.
  static bool get isEnabled => kDebugMode || _enableInRelease;

  static ForcedVariants? _instance;
  static ForcedVariants get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'ForcedVariants.instance accessed before init(). '
        'Call ForcedVariants.init() during app startup.',
      );
    }
    return i;
  }

  /// Initialize the singleton. Safe to call multiple times.
  static Future<ForcedVariants> init() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    final cache = <String, String>{};
    if (isEnabled) {
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (k is String && v is String) cache[k] = v;
            });
          }
        } catch (e) {
          developer.log(
            'failed to decode forced_variants: $e',
            name: 'remote_config',
            level: 900,
          );
        }
      }
    }
    _instance = ForcedVariants._(prefs, cache);
    return _instance!;
  }

  /// Read-only snapshot of all active overrides.
  Map<String, String> get all =>
      isEnabled ? Map.unmodifiable(_cache) : const <String, String>{};

  /// Returns the forced value for [key] when overrides are enabled and a
  /// value is set; null otherwise.
  String? get(String key) {
    if (!isEnabled) return null;
    return _cache[key];
  }

  /// Set the forced value for [key]. No-op when overrides are disabled.
  Future<void> setForced(String key, String value) async {
    if (!isEnabled) return;
    _cache[key] = value;
    await _persist();
  }

  /// Remove the forced value for [key]. No-op when overrides are disabled.
  Future<void> clearForced(String key) async {
    if (!isEnabled) return;
    _cache.remove(key);
    await _persist();
  }

  /// Wipe every forced value. No-op when overrides are disabled.
  Future<void> clearAllForced() async {
    if (!isEnabled) return;
    _cache.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_prefsKey, json.encode(_cache));
  }

  /// Test-only: reset the singleton so init() can run again.
  static void resetForTests() {
    _instance = null;
  }

  /// Test-only: inject a pre-built instance (skips SharedPreferences IO).
  static void installForTests(ForcedVariants instance) {
    _instance = instance;
  }

  /// Test-only ctor — bypasses SharedPreferences. Use with
  /// [installForTests].
  @visibleForTesting
  static ForcedVariants makeForTests(
      SharedPreferences prefs, Map<String, String> seed) {
    return ForcedVariants._(prefs, Map<String, String>.from(seed));
  }
}
