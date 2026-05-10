import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/coin_reward_calculator.dart';

void main() {
  group('CoinRewardCalculator', () {
    test('worldMultiplier matches GDD locked values', () {
      expect(CoinRewardCalculator.worldMultiplier(1), closeTo(1.00, 1e-9));
      expect(CoinRewardCalculator.worldMultiplier(2), closeTo(1.25, 1e-9));
      expect(CoinRewardCalculator.worldMultiplier(3), closeTo(1.50, 1e-9));
      expect(CoinRewardCalculator.worldMultiplier(4), closeTo(1.75, 1e-9));
      expect(CoinRewardCalculator.worldMultiplier(5), closeTo(2.00, 1e-9));
      expect(CoinRewardCalculator.worldMultiplier(6), closeTo(2.25, 1e-9));
    });

    test('coinsForWave returns the locked W1 baseline', () {
      const expected = <int>[20, 22, 25, 28, 32, 36, 40, 45, 50, 150];
      for (var i = 0; i < expected.length; i++) {
        expect(
          CoinRewardCalculator.coinsForWave(wave1to10: i + 1, world: 1),
          expected[i],
          reason: 'wave ${i + 1} W1',
        );
      }
    });

    test('out-of-range wave returns 0', () {
      expect(
          CoinRewardCalculator.coinsForWave(wave1to10: 0, world: 1), 0);
      expect(
          CoinRewardCalculator.coinsForWave(wave1to10: 11, world: 1), 0);
    });

    test('perfectStageTotal W1 hits the GDD ~600 target', () {
      // GDD §2.1 cumulative table: waves 448 + 100 stage clear + 50 (3-star)
      // = 598. We use floor() world multiplier which doesn't change W1.
      expect(CoinRewardCalculator.perfectStageTotal(1), 598);
    });

    test('salvageOnDeath drops to 40% floor', () {
      expect(CoinRewardCalculator.salvageOnDeath(0), 0);
      expect(CoinRewardCalculator.salvageOnDeath(100), 40);
      expect(CoinRewardCalculator.salvageOnDeath(101), 40); // floor
      expect(CoinRewardCalculator.salvageOnDeath(250), 100);
    });

    test('starBonus scales with stars and world', () {
      expect(
        CoinRewardCalculator.starBonus(stars: 0, world: 1),
        0,
      );
      expect(
        CoinRewardCalculator.starBonus(stars: 1, world: 1),
        0,
      );
      expect(
        CoinRewardCalculator.starBonus(stars: 2, world: 1),
        25,
      );
      expect(
        CoinRewardCalculator.starBonus(stars: 3, world: 1),
        50,
      );
      // World 6 multiplier = 2.25× on 50 = 112.5 → floor 112.
      expect(
        CoinRewardCalculator.starBonus(stars: 3, world: 6),
        112,
      );
    });

    test('stageClearBonus scales with world', () {
      expect(CoinRewardCalculator.stageClearBonus(1), 100);
      expect(CoinRewardCalculator.stageClearBonus(6), 225);
    });
  });
}
