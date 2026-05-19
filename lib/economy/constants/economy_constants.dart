/// Single-edit tuning surface for the entire economy.
///
/// Every numeric value the GDD locks lives here. Calculators and UI read
/// these constants by reference — they do **not** redeclare the same
/// numbers locally. Tuning changes happen here and only here.
class EconomyConstants {
  EconomyConstants._();

  // ---------------------------------------------------------------------------
  // Wave coin curve (World 1 baseline) — GDD §2.1
  // ---------------------------------------------------------------------------

  /// Coins awarded for clearing each of waves 1..10 of a stage. Index 0 is
  /// wave 1; index 9 is the boss wave.
  static const List<int> waveCoinCurveW1 = <int>[
    20, 22, 25, 28, 32, 36, 40, 45, 50, 150,
  ];

  /// One-time bonus for clearing a stage for the first time.
  static const int stageClearBonus = 100;

  /// Star bonus by star count: index = stars (0..3). 1★ = 0, 2★ = 25, 3★ = 50.
  static const List<int> starBonus = <int>[0, 0, 25, 50];

  /// `worldCoinMultiplier(world) = 1 + step × (world - 1)`. World 1 = 1.0×.
  static const double worldCoinMultiplierStep = 0.25;

  // ---------------------------------------------------------------------------
  // Loss salvage — GDD §2.3
  // ---------------------------------------------------------------------------

  /// Fraction of accumulated run coins kept on death (before any revive).
  static const double salvageCoinFraction = 0.40;

  // ---------------------------------------------------------------------------
  // Revive — GDD §2.4
  // ---------------------------------------------------------------------------

  /// Gem cost for paid revive by inclusive wave-range bucket. Order: W1-3,
  /// W4-6, W7-9, W10 boss.
  static const int reviveGemCostW1to3 = 5;
  static const int reviveGemCostW4to6 = 10;
  static const int reviveGemCostW7to9 = 15;
  static const int reviveGemCostBoss = 20;

  /// Maximum free ad-revives a player may take per stage attempt.
  static const int adRevivesPerStageCap = 3;

  // ---------------------------------------------------------------------------
  // First-time milestone gem rewards — GDD §3.1
  // ---------------------------------------------------------------------------

  /// Gems granted the first time a stage is cleared (any star count).
  static const int gemFirstStageClear = 2;

  /// Gems granted the first time a stage is cleared with 3★.
  static const int gemFirstThreeStarClear = 5;

  /// Gems granted the first time a world's boss is defeated.
  static const int gemFirstBossDefeat = 10;

  // ---------------------------------------------------------------------------
  // Daily streak — GDD §5
  // ---------------------------------------------------------------------------

  /// Per-day base gem rewards across the 7-day cycle (index 0 = Day 1).
  static const List<int> streakDailyGems = <int>[1, 0, 2, 0, 3, 0, 0];

  /// Per-day base coin rewards across the 7-day cycle (index 0 = Day 1).
  /// Day 7 chest is computed by formula and replaces the static value here.
  static const List<int> streakDailyCoins = <int>[100, 200, 0, 400, 0, 600, 0];

  /// Per-day random power-up grants (index 0 = Day 1).
  static const List<int> streakDailyPowerUps = <int>[0, 0, 1, 0, 2, 0, 0];

  /// Loyalty bonus = `min(loyaltyBonusCap, weeksCompleted × loyaltyBonusStep)`.
  static const double loyaltyBonusStep = 0.10;
  static const double loyaltyBonusCap = 0.50;

  // ---------------------------------------------------------------------------
  // Day 7 chest formula — GDD §5.3
  // ---------------------------------------------------------------------------
  static const int day7BaseCoins = 500;
  static const double day7CoinLevelStep = 0.08;
  static const int day7BaseGems = 20;
  static const double day7GemLevelStep = 0.5;
  static const int day7GemCap = 75;
  static const int day7PowerUpCount = 2;

