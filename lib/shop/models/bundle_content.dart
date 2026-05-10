/// Discriminator for the kind of reward inside a [ShopBundle].
enum BundleContentType { gems, coins, powerup, jet, jetSkin, xpBoost }

/// Map a [BundleContentType] to its server JSON tag (snake_case).
extension BundleContentTypeJson on BundleContentType {
  String get jsonValue {
    switch (this) {
      case BundleContentType.gems:
        return 'gems';
      case BundleContentType.coins:
        return 'coins';
      case BundleContentType.powerup:
        return 'powerup';
      case BundleContentType.jet:
        return 'jet';
      case BundleContentType.jetSkin:
        return 'jet_skin';
      case BundleContentType.xpBoost:
        return 'xp_boost';
    }
  }

  /// Parses a JSON tag back into a [BundleContentType]. Returns `null` for
  /// unknown values so the validator can drop the record.
  static BundleContentType? fromJsonValue(String? raw) {
    switch (raw) {
      case 'gems':
        return BundleContentType.gems;
      case 'coins':
        return BundleContentType.coins;
      case 'powerup':
        return BundleContentType.powerup;
      case 'jet':
        return BundleContentType.jet;
      case 'jet_skin':
        return BundleContentType.jetSkin;
      case 'xp_boost':
        return BundleContentType.xpBoost;
      default:
        return null;
    }
  }
}

/// Content types whose `itemId` must be non-null (the player needs to know
/// *which* power-up / jet / skin they're getting).
const Set<BundleContentType> kItemIdRequiredTypes = {
  BundleContentType.powerup,
  BundleContentType.jet,
  BundleContentType.jetSkin,
};

/// One reward line inside a bundle.
class BundleContent {
  final BundleContentType type;
  final String? itemId;
  final int count;
  final String iconAsset;

  /// The raw `type` token from the source JSON, or `null` for entries
  /// that were constructed in-code. The validator compares this against
  /// [type]'s `jsonValue` to detect unknown discriminators that would
  /// have silently mapped to `gems`.
  final String? rawType;

  const BundleContent({
    required this.type,
    required this.count,
    required this.iconAsset,
    this.itemId,
    this.rawType,
  });

  /// Whether `itemId` is mandatory for this content's type per game rules.
  bool get requiresItemId => kItemIdRequiredTypes.contains(type);

  /// Whether the raw JSON token failed to map to a known [BundleContentType].
  bool get hasUnknownType {
    if (rawType == null) return false;
    return BundleContentTypeJson.fromJsonValue(rawType) == null;
  }

  /// Parses a [BundleContent] from JSON. The original `type` token is
  /// preserved on the entry's [rawType] so the validator can see when
  /// the JSON shipped an unknown discriminator (defaulting silently to
  /// `gems` would let a misspelled "premium_currency" tag ship as 500
  /// gems with no signal that the upstream data is wrong).
  factory BundleContent.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    final parsedType =
        BundleContentTypeJson.fromJsonValue(rawType) ?? BundleContentType.gems;
    return BundleContent(
      type: parsedType,
      itemId: json['itemId'] as String?,
      count: (json['count'] as num?)?.toInt() ?? 0,
      iconAsset: (json['iconAsset'] as String?) ?? '',
      rawType: rawType,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        if (itemId != null) 'itemId': itemId,
        'count': count,
        'iconAsset': iconAsset,
      };
}
