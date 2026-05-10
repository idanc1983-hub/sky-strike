import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_bundle.dart';

/// Two-layer cache for the bundle list.
///
/// * In-memory: instant snapshot for synchronous renders.
/// * Persistent ([SharedPreferences]): survives restarts; capped at 7 days
///   so stale records eventually expire.
///
/// The service writes both layers on every successful fetch, and reads
/// memory first, persistent second when its initial render needs a value.
class BundleCache {
  static const _prefsKey = 'shop.bundle.cache';
  static const _maxAgePersistent = Duration(days: 7);

  List<ShopBundle>? _memory;
  DateTime? _persistedAt;

  /// Returns the in-memory snapshot or `null` if nothing has been stored
  /// yet this session.
  List<ShopBundle>? readMemory() => _memory;

  /// Writes [bundles] to the in-memory cache. Does not touch persistent.
  void writeMemory(List<ShopBundle> bundles) {
    _memory = List.unmodifiable(bundles);
  }

  /// Reads the persisted snapshot. Returns `null` if missing or older
  /// than [_maxAgePersistent].
  Future<List<ShopBundle>?> readPersistent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final tsRaw = decoded['persistedAt'] as int?;
    final list = decoded['bundles'];
    if (tsRaw == null || list is! List) return null;
    final persistedAt = DateTime.fromMillisecondsSinceEpoch(tsRaw);
    _persistedAt = persistedAt;
    final age = DateTime.now().difference(persistedAt);
    if (age > _maxAgePersistent) return null;
    final bundles = list
        .whereType<Map<String, dynamic>>()
        .map(ShopBundle.fromJson)
        .toList();
    return bundles;
  }

  /// Writes [bundles] to persistent storage atomically (single
  /// `setString`).
  Future<void> writePersistent(List<ShopBundle> bundles) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    _persistedAt = now;
    final payload = json.encode({
      'persistedAt': now.millisecondsSinceEpoch,
      'bundles': bundles.map((b) => b.toJson()).toList(),
    });
    await prefs.setString(_prefsKey, payload);
  }

  /// Whether the persisted snapshot is older than [maxAge]. Returns true
  /// when nothing has been persisted yet (stale ⇒ should refresh).
  bool isStale(Duration maxAge) {
    if (_persistedAt == null) return true;
    return DateTime.now().difference(_persistedAt!) > maxAge;
  }

  /// Clears both layers — useful from the debug overlay or tests.
  Future<void> clear() async {
    _memory = null;
    _persistedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
