import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_segment.dart';
import '../models/shop_bundle.dart';
import 'bundle_repository.dart';

/// Local-asset-driven bundle backend used for development and tests.
///
/// Reads the JSON files under `assets/mock_backend/`, simulates network
/// latency and optional failures, and persists `recordPurchase` calls to
/// [SharedPreferences] so purchase limits/cooldowns survive app restarts.
///
/// **Firebase swap point:** replace this class with a Firestore-backed one;
/// the [BundleRepository] interface stays identical, so [BundleService]
/// changes nothing.
class MockBundleRepository implements BundleRepository, DebugSegmentSetter {
  static const _bundlesPath = 'assets/mock_backend/bundles_active.json';
  static const _segmentsPath = 'assets/mock_backend/player_segments.json';
  static const _prefsPurchasesKey = 'shop.bundle.purchases';
  static const _prefsSegmentOverrideKey = 'shop.bundle.segment_override';

  final Random _rng = Random();
  Duration _latency = const Duration(milliseconds: 0);
  bool _failureMode = false;
  Duration _pollInterval = const Duration(minutes: 5);

  Timer? _pollTimer;
  StreamController<List<ShopBundle>>? _watchController;

  /// Override segments returned by [fetchPlayerSegments] without writing
  /// to disk. Used by the debug overlay to flip live-ops profiles.
  List<String>? _activeSegmentsOverride;

  /// Replaces simulated network latency. Useful in tests to make awaits
  /// deterministic. Default: 200–600 ms randomized when unset.
  void setLatency(Duration latency) {
    _latency = latency;
  }

  /// When true, every fetch throws a [BundleFetchException]. Used to test
  /// the cache-fallback path.
  void setFailureMode(bool fail) {
    _failureMode = fail;
  }

  /// Replaces the watch-stream poll interval (default 5 min). Tests pass
  /// short durations to verify the hot-reload path.
  void setPollInterval(Duration interval) {
    _pollInterval = interval;
    if (_pollTimer != null) {
      _pollTimer!.cancel();
      _startPolling();
    }
  }

  /// Hot-swap the active player's segment list for [fetchPlayerSegments].
  /// Pass `null` to fall back to the JSON file's value.
  void setActiveSegments(List<String>? segments) {
    _activeSegmentsOverride = segments;
  }

  Future<void> _simulateLatency() async {
    final ms = _latency == Duration.zero
        ? 200 + _rng.nextInt(400)
        : _latency.inMilliseconds;
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<List<ShopBundle>> fetchActiveBundles() async {
    await _simulateLatency();
    if (_failureMode) {
      throw const BundleFetchException('mock fetch disabled');
    }
    final raw = await rootBundle.loadString(_bundlesPath);
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const BundleFetchException('bundles_active.json not an object');
    }
    final list = (decoded['bundles'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ShopBundle.fromJson)
        .toList();
  }

  @override
  Future<PlayerSegmentData> fetchPlayerSegments() async {
    await _simulateLatency();
    if (_failureMode) {
      throw const BundleFetchException('mock fetch disabled');
    }
    final raw = await rootBundle.loadString(_segmentsPath);
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      return PlayerSegmentData.anonymous;
    }
    final base = PlayerSegmentData.fromJson(decoded);
    final purchases = await _loadPersistedPurchases();
    final segments = _activeSegmentsOverride ??
        await _loadPersistedSegmentOverride() ??
        base.segments;
    return PlayerSegmentData(
      playerId: base.playerId,
      segments: segments,
      level: base.level,
      totalSpendUsd: base.totalSpendUsd,
      lastActiveDaysAgo: base.lastActiveDaysAgo,
      bundlePurchases: purchases,
      ownedJets: base.ownedJets,
      completedWorld: base.completedWorld,
    );
  }

  @override
  Future<void> recordPurchase(String bundleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsPurchasesKey);
    final Map<String, dynamic> map = raw == null
        ? <String, dynamic>{}
        : (json.decode(raw) as Map<String, dynamic>? ?? <String, dynamic>{});
    final list = (map[bundleId] as List?) ?? [];
    list.add(DateTime.now().millisecondsSinceEpoch);
    map[bundleId] = list;
    await prefs.setString(_prefsPurchasesKey, json.encode(map));
  }

  @override
  Stream<List<ShopBundle>> watchActiveBundles() {
    _watchController ??= StreamController<List<ShopBundle>>.broadcast(
      onListen: _startPolling,
      onCancel: () {
        _pollTimer?.cancel();
        _pollTimer = null;
      },
    );
    return _watchController!.stream;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      try {
        final bundles = await fetchActiveBundles();
        _watchController?.add(bundles);
      } catch (e) {
        _watchController?.addError(e);
      }
    });
  }

  Future<Map<String, List<int>>> _loadPersistedPurchases() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsPurchasesKey);
    if (raw == null) return {};
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) return {};
    final out = <String, List<int>>{};
    decoded.forEach((k, v) {
      if (v is List) {
        out[k] = v.whereType<num>().map((n) => n.toInt()).toList();
      }
    });
    return out;
  }

  Future<List<String>?> _loadPersistedSegmentOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsSegmentOverrideKey);
    return raw;
  }

  /// Persists a debug-overlay segment switch to [SharedPreferences] so it
  /// survives a hot restart while testing live-ops.
  @override
  Future<void> persistSegmentOverride(List<String>? segments) async {
    final prefs = await SharedPreferences.getInstance();
    if (segments == null) {
      await prefs.remove(_prefsSegmentOverrideKey);
    } else {
      await prefs.setStringList(_prefsSegmentOverrideKey, segments);
    }
    _activeSegmentsOverride = segments;
  }

  /// Clears the persisted purchase history. Useful for resetting test
  /// scenarios; not exposed to players.
  Future<void> clearPurchaseHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPurchasesKey);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _watchController?.close();
    _watchController = null;
  }
}
