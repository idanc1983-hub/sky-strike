import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/shop/models/bundle_content.dart';
import 'package:skystrike/shop/models/bundle_price.dart';
import 'package:skystrike/shop/models/bundle_theme.dart';
import 'package:skystrike/shop/models/shop_bundle.dart';
import 'package:skystrike/shop/services/bundle_validator.dart';

ShopBundle _baseBundle({
  String id = 'valid_bundle',
  String localizationKey = 'bundle.valid.title',
  List<BundleContent>? contents,
  BundlePrice? price,
  DateTime? startsAt,
  DateTime? endsAt,
  List<BundlePrerequisite>? prerequisites,
  String? experimentKey,
  List<String>? assetManifest,
}) {
  return ShopBundle(
    id: id,
    localizationKey: localizationKey,
    theme: const BundleTheme(
      themeId: 'default',
      bannerAsset: 'assets/themes/default_banner.png',
      accentColorHex: '#3B6D11',
      backgroundColorHex: '#0a1a0a',
    ),
    contents: contents ??
        [
          const BundleContent(
            type: BundleContentType.gems,
            count: 100,
            iconAsset: 'assets/ui/icon_gem.png',
          ),
        ],
    price: price ??
        const BundlePrice(type: BundlePriceType.gems, gemCost: 50),
    startsAt: startsAt ?? DateTime.utc(2026, 5, 1),
    endsAt: endsAt ?? DateTime.utc(2026, 6, 1),
    targetSegments: const [],
    priority: 10,
    assetManifest: assetManifest ?? const [],
    analyticsTag: 'shop_bundle_valid',
    prerequisites: prerequisites ?? const [],
    experimentKey: experimentKey,
  );
}

void main() {
  group('BundleValidator', () {
    test('valid bundle passes', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle());
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('missing id fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(id: ''));
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('id missing')),
      );
    });

    test('missing localizationKey fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(localizationKey: ''));
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('localizationKey missing')),
      );
    });

    test('invalid id format fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(id: 'BadID!Mixed'));
      expect(result.isValid, isFalse);
      expect(result.errors, anyElement(contains('id format')));
    });

    test('endsAt before startsAt fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(
        startsAt: DateTime.utc(2026, 6, 1),
        endsAt: DateTime.utc(2026, 5, 1),
      ));
      expect(result.isValid, isFalse);
      expect(result.errors, anyElement(contains('endsAt must be after')));
    });

    test('empty contents array fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(contents: const []));
      expect(result.isValid, isFalse);
      expect(result.errors, anyElement(contains('contents empty')));
    });

    test('negative count fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(contents: const [
        BundleContent(
          type: BundleContentType.gems,
          count: -1,
          iconAsset: 'assets/ui/icon_gem.png',
        ),
      ]));
      expect(result.isValid, isFalse);
      expect(result.errors, anyElement(contains('count must be > 0')));
    });

    test('gems content with non-null itemId fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(contents: const [
        BundleContent(
          type: BundleContentType.gems,
          itemId: 'should_not_be_set',
          count: 100,
          iconAsset: 'assets/ui/icon_gem.png',
        ),
      ]));
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('itemId must be null')),
      );
    });

    test('powerup content with null itemId fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(contents: const [
        BundleContent(
          type: BundleContentType.powerup,
          count: 1,
          iconAsset: 'assets/ui/pu_bomb_slot.png',
        ),
      ]));
      expect(result.isValid, isFalse);
      expect(result.errors, anyElement(contains('itemId required')));
    });

    test('compareGems lower than gemCost fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(
        price: const BundlePrice(
          type: BundlePriceType.gems,
          gemCost: 100,
          compareGems: 50,
        ),
      ));
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('compareGems must be greater')),
      );
    });

    test('validation failure logs to analytics hook', () {
      final logged = <String>[];
      final v = BundleValidator(log: (id, errs) {
        logged.add('$id|${errs.length}');
      });
      v.validate(_baseBundle(id: ''));
      expect(logged, isNotEmpty);
      expect(logged.first, startsWith('<no-id>|'));
    });

    test('compareUsd lower than usdEquivalent fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(
        price: const BundlePrice(
          type: BundlePriceType.iap,
          iapProductId: 'com.skystrike.test',
          usdEquivalent: 9.99,
          compareUsd: 4.99,
        ),
      ));
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('compareUsd must be greater')),
      );
    });

    test('invalid experimentKey fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(experimentKey: 'BAD!Key'));
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('experimentKey format')),
      );
    });

    test('prerequisite with wrong value type fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(prerequisites: const [
        BundlePrerequisite(type: PrerequisiteType.minLevel, value: 'twenty'),
      ]));
      expect(result.isValid, isFalse);
      expect(result.errors, anyElement(contains('needs int')));
    });

    test('empty asset manifest entry fails', () {
      final v = BundleValidator(log: (_, __) {});
      final result = v.validate(_baseBundle(assetManifest: const ['', 'ok']));
      expect(result.isValid, isFalse);
      expect(result.errors, anyElement(contains('assetManifest[0] is empty')));
    });

    test('filterValid drops invalid bundles', () {
      final v = BundleValidator(log: (_, __) {});
      final survivors = v.filterValid([
        _baseBundle(),
        _baseBundle(id: 'BadID!'),
      ]);
      expect(survivors.length, 1);
      expect(survivors.first.id, 'valid_bundle');
    });
  });
}
