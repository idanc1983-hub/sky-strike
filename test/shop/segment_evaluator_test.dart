import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/shop/models/bundle_content.dart';
import 'package:skystrike/shop/models/bundle_price.dart';
import 'package:skystrike/shop/models/bundle_theme.dart';
import 'package:skystrike/shop/models/player_segment.dart';
import 'package:skystrike/shop/models/shop_bundle.dart';
import 'package:skystrike/shop/services/segment_evaluator.dart';

ShopBundle _bundle({
  String id = 'b1',
  List<String> targetSegments = const [],
  DateTime? startsAt,
  DateTime? endsAt,
  int? purchaseLimit,
  int? cooldownHours,
  int priority = 10,
  List<BundlePrerequisite> prerequisites = const [],
}) {
  return ShopBundle(
    id: id,
    localizationKey: 'bundle.$id',
    theme: const BundleTheme(
      themeId: 'default',
      bannerAsset: 'a.png',
      accentColorHex: '#3B6D11',
      backgroundColorHex: '#0a1a0a',
    ),
    contents: const [
      BundleContent(
        type: BundleContentType.gems,
        count: 100,
        iconAsset: 'a.png',
      ),
    ],
    price: const BundlePrice(type: BundlePriceType.gems, gemCost: 50),
    startsAt: startsAt ?? DateTime.utc(2026, 1, 1),
    endsAt: endsAt ?? DateTime.utc(2030, 1, 1),
    targetSegments: targetSegments,
    priority: priority,
    assetManifest: const [],
    analyticsTag: 'tag',
    prerequisites: prerequisites,
    purchaseLimit: purchaseLimit,
    cooldownAfterPurchaseHours: cooldownHours,
  );
}

void main() {
  final fixedNow = DateTime.utc(2026, 5, 6, 12, 0, 0);

  PlayerSegmentData player({
    List<String> segments = const [],
    int level = 14,
    Map<String, List<int>> purchases = const {},
    Set<String> ownedJets = const {},
    int completedWorld = 0,
    double totalSpend = 0,
  }) {
    return PlayerSegmentData(
      playerId: 'p',
      segments: segments,
      level: level,
      totalSpendUsd: totalSpend,
      lastActiveDaysAgo: 0,
      bundlePurchases: purchases,
      ownedJets: ownedJets,
      completedWorld: completedWorld,
    );
  }

  group('SegmentEvaluator', () {
    final evaluator = SegmentEvaluator(now: () => fixedNow);

    test('empty targetSegments passes for every player', () {
      final survivors = evaluator.filter(
        [_bundle()],
        player(),
      );
      expect(survivors.length, 1);
    });

    test('targetSegments filters non-matching player', () {
      final survivors = evaluator.filter(
        [_bundle(targetSegments: ['whales'])],
        player(segments: ['new_player']),
      );
      expect(survivors, isEmpty);
    });

    test('targetSegments passes matching player', () {
      final survivors = evaluator.filter(
        [_bundle(targetSegments: ['whales'])],
        player(segments: ['whales']),
      );
      expect(survivors.length, 1);
    });

    test('expired bundle filtered out', () {
      final survivors = evaluator.filter(
        [
          _bundle(
            endsAt: DateTime.utc(2026, 1, 1),
            startsAt: DateTime.utc(2025, 12, 1),
          ),
        ],
        player(),
      );
      expect(survivors, isEmpty);
    });

    test('future bundle filtered out', () {
      final survivors = evaluator.filter(
        [
          _bundle(
            startsAt: DateTime.utc(2027, 1, 1),
            endsAt: DateTime.utc(2027, 6, 1),
          ),
        ],
        player(),
      );
      expect(survivors, isEmpty);
    });

    test('minLevel prerequisite filters low-level player', () {
      final survivors = evaluator.filter(
        [
          _bundle(prerequisites: const [
            BundlePrerequisite(type: PrerequisiteType.minLevel, value: 30),
          ]),
        ],
        player(level: 14),
      );
      expect(survivors, isEmpty);
    });

    test('minLevel prerequisite passes high-level player', () {
      final survivors = evaluator.filter(
        [
          _bundle(prerequisites: const [
            BundlePrerequisite(type: PrerequisiteType.minLevel, value: 30),
          ]),
        ],
        player(level: 35),
      );
      expect(survivors.length, 1);
    });

    test('purchaseLimit drops bundles already at limit', () {
      final purchases = {
        'b1': [fixedNow.millisecondsSinceEpoch],
      };
      final survivors = evaluator.filter(
        [_bundle(purchaseLimit: 1)],
        player(purchases: purchases),
      );
      expect(survivors, isEmpty);
    });

    test('cooldown drops bundles purchased within window', () {
      final lastPurchase = fixedNow.subtract(const Duration(hours: 1));
      final purchases = {
        'b1': [lastPurchase.millisecondsSinceEpoch],
      };
      final survivors = evaluator.filter(
        [_bundle(cooldownHours: 24)],
        player(purchases: purchases),
      );
      expect(survivors, isEmpty);
    });

    test('cooldown allows bundles past window', () {
      final lastPurchase = fixedNow.subtract(const Duration(hours: 25));
      final purchases = {
        'b1': [lastPurchase.millisecondsSinceEpoch],
      };
      final survivors = evaluator.filter(
        [_bundle(cooldownHours: 24)],
        player(purchases: purchases),
      );
      expect(survivors.length, 1);
    });

    test('multiple bundles return sorted by priority desc', () {
      final survivors = evaluator.filter(
        [
          _bundle(id: 'low', priority: 5),
          _bundle(id: 'high', priority: 100),
          _bundle(id: 'mid', priority: 50),
        ],
        player(),
      );
      expect(survivors.map((b) => b.id).toList(), ['high', 'mid', 'low']);
    });

    test('ownsJet prerequisite filters players without that jet', () {
      final survivors = evaluator.filter(
        [
          _bundle(prerequisites: const [
            BundlePrerequisite(
              type: PrerequisiteType.ownsJet,
              value: 'wraith_x',
            ),
          ]),
        ],
        player(ownedJets: const {'phantom'}),
      );
      expect(survivors, isEmpty);
    });

    test('completedWorld prerequisite filters players who have not finished', () {
      final survivors = evaluator.filter(
        [
          _bundle(prerequisites: const [
            BundlePrerequisite(
              type: PrerequisiteType.completedWorld,
              value: 3,
            ),
          ]),
        ],
        player(completedWorld: 1),
      );
      expect(survivors, isEmpty);
    });
  });
}
