/// Per-world enemy base stats.
///
/// Parses `difficulty__enemy_scaling__v1`:
/// ```
/// {"schema_version":1, "worlds":{"1":{"base_hp":10,"base_speed":80,"fire_rate":0.0}}}
/// ```
class EnemyScalingTable {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, EnemyScaling> worlds;

  const EnemyScalingTable({
    required this.schemaVersion,
    required this.worlds,
  });

  static const EnemyScalingTable fallback = EnemyScalingTable(
    schemaVersion: supportedSchemaVersion,
    worlds: <String, EnemyScaling>{},
  );

  factory EnemyScalingTable.fromJson(Map<String, dynamic> json) {
    final int version = (json['schema_version'] as num?)?.toInt() ?? 0;
    final Map<String, dynamic> raw =
        (json['worlds'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = <String, EnemyScaling>{};
    raw.forEach((k, v) {
      if (v is Map) {
        out[k] = EnemyScaling.fromJson(v.cast<String, dynamic>());
      }
    });
    return EnemyScalingTable(schemaVersion: version, worlds: out);
  }

  EnemyScaling lookup({required int world}) =>
      worlds[world.toString()] ?? EnemyScaling.fallback;

  @override
  String toString() =>
      'EnemyScalingTable(v$schemaVersion, ${worlds.length} worlds)';
}

class EnemyScaling {
  final int baseHp;
  final int baseSpeed;
  final double fireRate;

  const EnemyScaling({
    required this.baseHp,
    required this.baseSpeed,
    required this.fireRate,
  });

  static const EnemyScaling fallback =
      EnemyScaling(baseHp: 10, baseSpeed: 80, fireRate: 0.0);

  factory EnemyScaling.fromJson(Map<String, dynamic> json) => EnemyScaling(
        baseHp: (json['base_hp'] as num?)?.toInt() ?? 10,
        baseSpeed: (json['base_speed'] as num?)?.toInt() ?? 80,
        fireRate: (json['fire_rate'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  String toString() =>
      'EnemyScaling(hp=$baseHp, spd=$baseSpeed, fire=$fireRate)';
}
