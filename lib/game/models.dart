import 'dart:math';
import 'package:flutter/material.dart';
import '../config/level_config.dart';
export 'power_ups.dart';

// ---------------------------------------------------------------------------
// Tuning constants — v2 level wiring
// ---------------------------------------------------------------------------
/// Converts the RC `boss.power` scalar into raw HP. The chosen factor
/// keeps `bossHpForLevel` roughly aligned with the pre-v2
/// [bossHpForWorld] hardcodes at the start of each biome while letting
/// HP scale meaningfully across the 10-stage progression within a world.
const int kBossHpPerPowerPoint = 50;

/// Default wave count when an RC entry has no `waves` field (or RC is
/// unreachable). Matches the legacy pre-v2 behavior.
const int kDefaultWavesPerLevel = 10;

/// Tag-to-tier mapping used by [activeEnemyTiersForLevel] when reading
/// the v2 `enemies` list.
const Map<String, EnemyTier> kTagToTier = {
  'enemy_1': EnemyTier.grunt,
  'enemy_2': EnemyTier.gunship,
  'enemy_3': EnemyTier.drone,
  'enemy_4': EnemyTier.bomber,
  'boss': EnemyTier.boss,
};

// ---------------------------------------------------------------------------
// Enemy tiers
// ---------------------------------------------------------------------------
enum EnemyTier { grunt, gunship, drone, bomber, boss }

class EnemyConfig {
  final EnemyTier tier;
  final int baseHp;
  final double baseSpeed;
  final double renderSize;
  final double hitRadius;
  final int scoreValue;
  final Color placeholderColor;

  const EnemyConfig({
    required this.tier,
    required this.baseHp,
    required this.baseSpeed,
    required this.renderSize,
    required this.hitRadius,
    required this.scoreValue,
    required this.placeholderColor,
  });
}

const Map<EnemyTier, EnemyConfig> kEnemyConfigs = {
  EnemyTier.grunt: EnemyConfig(
    tier: EnemyTier.grunt,
    baseHp: 1,
    baseSpeed: 0.55,
    renderSize: 36,
    hitRadius: 14,
    scoreValue: 10,
    placeholderColor: Color(0xFFAA3333),
  ),
  EnemyTier.gunship: EnemyConfig(
    tier: EnemyTier.gunship,
    baseHp: 2,
    baseSpeed: 0.45,
    renderSize: 44,
    hitRadius: 17,
    scoreValue: 25,
    placeholderColor: Color(0xFFCC6622),
  ),
  EnemyTier.drone: EnemyConfig(
    tier: EnemyTier.drone,
    baseHp: 3,
    baseSpeed: 0.68,
    renderSize: 30,
    hitRadius: 12,
    scoreValue: 40,
    placeholderColor: Color(0xFF2255BB),
  ),
  EnemyTier.bomber: EnemyConfig(
    tier: EnemyTier.bomber,
    baseHp: 4,
    baseSpeed: 0.32,
    renderSize: 52,
    hitRadius: 21,
    scoreValue: 60,
    placeholderColor: Color(0xFF884499),
  ),
  EnemyTier.boss: EnemyConfig(
    tier: EnemyTier.boss,
    baseHp: 1,
    baseSpeed: 0.28,
    renderSize: 80,
    hitRadius: 36,
    scoreValue: 500,
    placeholderColor: Color(0xFFCC1111),
  ),
};

// ---------------------------------------------------------------------------
// Difficulty scaling per stage bracket
// ---------------------------------------------------------------------------
class DifficultyParams {
  final double speedMult;
  final int hpMult;

  const DifficultyParams({required this.speedMult, required this.hpMult});
}

DifficultyParams getDifficulty(int stage) {
  final t = ((stage - 1) ~/ 5).clamp(0, 7);
  return DifficultyParams(
    speedMult: 1.0 + t * 0.18,
    hpMult:    1 + t,
  );
}

// ---------------------------------------------------------------------------
// Wave formulas (wave 1–10 within a stage)
// ---------------------------------------------------------------------------
// Returns concurrent pool size AND kill quota for the wave
int waveEnemyCount(int world, int wave) {
  if (world == 1) return 3 + (wave * 0.4).floor(); // gentle tutorial ramp
  return 4 + (wave * 0.6).floor();
}

