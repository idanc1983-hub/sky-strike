import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/constants/economy_constants.dart';
import 'package:skystrike/economy/constants/power_up_catalog.dart';
import 'package:skystrike/economy/services/coin_reward_calculator.dart';
import 'package:skystrike/economy/services/economy_config.dart';
import 'package:skystrike/economy/services/pack_pricing.dart';

class _OverrideSource implements EconomyConfigSource {
  final int? wave;
  final double? mult;
  final int? clear;
  final int? star;
  final int? pickup;
  final int? puPrice;

  const _OverrideSource({
    this.wave,
    this.mult,
    this.clear,
    this.star,
    this.pickup,
    this.puPrice,
  });

  @override
  int? waveClearCoins(int _) => wave;
  @override
  double? worldCoinMultiplier(int _) => mult;
  @override
  int? stageClearBonus() => clear;
  @override
  int? starBonus(int _) => star;
  @override
  int? coinPickupRegular() => pickup;
  @override
  int? coinPickupElite() => pickup;
  @override
  int? coinPickupBossPhase() => pickup;
  @override
  int? hpDropAtMaxHpCoinValue() => pickup;
  @override
  int? powerUpSinglePrice(String _) => puPrice;
}

void main() {
  tearDown(EconomyConfig.resetForTest);

  group('EconomyConfig fallback', () {
    test('coinsForWave defaults to EconomyConstants', () {
      expect(
        EconomyConfig.coinsForWave(1),
        equals(EconomyConstants.waveCoinCurveW1[0]),
      );
      expect(
        EconomyConfig.coinsForWave(10),
        equals(EconomyConstants.waveCoinCurveW1[9]),
      );
    });

    test('out-of-range wave returns 0', () {
      expect(EconomyConfig.coinsForWave(0), equals(0));
      expect(EconomyConfig.coinsForWave(11), equals(0));
    });

    test('worldCoinMultiplier matches the step formula', () {
      expect(EconomyConfig.worldCoinMultiplier(1), equals(1.0));
      expect(
        EconomyConfig.worldCoinMultiplier(3),
        closeTo(1.0 + 2 * EconomyConstants.worldCoinMultiplierStep, 1e-9),
      );
    });

    test('powerUpSinglePrice returns null when neither RC nor catalog know',
        () {
      expect(
        EconomyConfig.powerUpSinglePrice('does_not_exist'),
        isNull,
      );
    });
  });

  group('EconomyConfig override', () {
    test('live tuning overrides constants', () {
      EconomyConfig.setSource(const _OverrideSource(
        wave: 99,
        mult: 2.5,
        clear: 777,
        star: 250,
        pickup: 42,
        puPrice: 999,
      ));

      expect(EconomyConfig.coinsForWave(1), equals(99));
      expect(EconomyConfig.worldCoinMultiplier(3), equals(2.5));
      expect(EconomyConfig.stageClearBonus(), equals(777));
      expect(EconomyConfig.starBonus(3), equals(250));
      expect(EconomyConfig.coinPickupRegular(), equals(42));
      expect(EconomyConfig.coinPickupElite(), equals(42));
      expect(EconomyConfig.coinPickupBossPhase(), equals(42));
      expect(EconomyConfig.hpDropAtMaxHpCoinValue(), equals(42));
      expect(EconomyConfig.powerUpSinglePrice('bomb'), equals(999));
    });
  });

  group('CoinRewardCalculator uses live config', () {
    test('coinsForWave honours live wave value × multiplier', () {
      EconomyConfig.setSource(const _OverrideSource(wave: 100, mult: 1.5));
      // 100 base × 1.5 multiplier = 150
      expect(
        CoinRewardCalculator.coinsForWave(wave1to10: 5, world: 3),
        equals(150),
      );
    });

    test('starBonus honours live star value', () {
      EconomyConfig.setSource(const _OverrideSource(star: 80, mult: 1.0));
      expect(
        CoinRewardCalculator.starBonus(stars: 3, world: 1),
        equals(80),
      );
    });
  });

  group('PackPricing uses live config', () {
    test('totalPrice prefers live single price over catalog', () {
      EconomyConfig.setSource(const _OverrideSource(puPrice: 200));
      // 200 × 3 × (1 - 0.10) = 540
      expect(
        PackPricing.totalPrice(powerUpId: 'bomb', packSize: 3),
        equals(540),
      );
    });

    test('falls back to PowerUpCatalog when no live price', () {
      final fallback = PowerUpCatalog.singlePrice['bomb']!;
      expect(
        PackPricing.totalPrice(powerUpId: 'bomb', packSize: 1),
        equals(fallback),
      );
    });
  });
}
