import 'bundle_content.dart';
import 'bundle_price.dart';
import 'bundle_theme.dart';

/// Type of player-state gate that a bundle can declare.
enum PrerequisiteType { minLevel, ownsJet, completedWorld, minSpend }

extension PrerequisiteTypeJson on PrerequisiteType {
  String get jsonValue {
    switch (this) {
      case PrerequisiteType.minLevel:
        return 'min_level';
      case PrerequisiteType.ownsJet:
        return 'owns_jet';
      case PrerequisiteType.completedWorld:
        return 'completed_world';
      case PrerequisiteType.minSpend:
        return 'min_spend';
    }
  }

  static PrerequisiteType? fromJsonValue(String? raw) {
    switch (raw) {
      case 'min_level':
        return PrerequisiteType.minLevel;
      case 'owns_jet':
        return PrerequisiteType.ownsJet;
      case 'completed_world':
        return PrerequisiteType.completedWorld;
      case 'min_spend':
        return PrerequisiteType.minSpend;
      default:
        return null;
    }
  }
}

/// One gating rule attached to a bundle.
class BundlePrerequisite {
  final PrerequisiteType type;
  final dynamic value;

  /// The raw `type` token from the source JSON — preserved so the
  /// validator can detect unknown discriminators that would otherwise
  /// silently default to `min_level` and gate the bundle by a wrong
  /// rule.
  final String? rawType;

  const BundlePrerequisite({
    required this.type,
    required this.value,
    this.rawType,
  });

  /// Whether the raw JSON token failed to map to a known
  /// [PrerequisiteType].
  bool get hasUnknownType {
    if (rawType == null) return false;
    return PrerequisiteTypeJson.fromJsonValue(rawType) == null;
  }

  factory BundlePrerequisite.fromJson(Map<String, dynamic> json) {
    final raw = json['type'] as String?;
    final t = PrerequisiteTypeJson.fromJsonValue(raw);
    return BundlePrerequisite(
      type: t ?? PrerequisiteType.minLevel,
      value: json['value'],
      rawType: raw,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.jsonValue,
        'value': value,
      };
}

/// The canonical bundle record. Every field maps 1:1 to the server JSON
/// shape so swapping the mock for Firebase later is a one-class change.
class ShopBundle {
  final String id;
  final String localizationKey;
  final BundleTheme theme;
  final List<BundleContent> contents;
  final BundlePrice price;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<String> targetSegments;
  final int? purchaseLimit;
  final int? cooldownAfterPurchaseHours;
  final int priority;
  final List<String> assetManifest;
  final String? experimentKey;
  final String analyticsTag;
  final List<BundlePrerequisite> prerequisites;
  final String? badgeText;

  const ShopBundle({
    required this.id,
    required this.localizationKey,
    required this.theme,
    required this.contents,
    required this.price,
    required this.startsAt,
    required this.endsAt,
    required this.targetSegments,
    required this.priority,
    required this.assetManifest,
    required this.analyticsTag,
    required this.prerequisites,
    this.purchaseLimit,
    this.cooldownAfterPurchaseHours,
    this.experimentKey,
    this.badgeText,
  });

  /// Parses a bundle from server JSON. **Never throws** — missing or
  /// malformed fields yield a record that fails [BundleValidator] instead
  /// of crashing the app on launch. See validator for which fields are
  /// required for a record to ship to the player.
  factory ShopBundle.fromJson(Map<String, dynamic> json) {
    final themeJson = json['theme'];
    final priceJson = json['price'];
    return ShopBundle(
      id: (json['id'] as String?) ?? '',
      localizationKey: (json['localizationKey'] as String?) ?? '',
      theme: themeJson is Map<String, dynamic>
          ? BundleTheme.fromJson(themeJson)
          : BundleTheme.fromJson(const {}),
      contents: ((json['contents'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BundleContent.fromJson)
          .toList(),
      price: priceJson is Map<String, dynamic>
          ? BundlePrice.fromJson(priceJson)
          : BundlePrice.fromJson(const {}),
      startsAt: _parseDate(json['startsAt']),
      endsAt: _parseDate(json['endsAt']),
      targetSegments: ((json['targetSegments'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      purchaseLimit: (json['purchaseLimit'] as num?)?.toInt(),
      cooldownAfterPurchaseHours:
          (json['cooldownAfterPurchaseHours'] as num?)?.toInt(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      assetManifest: ((json['assetManifest'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      experimentKey: json['experimentKey'] as String?,
      analyticsTag: (json['analyticsTag'] as String?) ?? '',
      prerequisites: ((json['prerequisites'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BundlePrerequisite.fromJson)
          .toList(),
      badgeText: json['badgeText'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'localizationKey': localizationKey,
        'theme': theme.toJson(),
        'contents': contents.map((c) => c.toJson()).toList(),
        'price': price.toJson(),
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'targetSegments': targetSegments,
        if (purchaseLimit != null) 'purchaseLimit': purchaseLimit,
        if (cooldownAfterPurchaseHours != null)
          'cooldownAfterPurchaseHours': cooldownAfterPurchaseHours,
        'priority': priority,
        'assetManifest': assetManifest,
        if (experimentKey != null) 'experimentKey': experimentKey,
        'analyticsTag': analyticsTag,
        'prerequisites': prerequisites.map((p) => p.toJson()).toList(),
        if (badgeText != null) 'badgeText': badgeText,
      };

  /// Sentinel epoch used when a date string is missing/invalid; the
  /// validator rejects records carrying it.
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime _parseDate(dynamic raw) {
    if (raw is! String) return _epoch;
    return DateTime.tryParse(raw) ?? _epoch;
  }

  /// Concise summary of contents for compact card subtitles, e.g.
  /// `500 gems · 3 power-ups · 1 skin`.
  String contentSummary() {
    final parts = <String>[];
    for (final c in contents) {
      switch (c.type) {
        case BundleContentType.gems:
          parts.add('${c.count} gems');
          break;
        case BundleContentType.coins:
          parts.add('${c.count} coins');
          break;
        case BundleContentType.powerup:
          parts.add('${c.count} power-up${c.count == 1 ? '' : 's'}');
          break;
        case BundleContentType.jet:
          parts.add('${c.count} jet${c.count == 1 ? '' : 's'}');
          break;
        case BundleContentType.jetSkin:
          parts.add('${c.count} skin${c.count == 1 ? '' : 's'}');
          break;
        case BundleContentType.xpBoost:
          parts.add('${c.count}× XP');
          break;
      }
    }
    return parts.join(' · ');
  }
}
