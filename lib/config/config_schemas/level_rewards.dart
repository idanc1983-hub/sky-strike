/// Per-level reward grants.
///
/// Parses `progression__level_rewards__v1`:
/// ```
/// {"schema_version":1,
///  "rewards":{"5":{"coins":500,"gems":20,"powerups":["bomb","laser"],"jet":""}}}
/// ```
class LevelRewardsTable {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, LevelRewards> rewards;

  const LevelRewardsTable({
    required this.schemaVersion,
    required this.rewards,
  });

  static const LevelRewardsTable fallback = LevelRewardsTable(
    schemaVersion: supportedSchemaVersion,
    rewards: <String, LevelRewards>{},
  );

  factory LevelRewardsTable.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> raw =
        (json['rewards'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = <String, LevelRewards>{};
    raw.forEach((k, v) {
      if (v is Map) {
        out[k] = LevelRewards.fromJson(v.cast<String, dynamic>());
      }
    });
    return LevelRewardsTable(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      rewards: Map.unmodifiable(out),
    );
  }

  /// Reward for [level] or null if no reward is configured.
  LevelRewards? lookup({required int level}) => rewards[level.toString()];

  @override
  String toString() =>
      'LevelRewardsTable(v$schemaVersion, ${rewards.length} levels)';
}

class LevelRewards {
  final int coins;
  final int gems;
  final List<String> powerups;

  /// Jet id granted at this level, or empty string for none.
  final String jet;

  const LevelRewards({
    required this.coins,
    required this.gems,
    required this.powerups,
    required this.jet,
  });

  factory LevelRewards.fromJson(Map<String, dynamic> json) {
    final List raw = (json['powerups'] as List?) ?? const [];
    final pups = <String>[for (final v in raw) if (v is String) v];
    return LevelRewards(
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      gems: (json['gems'] as num?)?.toInt() ?? 0,
      powerups: List.unmodifiable(pups),
      jet: json['jet'] as String? ?? '',
    );
  }

  bool get hasJet => jet.isNotEmpty;

  @override
  String toString() =>
      'LevelRewards(coins=$coins, gems=$gems, pups=$powerups, jet=$jet)';
}
