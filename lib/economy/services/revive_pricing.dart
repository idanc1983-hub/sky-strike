import '../constants/economy_constants.dart';

/// Wave-bucket gem pricing for the paid revive option. Pure function.
class RevivePricing {
  RevivePricing._();

  /// Gem cost for paid revive on the given wave (1..10). Boss wave (10)
  /// uses [EconomyConstants.reviveGemCostBoss].
  static int gemsForWave(int wave1to10) {
    if (wave1to10 <= 3) return EconomyConstants.reviveGemCostW1to3;
    if (wave1to10 <= 6) return EconomyConstants.reviveGemCostW4to6;
    if (wave1to10 <= 9) return EconomyConstants.reviveGemCostW7to9;
    return EconomyConstants.reviveGemCostBoss;
  }

  /// True iff the player still has free ad-revives left in this stage
  /// attempt. The [adRevivesUsedThisStage] counter is reset whenever a new
  /// stage starts.
  static bool canTakeAdRevive(int adRevivesUsedThisStage) {
    return adRevivesUsedThisStage <
        EconomyConstants.adRevivesPerStageCap;
  }
}
