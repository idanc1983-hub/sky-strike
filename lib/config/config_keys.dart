/// Single source of truth for Firebase Remote Config key names.
///
/// Naming convention: `{namespace}__{name}__v{schema_version}`.
/// Keep this list in lockstep with `KEY_MAP` in `tools/build_config.py`.
class ConfigKeys {
  ConfigKeys._();

  // challenges namespace
  static const String challengesCyclePlan = 'challenges__cycle_plan__v1';

  // difficulty namespace
  static const String difficultyWaveCurves = 'difficulty__wave_curves__v1';
  static const String difficultyEnemyScaling = 'difficulty__enemy_scaling__v1';

  // drops namespace
  static const String dropsRates = 'drops__rates__v1';
  static const String dropsPowerupDistribution =
      'drops__powerup_distribution__v1';
  static const String dropsStreakBoost = 'drops__streak_boost__v1';

  // economy namespace
  static const String economyRevivePricing = 'economy__revive_pricing__v1';
  static const String economyShopPrices = 'economy__shop_prices__v1';

  // progression namespace
  static const String progressionXpCurve = 'progression__xp_curve__v1';
  static const String progressionLevelRewards =
      'progression__level_rewards__v1';

  // flags namespace
  static const String flagsFeatureFlags = 'flags__feature_flags__v1';
  static const String flagsKillSwitches = 'flags__kill_switches__v1';

  // experiments namespace
  static const String experimentsAbAssignment =
      'experiments__ab_assignment__v1';

  /// All keys, alphabetically sorted. Used by the service to register
  /// defaults and to iterate when parsing remote payloads.
  static const List<String> all = <String>[
    challengesCyclePlan,
    difficultyEnemyScaling,
    difficultyWaveCurves,
    dropsPowerupDistribution,
    dropsRates,
    dropsStreakBoost,
    economyRevivePricing,
    economyShopPrices,
    experimentsAbAssignment,
    flagsFeatureFlags,
    flagsKillSwitches,
    progressionLevelRewards,
    progressionXpCurve,
  ];
}
