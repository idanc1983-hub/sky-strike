/// Failure-streak drop boost multipliers.
///
/// Parses `drops__streak_boost__v1`:
/// ```
/// {"schema_version":1, "trigger_streak_modulo":5, "hp_mult":2.0,
///  "powerup_mult":1.5, "gem_mult":1.5}
/// ```
class StreakBoost {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final int triggerStreakModulo;
  final double hpMult;
  final double powerupMult;
  final double gemMult;

  const StreakBoost({
    required this.schemaVersion,
    required this.triggerStreakModulo,
    required this.hpMult,
    required this.powerupMult,
    required this.gemMult,
  });

  static const StreakBoost fallback = StreakBoost(
    schemaVersion: supportedSchemaVersion,
    triggerStreakModulo: 5,
    hpMult: 2.0,
    powerupMult: 1.5,
    gemMult: 1.5,
  );

  factory StreakBoost.fromJson(Map<String, dynamic> json) => StreakBoost(
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
        triggerStreakModulo:
            (json['trigger_streak_modulo'] as num?)?.toInt() ?? 5,
        hpMult: (json['hp_mult'] as num?)?.toDouble() ?? 2.0,
        powerupMult: (json['powerup_mult'] as num?)?.toDouble() ?? 1.5,
        gemMult: (json['gem_mult'] as num?)?.toDouble() ?? 1.5,
      );

  /// True if [failureStreak] should trigger the boost this run.
  bool triggersOn(int failureStreak) =>
      failureStreak > 0 &&
      triggerStreakModulo > 0 &&
      failureStreak % triggerStreakModulo == 0;

  @override
  String toString() =>
      'StreakBoost(every=$triggerStreakModulo, hp=$hpMult, '
      'pu=$powerupMult, gem=$gemMult)';
}