  // ---------------------------------------------------------------------------
  // Operation chest formula — GDD §4.2
  // ---------------------------------------------------------------------------
  static const int operationBaseCoins = 800;
  static const double operationCoinLevelStep = 0.05;
  static const double operationCoinJitterMin = 0.8;
  static const double operationCoinJitterMax = 1.2;

  /// FTUE multiplier applied to operation chest reward when the player is
  /// still in their first 24h.
  static const double operationFtueChestMultiplier = 1.5;

  /// FTUE shortens operation duration to this fraction of the standard.
  static const double operationFtueTargetFraction = 0.6;

  // ---------------------------------------------------------------------------
  // Loadout — GDD §2.7
  // ---------------------------------------------------------------------------

  /// Default unlocked slots on first launch (Slots 1-3 are free).
  static const int defaultUnlockedLoadoutSlots = 3;

  /// Maximum loadout slots a player can ever own.
  static const int maxLoadoutSlots = 5;

  /// Number of power-up cells in a single loadout's tray.
  static const int trayPowerUpCount = 5;

  /// Coin price to unlock loadout slot 4.
  static const int loadoutSlot4CoinCost = 35000;

  /// Coin price to unlock loadout slot 5.
  static const int loadoutSlot5CoinCost = 80000;

  /// Gem cost for the contextual Slot-4 unlock shortcut (pickup overflow only).
  static const int loadoutSlot4GemShortcutCost = 25;

  /// Biome required to unlock loadout slot 4 (W5 = Volcano).
  static const int loadoutSlot4BiomeReq = 5;

  /// Biome required to unlock loadout slot 5 (W6 = City).
  static const int loadoutSlot5BiomeReq = 6;

  // ---------------------------------------------------------------------------
  // Pickup overflow — GDD §2.7.1
  // ---------------------------------------------------------------------------
  static const int maxPickupQueue = 2;

  // ---------------------------------------------------------------------------
  // Random power-up reward weighting — GDD §2.6
  // ---------------------------------------------------------------------------

  /// Probability of pulling from the most-recent biome's pool.
  static const double powerUpRecentPoolWeight = 0.50;

  /// Probability of pulling from the previous biome's pool (cumulative
  /// upper bound: `recent + previous = 0.80`).
  static const double powerUpPreviousPoolWeight = 0.30;

  /// Probability of pulling from older biomes (remainder = 0.20).
  static const double powerUpEarlierPoolWeight = 0.20;

  // ---------------------------------------------------------------------------
  // Gem sinks (non-revive) — GDD §3.2
  // ---------------------------------------------------------------------------
  static const int gemCostTrayRefill = 15;
  static const int gemCostOperationSkipPerHour = 1;
  static const int gemCostDealReroll = 5;

  // ---------------------------------------------------------------------------
  // HP pack pickup drop — GDD §2.9
  // ---------------------------------------------------------------------------
  static const double hpDropChanceStandard = 0.15;
  static const double hpDropChanceElite = 0.25;
  static const double hpDropChanceBossPhase = 0.35;

  /// When player is at max HP, an HP-pack drop is converted to coins.
  static const int hpDropAtMaxHpCoinValue = 50;

  // ---------------------------------------------------------------------------
  // Coin pickups — GDD §2.9
  // ---------------------------------------------------------------------------
  static const int coinPickupValueRegular = 5;
  static const int coinPickupValueElite = 15;
  static const int coinPickupValueBossPhase = 50;
  static const double magnetPullRadiusPx = 200;

  // ---------------------------------------------------------------------------
  // Ad reward bumps — GDD §2.11
  // ---------------------------------------------------------------------------
  static const int dailyAdWatchCap = 5;

  /// `Remove Ads` IAP doubles all reward placements permanently.
  static const double removeAdsRewardMultiplier = 2.0;

  /// Operation chest "+25% from chest open" rewarded-ad boost.
  static const double adChestBoostFraction = 0.25;

  // ---------------------------------------------------------------------------
  // Backend sync — GDD §6.1
  // ---------------------------------------------------------------------------
  static const Duration backendSyncDebounce = Duration(seconds: 30);
  static const Duration operationRefreshInterval = Duration(seconds: 60);
}