double waveEnemySpeed(int wave) => 0.4 + (wave * 0.05);

// Higher number = slower fire. World 1 W1-3 returns 9999 (no fire).
// Result is scaled by 1/0.9 → 10% lower fire rate across the game.
int waveEnemyFireRate(int world, int wave) {
  if (world == 1 && wave <= 3) return 9999;
  final base = world == 1
      ? max(75 - wave * 2, 40)
      : max(60 - wave * 2, 28);
  return (base / 0.9).round();
}

double eliteRatio(int world, int wave) {
  if (world == 1) {
    const w1 = [0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.25, 0.40, 0.55, 0.0];
    return w1[(wave - 1).clamp(0, 9)];
  }
  // Wave 10 is always a pure boss encounter — no elite spawns.
  if (wave >= 10) return 0.0;
  return (0.1 + (wave - 1) * 0.067).clamp(0.0, 0.70);
}

// ---------------------------------------------------------------------------
// Combo & score
// ---------------------------------------------------------------------------
double comboMultiplier(int recentKills) {
  if (recentKills <= 2)  return 1.0;
  if (recentKills <= 4)  return 1.5;
  if (recentKills <= 7)  return 2.0;
  if (recentKills <= 11) return 3.0;
  return 5.0;
}

int scorePerKill(int wave, double combo) =>
    (10 * (1.0 + wave * 0.1) * combo).round();

// Sum of base-score kills across all 9 waves + boss score value.
// Used for the stage-clear 2★/3★ percentage thresholds.
int maxPossibleScore(int world) {
  int total = 0;
  for (int w = 1; w <= 9; w++) {
    total += scorePerKill(w, 1.0) * waveEnemyCount(world, w);
  }
  total += kEnemyConfigs[EnemyTier.boss]!.scoreValue;
  return total;
}

// ---------------------------------------------------------------------------
// Boss HP per world (GDD values)
// ---------------------------------------------------------------------------
int bossHpForWorld(int world) {
  const hps = [250, 900, 1400, 2200, 3200, 5000];
  return hps[(world - 1).clamp(0, 5)];
}

// Frames between boss fire volleys — earlier biomes fire slowly so players can dodge.
// Result is scaled by 1/0.9 → 10% lower fire rate across the game.
int bossFireRate(int world) {
  final base = world == 1 ? 75 : world == 2 ? 60 : 45;
  return (base / 0.9).round();
}

// Boss bullet speed (downward) — slower in World 1 for dodgeability
double bossBulletSpeed(int world) => world == 1 ? 2.0 : 3.0;

// Boss spread bullet dx — narrower spread in World 1
double bossBulletSpread(int world) => world == 1 ? 0.6 : 1.0;

// ---------------------------------------------------------------------------
// Which enemy tiers are active at a given stage (legacy fallback). The
// v2-aware version is [activeEnemyTiersForLevel] which reads from RC.
// ---------------------------------------------------------------------------
List<EnemyTier> activeEnemyTiers(int stage) {
  if (stage <= 4)  return [EnemyTier.grunt];
  if (stage <= 9)  return [EnemyTier.grunt, EnemyTier.gunship];
  if (stage <= 14) return [EnemyTier.grunt, EnemyTier.gunship, EnemyTier.drone];
  return [EnemyTier.grunt, EnemyTier.gunship, EnemyTier.drone, EnemyTier.bomber];
}

// ---------------------------------------------------------------------------
// v2 level-driven helpers — Scope 1 wiring
//
// Each reads the `(world, stage)` entry from
// `levels__biome_levels__v1` via [LevelConfig]. Falls back to the
// legacy hardcoded formula when the RC entry is missing so a stale
// build or LiveOps gap never crashes gameplay.
// ---------------------------------------------------------------------------

/// Number of waves the supplied `(world, stage)` runs for. Reads
/// `waves` from RC; defaults to [kDefaultWavesPerLevel] (=10).
int wavesForLevel(int world, int stage) {
  final cfg = LevelConfig.fromRc(world: world, stage: stage);
  return cfg?.waves ?? kDefaultWavesPerLevel;
}

/// Whether the supplied `(world, stage)` is a boss level — i.e. the RC
/// `enemies` list contains a `boss` tier entry with `count > 0`. When
/// RC has no entry for this level, defaults to true so the legacy
/// "wave 10 is always boss" behavior holds.
bool isBossLevel(int world, int stage) {
  final cfg = LevelConfig.fromRc(world: world, stage: stage);
  if (cfg == null) return true;
  return cfg.isBossLevel;
}

