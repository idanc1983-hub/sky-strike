/// Locked numerics for the Challenge System (GDD v1.3 §4).
///
/// Single-edit tuning surface — every number the GDD pins lives here.
/// Calculators read these by reference; tests pin them to GDD-spec'd
/// outputs.
class ChallengeConstants {
  ChallengeConstants._();

  // ---------------------------------------------------------------------------
  // Cycle duration — GDD §4.1
  // ---------------------------------------------------------------------------

  /// Length of one challenge cycle, fixed. No variable durations.
  static const Duration cycleDuration = Duration(hours: 72);

  // ---------------------------------------------------------------------------
  // Target formulas — GDD §4.2
  // ---------------------------------------------------------------------------

  // Hunter
  static const int hunterBaseTarget = 100;
  static const double hunterTargetLevelStep = 0.04;

  // Survivor
  static const int survivorBaseTarget = 3;
  static const double survivorTargetLevelStep = 0.1;

  // Treasure Hunter
  static const int treasureBaseTarget = 2500;
  static const double treasureTargetLevelStep = 0.08;

  // Conqueror
  static const int conquerorBaseTarget = 8;
  static const double conquerorTargetLevelStep = 0.2;

  // ---------------------------------------------------------------------------
  // Milestone reward formulas — GDD §4.3
  // ---------------------------------------------------------------------------

  // 50% milestone — coins
  static const int milestone50BaseCoins = 300;
  static const double milestone50CoinLevelStep = 0.05;

  // 100% milestone — coins
  static const int milestone100BaseCoins = 800;
  static const double milestone100CoinLevelStep = 0.05;
  static const double milestone100CoinJitterMin = 0.8;
  static const double milestone100CoinJitterMax = 1.2;

  // ---------------------------------------------------------------------------
  // Milestone progress thresholds (% of target)
  // ---------------------------------------------------------------------------
  static const double milestone50Threshold = 0.50;
  static const double milestone100Threshold = 1.0;
}
