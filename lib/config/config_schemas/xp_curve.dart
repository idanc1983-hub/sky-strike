/// Cumulative XP curve and level cap.
///
/// Parses `progression__xp_curve__v1`:
/// ```
/// {"schema_version":1, "level_cap":100, "xp_cumulative":[0,100,250,...]}
/// ```
///
/// Index `i` in [xpCumulative] = XP required to reach level `i+1`.
/// `xpCumulative[0]` is always 0.
class XpCurve {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final int levelCap;
  final List<int> xpCumulative;

  const XpCurve({
    required this.schemaVersion,
    required this.levelCap,
    required this.xpCumulative,
  });

  static const XpCurve fallback = XpCurve(
    schemaVersion: supportedSchemaVersion,
    levelCap: 100,
    xpCumulative: <int>[0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200],
  );

  factory XpCurve.fromJson(Map<String, dynamic> json) {
    final List raw = (json['xp_cumulative'] as List?) ?? const [];
    final xp = <int>[for (final v in raw) if (v is num) v.toInt()];
    return XpCurve(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      levelCap: (json['level_cap'] as num?)?.toInt() ?? 100,
      xpCumulative: List.unmodifiable(xp),
    );
  }

  /// Player's level given total XP earned. Capped at [levelCap].
  int levelFor(int totalXp) {
    int level = 1;
    for (int i = 1; i < xpCumulative.length; i++) {
      if (totalXp >= xpCumulative[i]) {
        level = i + 1;
      } else {
        break;
      }
    }
    if (level > levelCap) return levelCap;
    return level;
  }

  /// XP required to reach [level]. Returns the last bucket's value if
  /// [level] exceeds the table.
  int xpRequiredFor(int level) {
    if (xpCumulative.isEmpty) return 0;
    final i = level - 1;
    if (i < 0) return xpCumulative.first;
    if (i >= xpCumulative.length) return xpCumulative.last;
    return xpCumulative[i];
  }

  @override
  String toString() =>
      'XpCurve(v$schemaVersion, cap=$levelCap, ${xpCumulative.length} levels)';
}
