import '../constants/power_up_catalog.dart';

/// Pure-function pack-discount pricing for power-up purchases — GDD §2.6.
class PackPricing {
  PackPricing._();

  /// Returns the discounted total coin price for [packSize] units of the
  /// power-up identified by [powerUpId]. Falls back to undiscounted
  /// (size-1) pricing for unknown sizes.
  ///
  /// Throws [ArgumentError] for an unknown [powerUpId] — silently
  /// returning 0 historically let typo'd ids ship as free packs.
  /// Throws [ArgumentError] for non-positive [packSize].
  static int totalPrice({
    required String powerUpId,
    required int packSize,
  }) {
    if (packSize <= 0) {
      throw ArgumentError.value(packSize, 'packSize', 'must be > 0');
    }
    final unit = PowerUpCatalog.singlePrice[powerUpId];
    if (unit == null) {
      throw ArgumentError.value(powerUpId, 'powerUpId', 'unknown power-up id');
    }
    final discount = PowerUpCatalog.packDiscounts[packSize] ??
        PowerUpCatalog.packDiscounts[1]!;
    return ((unit * packSize) * (1 - discount)).floor();
  }

  /// Best-effort variant for diagnostic UIs that want to display a
  /// price without crashing on an unknown id (e.g. debug overlay).
  /// Returns null if [powerUpId] isn't in the catalog.
  static int? totalPriceOrNull({
    required String powerUpId,
    required int packSize,
  }) {
    if (packSize <= 0 || !PowerUpCatalog.singlePrice.containsKey(powerUpId)) {
      return null;
    }
    return totalPrice(powerUpId: powerUpId, packSize: packSize);
  }
}
