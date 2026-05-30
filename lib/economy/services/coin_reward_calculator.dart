import '../constants/economy_constants.dart';
import 'economy_config.dart';

/// Pure functions for the per-stage coin economy. Reads live values
/// from [EconomyConfig] (RC-backed in production) and falls back to
/// [EconomyConstants] when RC has no tuning for a given key. No state,
/// no side effects.
class CoinRewardCalculator {
  CoinRewardCalculator._();

  /// World multiplier. Reads RC `levels_economy[biome_1].world_coin_mult`
  /// when present; otherwise `1 + step × (world - 1)` from constants.
  /// Clamps `world` to `>= 1` so callers passing 0 don't underflow.
  static double worldMultiplier(int world) {
    return EconomyConfig.worldCoinMultiplier(world);
  }

  /// Coins awarded for clearing wave [wave1to10] in [world].
  /// Returns 0 when [wave1to10] is outside `1..10`.
  static int coinsForWave({required int wave1to10, required int world}) {
    if (wave1to10 < 1 || wave1to10 > 10) return 0;
    final base = EconomyConfig.coinsForWave(wave1to10);
    return (base * worldMultiplier(world)).floor();
  }

  /// Cumulative coin earnings if every wave 1..10 is cleared in [world].
  /// Excludes the stage clear bonus and star bonus.
  static int waveSubtotal(int world) {
    var sum = 0;
    for (var i = 1; i <= 10; i++) {
      sum += coinsForWave(wave1to10: i, world: world);
    }
    return sum;
  }

  /// First-time stage clear bonus, scaled by world.
  static int stageClearBonus(int world) {
    return (EconomyConfig.stageClearBonus() * worldMultiplier(world)).floor();
  }

  /// Star bonus for [stars] (0..3), scaled by world.
  static int starBonus({required int stars, required int world}) {
    final base = EconomyConfig.starBonus(stars);
    if (base <= 0) return 0;
    return (base * worldMultiplier(world)).floor();
  }

  /// Coins kept on death — `floor(accumulated × 0.40)`. See GDD §2.3.
  /// Gems and bonuses are forfeited (not handled here). Salvage fraction
  /// stays in constants — it's a mechanical rule, not a LiveOps lever.
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
