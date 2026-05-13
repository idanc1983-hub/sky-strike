/// Per-(world, wave) difficulty curve.
///
/// Parses `difficulty__wave_curves__v1`:
/// ```
/// {
///   "schema_version": 1,
///   "waves": {
///     "1_1": { "hp_mult": 1.0, "speed_mult": 1.0, "spawn_count": 8,
///              "elites_allowed": false, "enemy_fire": false, "is_boss": false },
///     ...
///   }
/// }
/// ```
class WaveCurveTable {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, WaveCurve> waves;

  const WaveCurveTable({
    required this.schemaVersion,
    required this.waves,
  });

  static const WaveCurveTable fallback = WaveCurveTable(
    schemaVersion: supportedSchemaVersion,
    waves: <String, WaveCurve>{},
  );

  factory WaveCurveTable.fromJson(Map<String, dynamic> json) {
    final int version = (json['schema_version'] as num?)?.toInt() ?? 0;
    final Map<String, dynamic> waves =
        (json['waves'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = <String, WaveCurve>{};
    waves.forEach((key, value) {
      if (value is Map) {
        out[key] = WaveCurve.fromJson(value.cast<String, dynamic>());
      }
    });
    return WaveCurveTable(schemaVersion: version, waves: out);
  }

  /// Lookup curve for `(world, wave)`. If the exact key is missing,
  /// extrapolate from the highest known wave in the same world by
  /// growing `hp_mult` 5% per missing wave; otherwise returns the
  /// global fallback `WaveCurve.fallback`.
  WaveCurve lookup({required int world, required int wave}) {
    final String key = '${world}_$wave';
    final exact = waves[key];
    if (exact != null) return exact;

    WaveCurve? best;
    int bestWave = 0;
    for (final entry in waves.entries) {
      final parts = entry.key.split('_');
      if (parts.length != 2) continue;
      final int? w = int.tryParse(parts[0]);
      final int? n = int.tryParse(parts[1]);
      if (w == null || n == null) continue;
      if (w != world) continue;
      if (n < wave && n > bestWave) {
        best = entry.value;
        bestWave = n;
      }
    }
    if (best == null) return WaveCurve.fallback;
    final int gap = wave - bestWave;
    return best.scaled(hpMultGrowth: 1.0 + 0.05 * gap);
  }

  @override
  String toString() =>
      'WaveCurveTable(v$schemaVersion, ${waves.length} waves)';
}

class WaveCurve {
  final double hpMult;
  final double speedMult;
  final int spawnCount;
  final bool elitesAllowed;
  final bool enemyFire;
  final bool isBoss;

  const WaveCurve({
    required this.hpMult,
    required this.speedMult,
    required this.spawnCount,
    required this.elitesAllowed,
    required this.enemyFire,
    required this.isBoss,
  });

  static const WaveCurve fallback = WaveCurve(
    hpMult: 1.0,
    speedMult: 1.0,
    spawnCount: 8,
    elitesAllowed: false,
    enemyFire: false,
    isBoss: false,
  );

  factory WaveCurve.fromJson(Map<String, dynamic> json) {
    return WaveCurve(
      hpMult: (json['hp_mult'] as num?)?.toDouble() ?? 1.0,
      speedMult: (json['speed_mult'] as num?)?.toDouble() ?? 1.0,
      spawnCount: (json['spawn_count'] as num?)?.toInt() ?? 8,
      elitesAllowed: json['elites_allowed'] as bool? ?? false,
      enemyFire: json['enemy_fire'] as bool? ?? false,
      isBoss: json['is_boss'] as bool? ?? false,
    );
  }

  WaveCurve scaled({required double hpMultGrowth}) => WaveCurve(
        hpMult: hpMult * hpMultGrowth,
        speedMult: speedMult,
        spawnCount: spawnCount,
        elitesAllowed: elitesAllowed,
        enemyFire: enemyFire,
        isBoss: isBoss,
      );

  @override
  String toString() =>
      'WaveCurve(hp=$hpMult, spd=$speedMult, n=$spawnCount, '
      'elite=$elitesAllowed, fire=$enemyFire, boss=$isBoss)';
}
