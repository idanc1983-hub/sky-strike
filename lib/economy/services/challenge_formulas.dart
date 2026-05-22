import 'dart:math';

import '../constants/challenge_constants.dart';
import '../state/challenge_state.dart';
import '../state/reward.dart';
import 'power_up_picker.dart';

/// Pure-function formulas for challenge target counts and milestone
/// rewards. No side effects; all randomness is injected via [Random].
///
/// The 50% / 100% gem tier values are the **post-rebalance** numbers
/// from GDD v1.3 §4.3 — 25% lower than the v1.2 single-chest tiers to
/// account for the higher cycle frequency (10/month vs ~5/month).
class ChallengeFormulas {
  ChallengeFormulas._();

  // ---------------------------------------------------------------------------
  // Target formulas — GDD §4.2
  // ---------------------------------------------------------------------------

  /// Computes the target count for [type] at [playerLevel].
  ///
  /// The intro `newPlayers` cycle uses half the Hunter base target so it
  /// feels accessible at the level-4 unlock point — players have just
  /// reached the gate and shouldn't bounce off a hard target.
  static int targetFor({
    required ChallengeType type,
    required int playerLevel,
  }) {
    switch (type) {
      case ChallengeType.newPlayers:
        return ((ChallengeConstants.hunterBaseTarget / 2) *
                (1 + playerLevel * ChallengeConstants.hunterTargetLevelStep))
            .floor();
      case ChallengeType.hunter:
        return (ChallengeConstants.hunterBaseTarget *
                (1 + playerLevel * ChallengeConstants.hunterTargetLevelStep))
            .floor();
      case ChallengeType.survivor:
        return ChallengeConstants.survivorBaseTarget +
            (playerLevel * ChallengeConstants.survivorTargetLevelStep)
                .floor();
      case ChallengeType.treasure:
        return (ChallengeConstants.treasureBaseTarget *
                (1 +
                    playerLevel *
                        ChallengeConstants.treasureTargetLevelStep))
            .floor();
      case ChallengeType.conqueror:
        return ChallengeConstants.conquerorBaseTarget +
            (playerLevel * ChallengeConstants.conquerorTargetLevelStep)
                .floor();
    }
  }

  // ---------------------------------------------------------------------------
  // 100% milestone gem tier — GDD §4.3 (post-rebalance, −25%)
  //
  // v2 removed the 50% mid-cycle milestone. Only the completion reward
  // remains.
  // ---------------------------------------------------------------------------

  /// 100% milestone gem reward range `(min, maxInclusive)` by level bucket.
  static (int, int) gemRange100ForLevel(int playerLevel) {
    if (playerLevel < 11) return (8, 15);
    if (playerLevel < 26) return (11, 22);
    if (playerLevel < 51) return (18, 30);
    return (26, 37);
  }

  // ---------------------------------------------------------------------------
  // Completion reward computation
  // ---------------------------------------------------------------------------

  /// Computes the 100% milestone reward for [playerLevel]. Uses the
  /// `0.8..1.2` jitter from GDD §4.3.
  static Reward reward100({
    required int playerLevel,
    required int maxWorldReached,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final coinMult =
        1 + playerLevel * ChallengeConstants.milestone100CoinLevelStep;
    final jitter = ChallengeConstants.milestone100CoinJitterMin +
        r.nextDouble() *
            (ChallengeConstants.milestone100CoinJitterMax -
                ChallengeConstants.milestone100CoinJitterMin);
    final coins =
        (ChallengeConstants.milestone100BaseCoins * coinMult * jitter)
            .floor();
    final (gemMin, gemMax) = gemRange100ForLevel(playerLevel);
    final gems = gemMin + r.nextInt(gemMax - gemMin + 1);
    final powerUp = PowerUpPicker.pick(
      maxWorldReached: maxWorldReached,
      rng: r,
    );
    return Reward(coins: coins, gems: gems, powerUps: <String>[powerUp]);
  }
}
