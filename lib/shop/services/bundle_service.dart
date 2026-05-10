import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/player_segment.dart';
import '../models/shop_bundle.dart';
import 'bundle_cache.dart';
import 'bundle_repository.dart';
import 'bundle_validator.dart';
import 'segment_evaluator.dart';

/// Public face of the shop bundle subsystem. The UI layer subscribes to this
/// (via Provider/[ChangeNotifier]) and reads [visibleBundles].
class BundleService extends ChangeNotifier {
  final BundleRepository repository;
  final BundleValidator validator;
  final SegmentEvaluator evaluator;
  final BundleCache cache;

  /// How fresh the persistent cache must be to render before we even fetch.
  /// Older snapshots still show but trigger a foreground refresh.
  final Duration freshThreshold;

  StreamSubscription<List<ShopBundle>>? _watchSub;
  Timer? _expiryTicker;
  PlayerSegmentData _player = PlayerSegmentData.anonymous;
  List<ShopBundle> _allValidatedBundles = const [];
  List<ShopBundle> _visibleBundles = const [];
  bool _initialized = false;

  /// True while a fetch is in progress. UI uses this to pick between
  /// skeleton placeholders and rendered cards.
  bool isLoading = false;

  /// Last error message surfaced to the UI as a thin banner. The cache
  /// keeps showing whatever it has — the shop never goes blank when a
  /// fetch fails.
  String? lastError;

  BundleService({
    required this.repository,
    required this.validator,
    required this.evaluator,
    required this.cache,
    this.freshThreshold = const Duration(hours: 24),
  });

  /// Bundles the player should currently see, sorted by `priority` desc.
  List<ShopBundle> get visibleBundles => _visibleBundles;

  /// All validated bundles before segment filtering. Useful for the debug
  /// overlay's "switch segment" verification.
  List<ShopBundle> get allValidatedBundles => _allValidatedBundles;

  /// Last known player snapshot used by [SegmentEvaluator]. Updated on
  /// every successful fetch and on debug overlay segment switches.
  PlayerSegmentData get player => _player;

  /// Bootstraps the service. Idempotent — safe to call multiple times
  /// (e.g. on tab re-mount). Calling again triggers a refresh, not a
  /// duplicate watcher.
  Future<void> initialize() async {
    if (_initialized) {
      await refresh();
      return;
    }
    _initialized = true;

    // 1. In-memory cache — instant render.
    final mem = cache.readMemory();
    if (mem != null && mem.isNotEmpty) {
      _allValidatedBundles = mem;
      _recomputeVisible();
      notifyListeners();
    }

    // 2. Persistent cache — fall back if nothing in memory. Always run
    // through the validator: a corrupted snapshot can yield empty-id /
    // empty-content bundles whose keep-warm render would otherwise
    // bypass schema enforcement until the next foreground fetch.
    if (_visibleBundles.isEmpty) {
      try {
        final persisted = await cache.readPersistent();
        if (persisted != null && persisted.isNotEmpty) {
          _allValidatedBundles = validator.filterValid(persisted);
          _recomputeVisible();
          notifyListeners();
        }
      } catch (e) {
        // Cache reads must never crash the shop. Log and continue.
        if (kDebugMode) {
          // ignore: avoid_print
          print('[BUNDLE_CACHE_READ_FAIL] $e');
        }
      }
    }

    // 3. Foreground fetch.
    await refresh();

    // 4. Hot-reload subscription — every emit replays validate/filter.
    _watchSub = repository.watchActiveBundles().listen(
      (bundles) async {
        await _ingest(bundles);
      },
      onError: (Object e) {
        lastError = e.toString();
        notifyListeners();
      },
    );

    // 5. Periodic expiry sweep — `_inTimeWindow` is otherwise only
    // re-evaluated on stream emission, leaving bundles whose `endsAt`
    // passes mid-session purchasable until the next poll. A 30-second
    // tick keeps the visible list aligned with wall-clock without
    // hammering the segment evaluator.
    _expiryTicker?.cancel();
    _expiryTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _recomputeAndNotify(),
    );
  }

  /// Forces a fresh fetch + validation + filter cycle. Surfaces errors via
  /// [lastError] but never empties the visible list when a cache exists.
  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    try {
      final bundles = await repository.fetchActiveBundles();
      _player = await repository.fetchPlayerSegments();
      await _ingest(bundles);
      lastError = null;
    } catch (e) {
      lastError = e.toString();
      // Keep showing whatever's already in memory.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Attempts to purchase [bundleId]. Returns true on success. Records the
  /// purchase via the repository and re-runs the segment filter so any
  /// single-purchase bundles drop out of the list.
  Future<bool> attemptPurchase(String bundleId) async {
    try {
      await repository.recordPurchase(bundleId);
      // Re-fetch player so the updated purchase history is visible to
      // SegmentEvaluator; bundles list itself can stay cached.
      _player = await repository.fetchPlayerSegments();
      _recomputeVisible();
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'Purchase failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Replaces the player's active segments (debug overlay) and re-renders.
  /// Persists the override so a hot restart keeps the test state.
  Future<void> debugSetSegments(List<String>? segments) async {
    final dynamic repo = repository;
    if (repo is DebugSegmentSetter) {
      await repo.persistSegmentOverride(segments);
    }
    _player = _player.withSegments(segments ?? const []);
    _recomputeVisible();
    notifyListeners();
  }

  /// Validates [bundles], stores them in caches, and recomputes the
  /// visible list. Shared between initial fetch and watch-stream emissions.
  Future<void> _ingest(List<ShopBundle> bundles) async {
    _allValidatedBundles = validator.filterValid(bundles);
    cache.writeMemory(_allValidatedBundles);
    try {
      await cache.writePersistent(_allValidatedBundles);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[BUNDLE_CACHE_WRITE_FAIL] $e');
      }
    }
    // A successful ingest implicitly clears any stale failure banner —
    // otherwise a transient fetch error sticks until the next refresh().
    lastError = null;
    _recomputeVisible();
    notifyListeners();
  }

  void _recomputeVisible() {
    _visibleBundles = evaluator.filter(_allValidatedBundles, _player);
  }

  void _recomputeAndNotify() {
    final before = _visibleBundles;
    _recomputeVisible();
    // Only notify when the result actually changes — avoids waking up
    // every BundlePriceButton/Countdown widget every 30 s for nothing.
    if (!identical(before, _visibleBundles) &&
        !_listsEqual(before, _visibleBundles)) {
      notifyListeners();
    }
  }

  bool _listsEqual(List<ShopBundle> a, List<ShopBundle> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i]) && a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    _expiryTicker = null;
    _watchSub?.cancel();
    _watchSub = null;
    repository.dispose();
    super.dispose();
  }
}

