import 'streak_boost.dart';

/// Drop rate config — buckets per (world, wave range) + power-up distribution.
///
/// Logically combines two Firebase keys:
///   - `drops__rates__v1`               → {schema_version, buckets:[...]}
///   - `drops__powerup_distribution__v1`→ {schema_version, distribution:{...}}
///
/// `fromJson` accepts the merged shape constructed by the service:
/// ```
/// {"schema_version":1,
///  "buckets":[{world,wave_min,wave_max,hp_prob,powerup_prob,gem_prob},...],
///  "powerup_distribution":{powerup_id: weight, ...}}
/// ```
class DropRatesConfig {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final List<DropBucket> buckets;
  final Map<String, double> powerupDistribution;

  const DropRatesConfig({
    required this.schemaVersion,
    required this.buckets,
    required this.powerupDistribution,
  });

  static const DropRatesConfig fallback = DropRatesConfig(
    schemaVersion: supportedSchemaVersion,
    buckets: <DropBucket>[],
    powerupDistribution: <String, double>{},
  );

  factory DropRatesConfig.fromJson(Map<String, dynamic> json) {
    final int version = (json['schema_version'] as num?)?.toInt() ?? 0;
    final List rawBuckets = (json['buckets'] as List?) ?? const [];
    final buckets = <DropBucket>[];
    for (final r in rawBuckets) {
      if (r is Map) {
        buckets.add(DropBucket.fromJson(r.cast<String, dynamic>()));
      }
    }
    final Map<String, dynamic> rawDist =
        (json['powerup_distribution'] as Map?)?.cast<String, dynamic>() ??
            const {};
    final dist = <String, double>{};
    rawDist.forEach((k, v) {
      if (v is num) dist[k] = v.toDouble();
    });
    return DropRatesConfig(
      schemaVersion: version,
      buckets: List.unmodifiable(buckets),
      powerupDistribution: Map.unmodifiable(dist),
    );
  }

  /// Find the first bucket covering [world] and [wave]. Returns null if
  /// no bucket matches.
  DropBucket? bucketFor({required int world, required int wave}) {
    for (final b in buckets) {
      if (b.world == world && wave >= b.waveMin && wave <= b.waveMax) {
        return b;
      }
    }
    return null;
  }

  /// Resolve effective drop rates for the current (world, wave, streak).
  /// Applies [streakBoost] when [failureStreak] triggers it.
  EffectiveDropRates lookup({
    required int world,
    required int wave,
    required int failureStreak,
    required StreakBoost streakBoost,
  }) {
    final bucket = bucketFor(world: world, wave: wave) ??
        const DropBucket(
          world: 0,
          waveMin: 0,
          waveMax: 0,
          hpProb: 0.10,
          powerupProb: 0.10,
          gemProb: 0.02,
        );
    final bool boost = streakBoost.triggersOn(failureStreak);
    return EffectiveDropRates(
      hpProb: _clamp01(bucket.hpProb * (boost ? streakBoost.hpMult : 1.0)),
      powerupProb:
          _clamp01(bucket.powerupProb * (boost ? streakBoost.powerupMult : 1.0)),
      gemProb: _clamp01(bucket.gemProb * (boost ? streakBoost.gemMult : 1.0)),
      streakBoostApplied: boost,
      powerupDistribution: powerupDistribution,
    );
  }

  static double _clamp01(double v) {
    if (v.isNaN) return 0.0;
    if (v < 0) return 0.0;
    if (v > 1) return 1.0;
    return v;
  }

  @override
  String toString() =>
      'DropRatesConfig(v$schemaVersion, ${buckets.length} buckets, '
      '${powerupDistribution.length} powerups)';
}

class DropBucket {
  final int world;
  final int waveMin;
  final int waveMax;
  final double hpProb;
  final double powerupProb;
  final double gemProb;

  const DropBucket({
    required this.world,
    required this.waveMin,
    required this.waveMax,
    required this.hpProb,
    required this.powerupProb,
    required this.gemProb,
  });

  factory DropBucket.fromJson(Map<String, dynamic> json) => DropBucket(
        world: (json['world'] as num?)?.toInt() ?? 0,
        waveMin: (json['wave_min'] as num?)?.toInt() ?? 0,
        waveMax: (json['wave_max'] as num?)?.toInt() ?? 0,
        hpProb: (json['hp_prob'] as num?)?.toDouble() ?? 0.0,
        powerupProb: (json['powerup_prob'] as num?)?.toDouble() ?? 0.0,
        gemProb: (json['gem_prob'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  String toString() => 'DropBucket(w=$world, wave=$waveMin..$waveMax, '
      'hp=$hpProb, pu=$powerupProb, gem=$gemProb)';
}

class EffectiveDropRates {
  final double hpProb;
  final double powerupProb;
  final double gemProb;
  final bool streakBoostApplied;
  final Map<String, double> powerupDistribution;

  const EffectiveDropRates({
    required this.hpProb,
    required this.powerupProb,
    required this.gemProb,
    required this.streakBoostApplied,
    required this.powerupDistribution,
  });

  @override
  String toString() => 'EffectiveDropRates(hp=$hpProb, pu=$powerupProb, '
      'gem=$gemProb, boost=$streakBoostApplied)';
}
