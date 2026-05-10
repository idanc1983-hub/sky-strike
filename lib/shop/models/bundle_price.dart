/// Price kind: in-game gems vs platform IAP.
enum BundlePriceType { gems, iap }

extension BundlePriceTypeJson on BundlePriceType {
  String get jsonValue =>
      this == BundlePriceType.gems ? 'gems' : 'iap';

  static BundlePriceType? fromJsonValue(String? raw) {
    switch (raw) {
      case 'gems':
        return BundlePriceType.gems;
      case 'iap':
        return BundlePriceType.iap;
      default:
        return null;
    }
  }
}

/// Cost record for a [ShopBundle]. Either `gemCost` (when type==gems) or
/// `iapProductId` (when type==iap) is populated; the other is null.
/// Compare-prices are optional and shown as strikethrough when present.
class BundlePrice {
  final BundlePriceType type;
  final int? gemCost;
  final String? iapProductId;
  final double? usdEquivalent;
  final int? compareGems;
  final double? compareUsd;

  const BundlePrice({
    required this.type,
    this.gemCost,
    this.iapProductId,
    this.usdEquivalent,
    this.compareGems,
    this.compareUsd,
  });

  /// Whether this bundle has a strikethrough "compare" price (used to
  /// compute "%" off badges).
  bool get hasCompare =>
      (type == BundlePriceType.gems && compareGems != null) ||
      (type == BundlePriceType.iap && compareUsd != null);

  /// Discount percent based on compare vs actual. Returns `null` when no
  /// compare price is set or the math doesn't yield a positive discount.
  int? get percentOff {
    if (type == BundlePriceType.gems &&
        compareGems != null &&
        gemCost != null &&
        compareGems! > gemCost!) {
      return ((1 - gemCost! / compareGems!) * 100).round();
    }
    if (type == BundlePriceType.iap &&
        compareUsd != null &&
        usdEquivalent != null &&
        compareUsd! > usdEquivalent!) {
      return ((1 - usdEquivalent! / compareUsd!) * 100).round();
    }
    return null;
  }

  factory BundlePrice.fromJson(Map<String, dynamic> json) {
    final parsedType = BundlePriceTypeJson.fromJsonValue(
          json['type'] as String?,
        ) ??
        BundlePriceType.gems;
    return BundlePrice(
      type: parsedType,
      gemCost: (json['gemCost'] as num?)?.toInt(),
      iapProductId: json['iapProductId'] as String?,
      usdEquivalent: (json['usdEquivalent'] as num?)?.toDouble(),
      compareGems: (json['compareGems'] as num?)?.toInt(),
      compareUsd: (json['compareUsd'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        if (gemCost != null) 'gemCost': gemCost,
        if (iapProductId != null) 'iapProductId': iapProductId,
        if (usdEquivalent != null) 'usdEquivalent': usdEquivalent,
        if (compareGems != null) 'compareGems': compareGems,
        if (compareUsd != null) 'compareUsd': compareUsd,
      };
}
