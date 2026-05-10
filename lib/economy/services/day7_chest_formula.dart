import 'dart:math';

import '../constants/economy_constants.dart';
import '../state/reward.dart';
import 'power_up_picker.dart';

/// Pure-function formula for the Day 7 streak chest reward — GDD §5.3.
class Day7ChestFormula {
  Day7ChestFormula._();

  /// Computes the Day 7 chest reward for [playerLevel]. Power-up grants
  /// are pulled from the unlocked pool weighted 50/30/20.
  static Reward compute({
    required int playerLevel,
    required int maxWorldReached,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final coins = (EconomyConstants.day7BaseCoins *
            (1 + playerLevel * EconomyConstants.day7CoinLevelStep))
        .floor();
    final rawGems = EconomyConstants.day7BaseGems +
        (playerLevel * EconomyConstants.day7GemLevelStep).floor();
    final gems = rawGems > EconomyConstants.day7GemCap
        ? EconomyConstants.day7GemCap
        : rawGems;
    final powerUps = PowerUpPicker.pickMany(
      count: EconomyConstants.day7PowerUpCount,
      maxWorldReached: maxWorldReached,
      rng: r,
    );
    return Reward(coins: coins, gems: gems, powerUps: powerUps);
  }
}
