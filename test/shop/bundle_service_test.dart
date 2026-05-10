import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skystrike/shop/models/bundle_content.dart';
import 'package:skystrike/shop/models/bundle_price.dart';
import 'package:skystrike/shop/models/bundle_theme.dart';
import 'package:skystrike/shop/models/player_segment.dart';
import 'package:skystrike/shop/models/shop_bundle.dart';
import 'package:skystrike/shop/services/bundle_cache.dart';
import 'package:skystrike/shop/services/bundle_repository.dart';
import 'package:skystrike/shop/services/bundle_service.dart';
import 'package:skystrike/shop/services/bundle_validator.dart';
import 'package:skystrike/shop/services/segment_evaluator.dart';

ShopBundle _bundle({
  String id = 'b1',
  int priority = 10,
  String? badIdToFailValidation,
  int? purchaseLimit,
}) {
  return ShopBundle(
    id: badIdToFailValidation ?? id,
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
    startsAt: DateTime.utc(2026, 1, 1),
    endsAt: DateTime.utc(2030, 1, 1),
    targetSegments: const [],
    priority: priority,
    assetManifest: const [],
    analyticsTag: 'tag',
    prerequisites: const [],
    purchaseLimit: purchaseLimit,
  );
}

class _StubRepo implements BundleRepository, DebugSegmentSetter {
  List<ShopBundle> bundles;
  PlayerSegmentData player;
  bool throwOnFetch;
  final Set<String> recordedPurchases = <String>{};
  final StreamController<List<ShopBundle>> controller =
      StreamController<List<ShopBundle>>.broadcast();
  bool disposed = false;

  _StubRepo({
    required this.bundles,
    required this.player,
    this.throwOnFetch = false,
  });

  @override
  Future<List<ShopBundle>> fetchActiveBundles() async {
    if (throwOnFetch) {
      throw const BundleFetchException('stub failure');
    }
    return bundles;
  }

  @override
  Future<PlayerSegmentData> fetchPlayerSegments() async {
    if (throwOnFetch) {
      throw const BundleFetchException('stub failure');
    }
    return player;
  }

  @override
  Future<void> recordPurchase(String bundleId) async {
    recordedPurchases.add(bundleId);
    final updated = player.withPurchase(
      bundleId,
      DateTime.now().millisecondsSinceEpoch,
    );
    player = updated;
  }

  @override
  Stream<List<ShopBundle>> watchActiveBundles() => controller.stream;

  @override
  Future<void> persistSegmentOverride(List<String>? segments) async {
    if (segments != null) {
      player = player.withSegments(segments);
    }
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Stub asset bundle so any direct asset reads in tests don't blow up.
    const channel = MethodChannel('flutter/assets');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });

  PlayerSegmentData newPlayer() => const PlayerSegmentData(
        playerId: 'p',
        segments: [],
        level: 14,
        totalSpendUsd: 0,
        lastActiveDaysAgo: 0,
      );

  group('BundleService', () {
    test('successful fetch populates visibleBundles', () async {
      final repo = _StubRepo(
        bundles: [_bundle(id: 'bundle_a'), _bundle(id: 'bundle_b', priority: 50)],
        player: newPlayer(),
      );
      final service = BundleService(
        repository: repo,
        validator: BundleValidator(log: (_, __) {}),
        evaluator: SegmentEvaluator(
          now: () => DateTime.utc(2026, 5, 6, 12),
        ),
        cache: BundleCache(),
      );
      await service.initialize();
      expect(service.visibleBundles.length, 2);
      // Sorted by priority desc
      expect(service.visibleBundles.first.id, 'bundle_b');
      service.dispose();
    });

    test('repository failure with cached data shows cached + sets lastError',
        () async {
      // Seed memory cache via a successful service first.
      final cache = BundleCache();
      cache.writeMemory([_bundle(id: 'cached')]);

      final failingRepo = _StubRepo(
        bundles: [],
        player: newPlayer(),
        throwOnFetch: true,
      );
      final service = BundleService(
        repository: failingRepo,
        validator: BundleValidator(log: (_, __) {}),
        evaluator: SegmentEvaluator(
          now: () => DateTime.utc(2026, 5, 6, 12),
        ),
        cache: cache,
      );
      await service.initialize();
      expect(service.visibleBundles.length, 1);
      expect(service.visibleBundles.first.id, 'cached');
      expect(service.lastError, isNotNull);
      service.dispose();
    });

    test('repository failure with no cache shows empty + lastError', () async {
      final failingRepo = _StubRepo(
        bundles: [],
        player: newPlayer(),
        throwOnFetch: true,
      );
      final service = BundleService(
        repository: failingRepo,
        validator: BundleValidator(log: (_, __) {}),
        evaluator: SegmentEvaluator(
          now: () => DateTime.utc(2026, 5, 6, 12),
        ),
        cache: BundleCache(),
      );
      await service.initialize();
      expect(service.visibleBundles, isEmpty);
      expect(service.lastError, isNotNull);
      service.dispose();
    });

    test('validator-failed bundles are silently dropped', () async {
      final repo = _StubRepo(
        bundles: [
          _bundle(id: 'good'),
          _bundle(badIdToFailValidation: 'BadID!'),
        ],
        player: newPlayer(),
      );
      final service = BundleService(
        repository: repo,
        validator: BundleValidator(log: (_, __) {}),
        evaluator: SegmentEvaluator(
          now: () => DateTime.utc(2026, 5, 6, 12),
        ),
        cache: BundleCache(),
      );
      await service.initialize();
      expect(service.visibleBundles.length, 1);
      expect(service.visibleBundles.first.id, 'good');
      service.dispose();
    });

    test('hot-reload stream updates visibleBundles and notifies', () async {
      final repo = _StubRepo(
        bundles: [_bundle(id: 'first')],
        player: newPlayer(),
      );
      final service = BundleService(
        repository: repo,
        validator: BundleValidator(log: (_, __) {}),
        evaluator: SegmentEvaluator(
          now: () => DateTime.utc(2026, 5, 6, 12),
        ),
        cache: BundleCache(),
      );
      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.initialize();
      expect(service.visibleBundles.first.id, 'first');

      // Push a new emission through the stream.
      repo.controller.add([_bundle(id: 'second', priority: 99)]);
      // Allow the microtask to process.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.visibleBundles.first.id, 'second');
      expect(notifyCount, greaterThan(1));
      service.dispose();
    });

    test('purchase records via repo and removes single-purchase bundles',
        () async {
      final repo = _StubRepo(
        bundles: [_bundle(id: 'one_shot', purchaseLimit: 1)],
        player: newPlayer(),
      );
      final service = BundleService(
        repository: repo,
        validator: BundleValidator(log: (_, __) {}),
        evaluator: SegmentEvaluator(
          now: () => DateTime.utc(2026, 5, 6, 12),
        ),
        cache: BundleCache(),
      );
      await service.initialize();
      expect(service.visibleBundles.length, 1);

      final ok = await service.attemptPurchase('one_shot');
      expect(ok, isTrue);
      expect(repo.recordedPurchases.contains('one_shot'), isTrue);
      expect(service.visibleBundles, isEmpty);
      service.dispose();
    });
  });
}
