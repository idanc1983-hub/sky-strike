import '../constants/economy_constants.dart';

/// Pure functions for the per-stage coin economy. No state, no side
/// effects — every value the GDD specifies in §2.1, §2.2, §2.3 is
/// computed from the constants in [EconomyConstants].
class CoinRewardCalculator {
  CoinRewardCalculator._();

  /// `1 + step × (world - 1)`. Clamps `world` to `>= 1` so callers passing
  /// 0 don't underflow.
  static double worldMultiplier(int world) {
    final w = world < 1 ? 1 : world;
    return 1.0 + EconomyConstants.worldCoinMultiplierStep * (w - 1);
  }

  /// Coins awarded for clearing wave [wave1to10] in [world].
  /// Returns 0 when [wave1to10] is outside `1..10`.
  static int coinsForWave({required int wave1to10, required int world}) {
    if (wave1to10 < 1 || wave1to10 > EconomyConstants.waveCoinCurveW1.length) {
      return 0;
    }
    final base = EconomyConstants.waveCoinCurveW1[wave1to10 - 1];
    return (base * worldMultiplier(world)).floor();
  }

  /// Cumulative coin earnings if every wave 1..10 is cleared in [world].
  /// Excludes the stage clear bonus and star bonus.
  static int waveSubtotal(int world) {
    var sum = 0;
    for (var i = 1; i <= EconomyConstants.waveCoinCurveW1.length; i++) {
      sum += coinsForWave(wave1to10: i, world: world);
    }
    return sum;
  }

  /// First-time stage clear bonus, scaled by world.
  static int stageClearBonus(int world) {
    return (EconomyConstants.stageClearBonus * worldMultiplier(world)).floor();
  }

  /// Star bonus for [stars] (0..3), scaled by world.
  static int starBonus({required int stars, required int world}) {
    if (stars < 0 || stars >= EconomyConstants.starBonus.length) return 0;
    final base = EconomyConstants.starBonus[stars];
    return (base * worldMultiplier(world)).floor();
  }

  /// Coins kept on death — `floor(accumulated × 0.40)`. See GDD §2.3.
  /// Gems and bonuses are forfeited (not handled here).
  static int salvageOnDeath(int accumulatedRunCoins) {
    if (accumulatedRunCoins <= 0) return 0;
    return (accumulatedRunCoins * EconomyConstants.salvageCoinFraction)
        .floor();
  }

  /// Total a perfectly-cleared stage pays: waves + stage clear + 3-star
  /// bonus, all scaled by world. Used by tuning sanity checks (see tests).
  static int perfectStageTotal(int world) {
    return waveSubtotal(world) +
        stageClearBonus(world) +
        starBonus(stars: 3, world: world);
  }
}