/// Boss HP for the supplied `(world, stage)`. Computed from RC
/// `boss.power × kBossHpPerPowerPoint`; falls back to the per-world
/// hardcode when RC has no entry or no boss tier on this level.
int bossHpForLevel(int world, int stage) {
  final cfg = LevelConfig.fromRc(world: world, stage: stage);
  final bossPower = cfg?.powerFor('boss');
  if (bossPower != null && bossPower > 0) {
    return (bossPower * kBossHpPerPowerPoint).round();
  }
  return bossHpForWorld(world);
}

/// Tiers active at the supplied `(world, stage)`. Reads the RC
/// `enemies` list and includes every tier with `count > 0`. Falls back
/// to [activeEnemyTiers] (the legacy stage-bracket formula) when RC has
/// no entry. The returned list excludes `boss` — callers handle the
/// boss spawn separately (wave 10 of a boss-level).
List<EnemyTier> activeEnemyTiersForLevel(int world, int stage) {
  final cfg = LevelConfig.fromRc(world: world, stage: stage);
  if (cfg == null) {
    // Legacy callers passed a "stage" that was either local 1..10 or
    // global 1..60. Keep the local interpretation by mapping back.
    final globalLevel = (world - 1) * 10 + stage;
    return activeEnemyTiers(globalLevel);
  }
  final out = <EnemyTier>[];
  for (final e in cfg.enemies) {
    if (e.count <= 0) continue;
    final tier = kTagToTier[e.tag];
    if (tier == null || tier == EnemyTier.boss) continue;
    out.add(tier);
  }
  if (out.isEmpty) {
    // Defensive: RC entry present but no non-boss tiers? Fall back to
    // legacy formula so we at least spawn grunts.
    return activeEnemyTiers((world - 1) * 10 + stage);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Biome helpers
// ---------------------------------------------------------------------------
// World ordering follows Levels-economy.xlsx — one biome per 10 levels:
// W1 Jungle (1–10) → W2 Desert (11–20) → W3 Sea (21–30) →
// W4 Arctic / ice (31–40) → W5 Volcano (41–50) → W6 City (51–60).
const List<String> kWorldNames = [
  '', 'Jungle', 'Desert', 'Sea', 'Arctic', 'Volcano', 'City'
];
String worldName(int world) => kWorldNames[world.clamp(1, 6)];

// Biome key strings — match remote config (`unlock_biome` values).
// W4's display name is "Arctic" but its key is "ice".
const _biomeKeys = ['', 'jungle', 'desert', 'sea', 'ice', 'volcano', 'city'];
String biomeName(int world) => _biomeKeys[world.clamp(1, 6)];

String enemyAsset(int world, EnemyTier tier) {
  final name = biomeName(world);
  const suffixes = {
    EnemyTier.grunt:   '',
    EnemyTier.gunship: '_2',
    EnemyTier.drone:   '_3',
    EnemyTier.bomber:  '_4',
  };
  if (tier == EnemyTier.boss) return 'assets/enemies/boss_$name.png';
  return 'assets/enemies/enemy_$name${suffixes[tier]!}.png';
}

// Bullet asset: each biome gets one of the 3 bullet images, cycling round-robin
String bulletAsset(int world) {
  const bullets = ['bullet_1', 'bullet_2', 'bullet_3'];
  return 'assets/bullets/${bullets[(world - 1) % 3]}.png';
}

String enemyBulletAsset(int world) {
  const bullets = ['enemy_bullet_1', 'enemy_bullet_2', 'enemy_bullet_3'];
  return 'assets/bullets/${bullets[(world - 1) % 3]}.png';
}

// ---------------------------------------------------------------------------
// Revive pricing — paid in GEMS, not coins. Mirrors EconomyConstants.
// ---------------------------------------------------------------------------
int reviveGemPrice(int wave) {
  if (wave <= 3)  return 5;
  if (wave <= 6)  return 10;
  if (wave <= 9)  return 15;
  return 20;
}

@Deprecated('Use reviveGemPrice — same value, clearer currency name')
int revivePrice(int wave) => reviveGemPrice(wave);
