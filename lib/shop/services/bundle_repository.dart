import '../models/player_segment.dart';
import '../models/shop_bundle.dart';

/// Thrown by repository implementations when a fetch fails. The service
/// layer catches this and falls back to the cache.
class BundleFetchException implements Exception {
  final String message;
  final Object? cause;
  const BundleFetchException(this.message, {this.cause});

  @override
  String toString() => 'BundleFetchException: $message';
}

/// Backend-agnostic surface for the bundle service. Real implementations:
///   - [MockBundleRepository] (assets-driven, default)
///   - `FirebaseBundleRepository` (future, swap-in)
abstract class BundleRepository {
  /// Returns the raw active-bundle list. May include records that fail
  /// validation; the service runs them through [BundleValidator] before
  /// rendering.
  Future<List<ShopBundle>> fetchActiveBundles();

  /// Returns the segment record for the current player. Anonymous fallback
  /// is the implementation's responsibility.
  Future<PlayerSegmentData> fetchPlayerSegments();

  /// Records a successful purchase so [SegmentEvaluator] can enforce
  /// `purchaseLimit` / cooldown across app restarts.
  Future<void> recordPurchase(String bundleId);

  /// Hot-reload stream — emits the latest bundle list each time the
  /// repository's polling tick fires (or whenever a real backend pushes).
  Stream<List<ShopBundle>> watchActiveBundles();

  /// Releases timers and stream controllers. Safe to call multiple times.
  void dispose();
}

/// Optional capability: repository can persist a debug-overlay segment
/// switch. The mock implementation supports this; a real Firebase one
/// might not. The service feature-detects this at runtime.
abstract class DebugSegmentSetter {
  /// Persists [segments] as the active segment override, or clears it
  /// when [segments] is null.
  Future<void> persistSegmentOverride(List<String>? segments);
}
