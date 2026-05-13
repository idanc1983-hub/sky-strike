/// Revive pricing brackets + boss cost.
///
/// Parses `economy__revive_pricing__v1`:
/// ```
/// {"schema_version":1,
///  "wave_brackets":[{"wave_min":1,"wave_max":3,"cost_gems":5}, ...],
///  "boss_cost_gems":20,
///  "max_revives_per_run":1}
/// ```
class RevivePricing {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final List<ReviveBracket> waveBrackets;
  final int bossCostGems;
  final int maxRevivesPerRun;

  const RevivePricing({
    required this.schemaVersion,
    required this.waveBrackets,
    required this.bossCostGems,
    required this.maxRevivesPerRun,
  });

  static const RevivePricing fallback = RevivePricing(
    schemaVersion: supportedSchemaVersion,
    waveBrackets: <ReviveBracket>[
      ReviveBracket(waveMin: 1, waveMax: 3, costGems: 5),
      ReviveBracket(waveMin: 4, waveMax: 6, costGems: 10),
      ReviveBracket(waveMin: 7, waveMax: 9, costGems: 15),
    ],
    bossCostGems: 20,
    maxRevivesPerRun: 1,
  );

  factory RevivePricing.fromJson(Map<String, dynamic> json) {
    final List raw = (json['wave_brackets'] as List?) ?? const [];
    final brackets = <ReviveBracket>[];
    for (final r in raw) {
      if (r is Map) {
        brackets.add(ReviveBracket.fromJson(r.cast<String, dynamic>()));
      }
    }
    brackets.sort((a, b) => a.waveMin.compareTo(b.waveMin));
    return RevivePricing(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      waveBrackets: List.unmodifiable(brackets),
      bossCostGems: (json['boss_cost_gems'] as num?)?.toInt() ?? 20,
      maxRevivesPerRun: (json['max_revives_per_run'] as num?)?.toInt() ?? 1,
    );
  }

  int costFor({required int wave, required bool isBoss}) {
    if (isBoss) return bossCostGems;
    for (final b in waveBrackets) {
      if (wave >= b.waveMin && wave <= b.waveMax) return b.costGems;
    }
    if (waveBrackets.isEmpty) return bossCostGems;
    return waveBrackets.last.costGems;
  }

  @override
  String toString() => 'RevivePricing(v$schemaVersion, '
      '${waveBrackets.length} brackets, boss=$bossCostGems, '
      'max/run=$maxRevivesPerRun)';
}

class ReviveBracket {
  final int waveMin;
  final int waveMax;
  final int costGems;

  const ReviveBracket({
    required this.waveMin,
    required this.waveMax,
    required this.costGems,
  });

  factory ReviveBracket.fromJson(Map<String, dynamic> json) => ReviveBracket(
        waveMin: (json['wave_min'] as num?)?.toInt() ?? 0,
        waveMax: (json['wave_max'] as num?)?.toInt() ?? 0,
        costGems: (json['cost_gems'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() =>
      'ReviveBracket(wave=$waveMin..$waveMax, cost=$costGems)';
}
