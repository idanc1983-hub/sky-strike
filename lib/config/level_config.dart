import 'remote_config_service.dart';

/// Single enemy entry within a [LevelConfig] — one per tier present at
/// this level. Mirrors the v2 RC `enemies: [{tag, count, power}, ...]`
/// shape from `levels__biome_levels__v1`.
class LevelEnemy {
  /// Tier identifier: one of `enemy_1`, `enemy_2`, `enemy_3`, `enemy_4`,
  /// or `boss`.
  final String tag;

  /// Total count of this tier across the whole level (sum across all
  /// waves). Zero means the tier isn't active at this level.
  final int count;

  /// HP / damage power scalar for this tier at this level. 1.0 is the
  /// baseline (jungle_1 enemy_1); scales up to ~35× by city_60.
  final double power;

  const LevelEnemy({
    required this.tag,
    required this.count,
    required this.power,
  });
}

/// Typed view of one entry in `levels__biome_levels__v1.levels`.
///
/// Built via [LevelConfig.fromRc] which reads from
/// [RemoteConfigService.biomeLevels]. Returns `null` when the requested
/// `(world, stage)` has no RC entry — callers should fall back to their
/// hardcoded defaults so gameplay never crashes on a bad LiveOps push.
class LevelConfig {
  /// Global level number, 1..60. Maps to `(world - 1) * 10 + stage`.
  final int level;

  /// Biome key — one of `jungle`, `desert`, `sea`, `ice`, `volcano`, `city`.
  final String biome;

  /// Number of waves the level lasts (5, 7, or 10 in the v2 curves).
  final int waves;

  /// Player jet damage multiplier. Scales 1.0 → ~4.5 across the 60-level
  /// curve. Drives per-shot damage so progression feels meaningful.
  final double jetMultiplier;

  /// World-level coin-drop multiplier. 1.0 in jungle, escalates by ~25%
  /// each biome up to 2.8× in city.
  final double worldCoinMult;

  /// Per-tier enemy data. Includes every tier present in this level
  /// (count > 0). Tiers absent from the RC entry are omitted entirely.
  final List<LevelEnemy> enemies;

  const LevelConfig({
    required this.level,
    required this.biome,
    required this.waves,
    required this.jetMultiplier,
    required this.worldCoinMult,
    required this.enemies,
  });

  /// Reads the RC entry for the supplied `(world, stage)`. Returns
  /// `null` if the RC blob is missing, the entry is absent, or the
  /// shape is malformed. Callers must fall back to defaults.
  ///
  /// `world` is the biome index 1..6; `stage` is 1..10 within the biome.
  /// The global level number is `(world - 1) * 10 + stage`.
  static LevelConfig? fromRc({
    required int world,
    required int stage,
    RemoteConfigService? rcs,
  }) {
    if (world < 1 || world > 6) return null;
    if (stage < 1 || stage > 10) return null;
    final service = rcs ?? RemoteConfigService.instance;
    final levels = service.biomeLevels;
    if (levels.isEmpty) return null;
    final key = _keyFor(world: world, stage: stage);
    final raw = levels[key];
    if (raw is! Map) return null;
    return _parse(raw);
  }

  /// Visible for tests — accepts a pre-decoded `levels` map (the inner
  /// container value) so unit tests can pin behavior without touching
  /// Firebase.
  static LevelConfig? fromLevelsMap({
    required int world,
    required int stage,
    required Map<String, dynamic> levels,
  }) {
    if (world < 1 || world > 6) return null;
    if (stage < 1 || stage > 10) return null;
    final raw = levels[_keyFor(world: world, stage: stage)];
    if (raw is! Map) return null;
    return _parse(raw);
  }

  static String _keyFor({required int world, required int stage}) {
    const biomeOrder = ['jungle', 'desert', 'sea', 'ice', 'volcano', 'city'];
    final biome = biomeOrder[world - 1];
    final globalLevel = (world - 1) * 10 + stage;
    return '${biome}_$globalLevel';
  }

  static LevelConfig? _parse(Map raw) {
    try {
      final level = (raw['level'] as num?)?.toInt() ?? 0;
      if (level <= 0) return null;
      final enemiesRaw = raw['enemies'];
      final enemies = <LevelEnemy>[];
      if (enemiesRaw is List) {
        for (var i = 0; i < enemiesRaw.length; i++) {
          final e = enemiesRaw[i];
          if (e is! Map) continue;
          // The RC JSON stores enemies as positional entries (no `tag`
          // field). Map index 0→enemy_1, 1→enemy_2, etc. so callers can
          // still look up by [kTagToTier] keys. An explicit `tag` field
          // takes precedence if a future schema adds it.
          final explicit = e['tag'];
          final tag =
              explicit is String && explicit.isNotEmpty
                  ? explicit
                  : 'enemy_${i + 1}';
          final count = (e['count'] as num?)?.toInt() ?? 0;
          final power = (e['power'] as num?)?.toDouble() ?? 0.0;
          enemies.add(LevelEnemy(tag: tag, count: count, power: power));
        }
      }
      // Boss is stored as a sibling field (not inside `enemies`). Lift
      // it into the enemies list under the `boss` tag so `isBossLevel`
      // / `powerFor('boss')` see it.
      final bossRaw = raw['boss'];
      if (bossRaw is Map) {
        final bossCount = (bossRaw['count'] as num?)?.toInt() ?? 0;
        final bossPower = (bossRaw['power'] as num?)?.toDouble() ?? 0.0;
        if (bossCount > 0) {
          enemies.add(LevelEnemy(
            tag: 'boss',
            count: bossCount,
            power: bossPower,
          ));
        }
      }
      return LevelConfig(
        level: level,
        biome: (raw['biome'] as String?) ?? '',
        waves: (raw['waves'] as num?)?.toInt() ?? 10,
        jetMultiplier:
            (raw['jet_multiplier'] as num?)?.toDouble() ?? 1.0,
        worldCoinMult:
            (raw['world_coin_mult'] as num?)?.toDouble() ?? 1.0,
        enemies: enemies,
      );
    } catch (_) {
      // Defensive: any parse hiccup → caller falls back.
      return null;
    }
  }

  /// Returns the [LevelEnemy] for [tag] if present, else `null`.
  LevelEnemy? enemyFor(String tag) {
    for (final e in enemies) {
      if (e.tag == tag) return e;
    }
    return null;
  }

  /// Convenience — power scalar for [tag], defaulting to 1.0 when the
  /// tier isn't present at this level.
  double powerFor(String tag) => enemyFor(tag)?.power ?? 1.0;

  /// Convenience — count for [tag], defaulting to 0.
  int countFor(String tag) => enemyFor(tag)?.count ?? 0;

  /// True when this level has any boss entry with a positive count.
  bool get isBossLevel => countFor('boss') > 0;
}
