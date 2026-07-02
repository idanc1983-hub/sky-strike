// remote_config_service.dart
//
// Firebase Remote Config service for SKYSTRIKE.
// Matches deployed Server template v3 / v4 schema:
//   _meta, levels_economy, jets, chests, coins_drop, power_ups, shop,
//   daily_reward, challenges_config, challenge_stages, monetization
//
// All parameters are JSON-typed and parsed into immutable models on first read.
// Offline defaults are bundled as assets under: assets/remote_config_defaults/
//
// Usage:
//   final rc = RemoteConfigService.I;
//   await rc.initialize();
//   final level = rc.levelFor(biome: 'jungle', level: 3);
//   final offer = rc.monetization.configByAssetName('1+2_ironsky');

import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'enemy_glow_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Parameter keys
// ─────────────────────────────────────────────────────────────────────────────

class RcKeys {
  RcKeys._();

  static const meta = '_meta';
  static const levelsEconomy = 'levels_economy';
  static const jets = 'jets';
  static const chests = 'chests';
  static const coinsDrop = 'coins_drop';
  static const powerUps = 'power_ups';
  static const shop = 'shop';
  static const dailyReward = 'daily_reward';
  static const challengesConfig = 'challenges_config';
  static const challengeStages = 'challenge_stages';
  static const monetization = 'monetization';

  static const all = <String>[
    meta,
    levelsEconomy,
    jets,
    chests,
    coinsDrop,
    powerUps,
    shop,
    dailyReward,
    challengesConfig,
    challengeStages,
    monetization,
  ];

  // Enemy glow — primitive-typed keys, defaults registered in code (not assets).
  static const enemyGlowEnabled = 'enemy_glow__enabled__v1';
  static const enemyGlowBlurSigma = 'enemy_glow__blur_sigma__v1';
  static const enemyGlowBaseOpacity = 'enemy_glow__base_opacity__v1';
  static const enemyGlowPulseAmplitude = 'enemy_glow__pulse_amplitude__v1';
  static const enemyGlowPulsePeriodMs = 'enemy_glow__pulse_period_ms__v1';
  static const enemyGlowColors = 'enemy_glow__colors__v1';
}

const Map<String, Object> _enemyGlowPrimitiveDefaults = <String, Object>{
  RcKeys.enemyGlowEnabled: true,
  RcKeys.enemyGlowBlurSigma: 8.0,
  RcKeys.enemyGlowBaseOpacity: 0.55,
  RcKeys.enemyGlowPulseAmplitude: 0.15,
  RcKeys.enemyGlowPulsePeriodMs: 1200,
  RcKeys.enemyGlowColors:
      '{"1":"#EF9F27","2":"#EF9F27","3":"#EF9F27","4":"#45C4F0","5":"#EF9F27","6":"#EF9F27"}',
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true' || v == 'yes' || v == '1';
  if (v is num) return v != 0;
  return false;
}

String? _asString(dynamic v) => v?.toString();

List<dynamic> _asList(dynamic v) =>
    v is List ? v : const <dynamic>[];

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class MetaInfo {
  final String? generated;
  final String? schemaVersion;
  final String? rewardTokenGrammar;

  const MetaInfo({this.generated, this.schemaVersion, this.rewardTokenGrammar});

  factory MetaInfo.fromJson(Map<String, dynamic> j) => MetaInfo(
        generated: _asString(j['generated']),
        schemaVersion: _asString(j['schema_version']),
        rewardTokenGrammar: _asString(j['reward_token_grammar']),
      );
}

// ── levels_economy ──────────────────────────────────────────────────────────

@immutable
class EnemyWave {
  final int count;
  final double power;
  const EnemyWave({required this.count, required this.power});
  factory EnemyWave.fromJson(Map<String, dynamic> j) => EnemyWave(
        count: _asInt(j['count']) ?? 0,
        power: _asDouble(j['power']) ?? 0,
      );
}

@immutable
class BossWave {
  final int count;
  final double power;
  const BossWave({required this.count, required this.power});
  factory BossWave.fromJson(Map<String, dynamic> j) => BossWave(
        count: _asInt(j['count']) ?? 0,
        power: _asDouble(j['power']) ?? 0,
      );
}

@immutable
class LevelConfig {
  final String biome;
  final int level;
  final int waves;
  final double jetMultiplier;
  final double worldCoinMult;
  final List<EnemyWave> enemies;
  final BossWave? boss;

  const LevelConfig({
    required this.biome,
    required this.level,
    required this.waves,
    required this.jetMultiplier,
    required this.worldCoinMult,
    required this.enemies,
    required this.boss,
  });

  factory LevelConfig.fromJson(Map<String, dynamic> j) => LevelConfig(
        biome: _asString(j['biome']) ?? '',
        level: _asInt(j['level']) ?? 0,
        waves: _asInt(j['waves']) ?? 0,
        jetMultiplier: _asDouble(j['jet_multiplier']) ?? 1.0,
        worldCoinMult: _asDouble(j['world_coin_mult']) ?? 1.0,
        enemies: _asList(j['enemies'])
            .whereType<Map>()
            .map((e) => EnemyWave.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        boss: j['boss'] is Map
            ? BossWave.fromJson(Map<String, dynamic>.from(j['boss']))
            : null,
      );
}

// ── jets ────────────────────────────────────────────────────────────────────

@immutable
class JetConfig {
  final String jetId;
  final int basePower;
  final String unlockBiome;
  final int unlockPriceGems;

  const JetConfig({
    required this.jetId,
    required this.basePower,
    required this.unlockBiome,
    required this.unlockPriceGems,
  });

  factory JetConfig.fromJson(Map<String, dynamic> j) => JetConfig(
        jetId: _asString(j['jet_id']) ?? '',
        basePower: _asInt(j['base_power']) ?? 0,
        unlockBiome: _asString(j['unlock_biome']) ?? '',
        unlockPriceGems: _asInt(j['unlock_price_gems']) ?? 0,
      );
}

// ── chests ──────────────────────────────────────────────────────────────────

@immutable
class ChestDefinition {
  final String chestId;
  final int coinMin;
  final int coinMax;
  final int gemMin;
  final int gemMax;
  final double jetDropChance;
  final String? jetId;

  const ChestDefinition({
    required this.chestId,
    required this.coinMin,
    required this.coinMax,
    required this.gemMin,
    required this.gemMax,
    required this.jetDropChance,
    required this.jetId,
  });

  factory ChestDefinition.fromJson(Map<String, dynamic> j) => ChestDefinition(
        chestId: _asString(j['chest_id']) ?? '',
        coinMin: _asInt(j['coin_min']) ?? 0,
        coinMax: _asInt(j['coin_max']) ?? 0,
        gemMin: _asInt(j['gem_min']) ?? 0,
        gemMax: _asInt(j['gem_max']) ?? 0,
        jetDropChance: _asDouble(j['jet_drop_chance']) ?? 0,
        jetId: _asString(j['jet_id']),
      );
}

@immutable
class ChestsConfig {
  final List<ChestDefinition> definitions;
  final String? note;

  const ChestsConfig({required this.definitions, required this.note});

  factory ChestsConfig.fromJson(Map<String, dynamic> j) => ChestsConfig(
        definitions: _asList(j['definitions'])
            .whereType<Map>()
            .map((e) => ChestDefinition.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        note: _asString(j['note']),
      );

  ChestDefinition? byId(String id) =>
      definitions.cast<ChestDefinition?>().firstWhere(
            (c) => c?.chestId == id,
            orElse: () => null,
          );
}

// ── coins_drop ──────────────────────────────────────────────────────────────

@immutable
class CoinsDropConfig {
  final Map<String, num> world1Sources;
  final Map<String, num> waveClear;
  final String? note;

  const CoinsDropConfig({
    required this.world1Sources,
    required this.waveClear,
    required this.note,
  });

  factory CoinsDropConfig.fromJson(Map<String, dynamic> j) {
    Map<String, num> toNumMap(dynamic v) {
      final out = <String, num>{};
      _asMap(v).forEach((k, val) {
        final n = (val is num) ? val : _asDouble(val);
        if (n != null) out[k] = n;
      });
      return out;
    }

    return CoinsDropConfig(
      world1Sources: toNumMap(j['world1_sources']),
      waveClear: toNumMap(j['wave_clear']),
      note: _asString(j['_note']),
    );
  }

  /// World coin value = base wave coin × biome's world_coin_mult.
  num waveCoinFor(int waveIndex1Based) =>
      waveClear['wave_$waveIndex1Based'] ?? 0;
}

// ── power_ups ───────────────────────────────────────────────────────────────

@immutable
class PowerUpConfig {
  final String id;
  final String name;
  final String unlockBiome;
  final String category; // e.g. 'stack'
  final int? durationSec; // null for instant-use (e.g. Bomb)

  const PowerUpConfig({
    required this.id,
    required this.name,
    required this.unlockBiome,
    required this.category,
    required this.durationSec,
  });

  factory PowerUpConfig.fromJson(Map<String, dynamic> j) => PowerUpConfig(
        id: _asString(j['id']) ?? '',
        name: _asString(j['name']) ?? '',
        unlockBiome: _asString(j['unlock_biome']) ?? '',
        category: _asString(j['category']) ?? '',
        durationSec: _asInt(j['duration_sec']),
      );

  bool get isInstant => durationSec == null;
}

// ── shop ────────────────────────────────────────────────────────────────────

@immutable
class CurrencyPack {
  final String id;
  final int amount;
  final double price;

  /// Platform store product id (App Store Connect / Play Console). Null
  /// when the pack hasn't been mapped to a store SKU yet — the shop CTA
  /// stays disabled in that case rather than granting for free.
  final String? iapProductId;

  const CurrencyPack({
    required this.id,
    required this.amount,
    required this.price,
    this.iapProductId,
  });

  factory CurrencyPack.fromJson(Map<String, dynamic> j) => CurrencyPack(
        id: _asString(j['id']) ?? '',
        amount: _asInt(j['amount']) ?? 0,
        price: _asDouble(j['price']) ?? 0,
        iapProductId: _asString(j['iap_product_id']),
      );
}

@immutable
class ChestDeal {
  final String chestId;
  final int coinPrice;
  final int gemPrice;

  const ChestDeal({
    required this.chestId,
    required this.coinPrice,
    required this.gemPrice,
  });

  factory ChestDeal.fromJson(Map<String, dynamic> j) => ChestDeal(
        chestId: _asString(j['chest_id']) ?? '',
        coinPrice: _asInt(j['coin_price']) ?? 0,
        gemPrice: _asInt(j['gem_price']) ?? 0,
      );
}

@immutable
class ShopPowerUp {
  final String powerUpId;
  final int coinPrice;

  const ShopPowerUp({required this.powerUpId, required this.coinPrice});

  factory ShopPowerUp.fromJson(Map<String, dynamic> j) => ShopPowerUp(
        powerUpId: _asString(j['power_up_id']) ?? '',
        coinPrice: _asInt(j['coin_price']) ?? 0,
      );
}

@immutable
class ShopConfig {
  final List<CurrencyPack> coinPacks;
  final List<CurrencyPack> gemPacks;
  final List<ChestDeal> chestDeals;
  final List<ShopPowerUp> powerUps;

  const ShopConfig({
    required this.coinPacks,
    required this.gemPacks,
    required this.chestDeals,
    required this.powerUps,
  });

  factory ShopConfig.fromJson(Map<String, dynamic> j) => ShopConfig(
        coinPacks: _asList(j['coin_packs'])
            .whereType<Map>()
            .map((e) => CurrencyPack.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        gemPacks: _asList(j['gem_packs'])
            .whereType<Map>()
            .map((e) => CurrencyPack.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        chestDeals: _asList(j['chest_deals'])
            .whereType<Map>()
            .map((e) => ChestDeal.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        powerUps: _asList(j['power_ups'])
            .whereType<Map>()
            .map((e) => ShopPowerUp.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

// ── daily_reward ────────────────────────────────────────────────────────────

@immutable
class DailyRewardDay {
  final String dayId; // e.g. 'w1_d3'
  final int week;
  final int coinPrize;
  final int gemPrize;
  final String? chestType;
  final String? jetType; // 'biome_match' on D7
  final String? jetFallback; // when D7 jet already owned

  const DailyRewardDay({
    required this.dayId,
    required this.week,
    required this.coinPrize,
    required this.gemPrize,
    required this.chestType,
    required this.jetType,
    required this.jetFallback,
  });

  factory DailyRewardDay.fromJson(Map<String, dynamic> j) => DailyRewardDay(
        dayId: _asString(j['day_id']) ?? '',
        week: _asInt(j['week']) ?? 0,
        coinPrize: _asInt(j['coin_prize']) ?? 0,
        gemPrize: _asInt(j['gem_prize']) ?? 0,
        chestType: _asString(j['chest_type']),
        jetType: _asString(j['jet_type']),
        jetFallback: _asString(j['jet_fallback']),
      );
}

@immutable
class DailyRewardRule {
  /// Raw value — may be a String (e.g. 'freeze_then_reset') or num (e.g. 50).
  final dynamic value;
  final String? note;

  const DailyRewardRule({required this.value, required this.note});

  factory DailyRewardRule.fromJson(Map<String, dynamic> j) => DailyRewardRule(
        value: j['value'],
        note: _asString(j['note']),
      );

  String? get asString => _asString(value);
  int? get asInt => _asInt(value);
}

@immutable
class DailyRewardConfig {
  final List<DailyRewardDay> days;
  final Map<String, DailyRewardRule> rules;

  const DailyRewardConfig({required this.days, required this.rules});

  factory DailyRewardConfig.fromJson(Map<String, dynamic> j) {
    final rules = <String, DailyRewardRule>{};
    _asMap(j['rules']).forEach((k, v) {
      rules[k] = DailyRewardRule.fromJson(Map<String, dynamic>.from(v as Map));
    });
    return DailyRewardConfig(
      days: _asList(j['days'])
          .whereType<Map>()
          .map((e) => DailyRewardDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      rules: rules,
    );
  }

  DailyRewardDay? dayFor({required int week, required int dayOfWeek}) {
    final id = 'w${week}_d$dayOfWeek';
    return days.cast<DailyRewardDay?>().firstWhere(
          (d) => d?.dayId == id,
          orElse: () => null,
        );
  }

  int get weekCap => rules['week_cap']?.asInt ?? 5;
  int get streakRescueCostGems => rules['streak_rescue_cost_gems']?.asInt ?? 50;
}

// ── challenges_config ───────────────────────────────────────────────────────

@immutable
class ChallengeConfig {
  final String challengeId;
  final String displayName;
  final String metric; // 'kills', 'survival', 'score', 'stars'
  final String targetEnemy; // 'follow_biome'
  final int durationHours;
  final String? popupBg;
  final bool active;
  final bool isIntro; // NEW in v4 (not in deployed v3)

  const ChallengeConfig({
    required this.challengeId,
    required this.displayName,
    required this.metric,
    required this.targetEnemy,
    required this.durationHours,
    required this.popupBg,
    required this.active,
    required this.isIntro,
  });

  factory ChallengeConfig.fromJson(Map<String, dynamic> j) => ChallengeConfig(
        challengeId: _asString(j['challenge_id']) ?? '',
        displayName: _asString(j['display_name']) ?? '',
        metric: _asString(j['metric']) ?? 'kills',
        targetEnemy: _asString(j['target_enemy']) ?? 'follow_biome',
        durationHours: _asInt(j['duration_hours']) ?? 72,
        popupBg: _asString(j['popup_bg']),
        active: _asBool(j['active']),
        isIntro: _asBool(j['is_intro']),
      );
}

// ── challenge_stages ────────────────────────────────────────────────────────

@immutable
class StageConfig {
  final int stage;
  final int goal;
  final String prize; // e.g. '70coin', 'epic_chest', '200coin + epic_chest'

  const StageConfig({
    required this.stage,
    required this.goal,
    required this.prize,
  });

  factory StageConfig.fromJson(Map<String, dynamic> j) => StageConfig(
        stage: _asInt(j['stage']) ?? 0,
        goal: _asInt(j['goal']) ?? 0,
        prize: _asString(j['prize']) ?? '',
      );
}

// ── monetization ────────────────────────────────────────────────────────────

/// duration_hours can be: int (e.g. 48), -1 (persistent), or 'session' (string).
@immutable
class OfferDuration {
  final dynamic raw;
  const OfferDuration._(this.raw);

  factory OfferDuration.fromJson(dynamic v) => OfferDuration._(v);

  bool get isSession => raw is String && (raw as String) == 'session';
  bool get isPersistent => _asInt(raw) == -1;
  int? get hours {
    if (isSession) return null;
    final i = _asInt(raw);
    return (i != null && i >= 0) ? i : null;
  }
}

@immutable
class OfferConfig {
  final String assetName;
  final String displayName;
  final OfferDuration duration;
  final int cooldownHours;
  final String? popupBg;
  final String? lobbyIcon; // NEW in v4 (not in deployed v3)
  final bool active;
  final bool isIntro;
  final String? triggerChallengeId; // 'iron_skies', 'none', etc.
  final int unlockLevel;
  final String? dismissTrigger; // 'duration_expire_or_purchase', etc.

  /// Platform store product id backing this offer's paid CTA. Null when
  /// the offer hasn't been mapped to a store SKU yet — the CTA stays
  /// disabled in that case rather than granting for free.
  final String? productId;

  const OfferConfig({
    required this.assetName,
    required this.displayName,
    required this.duration,
    required this.cooldownHours,
    required this.popupBg,
    required this.lobbyIcon,
    required this.active,
    required this.isIntro,
    required this.triggerChallengeId,
    required this.unlockLevel,
    required this.dismissTrigger,
    this.productId,
  });

  factory OfferConfig.fromJson(Map<String, dynamic> j) => OfferConfig(
        assetName: _asString(j['asset_name']) ?? '',
        displayName: _asString(j['display_name']) ?? '',
        duration: OfferDuration.fromJson(j['duration_hours']),
        cooldownHours: _asInt(j['cooldown_hours']) ?? 0,
        popupBg: _asString(j['popup_bg']),
        lobbyIcon: _asString(j['lobby_icon']),
        active: _asBool(j['active']),
        isIntro: _asBool(j['is_intro']),
        triggerChallengeId: _asString(j['trigger_challenge_id']),
        unlockLevel: _asInt(j['unlock_level']) ?? 0,
        dismissTrigger: _asString(j['dismiss_trigger']),
        productId: _asString(j['product_id']),
      );
}

/// 1+2 layout: 3 slots (1 paid main + 2 free claim slots).
@immutable
class OnePlusTwoSlot {
  final String? reward;
  /// May be num (USD price) or 'free'.
  final dynamic price;

  const OnePlusTwoSlot({required this.reward, required this.price});

  factory OnePlusTwoSlot.fromJson(Map<String, dynamic> j) => OnePlusTwoSlot(
        reward: _asString(j['reward']),
        price: j['price'],
      );

  bool get isFree => price is String && (price as String) == 'free';
  double? get priceUsd => isFree ? null : _asDouble(price);
}

@immutable
class OnePlusTwoOffer {
  final String assetId;
  final List<OnePlusTwoSlot> slots;
  const OnePlusTwoOffer({required this.assetId, required this.slots});
  factory OnePlusTwoOffer.fromJson(Map<String, dynamic> j) => OnePlusTwoOffer(
        assetId: _asString(j['asset_id']) ?? '',
        slots: _asList(j['slots'])
            .whereType<Map>()
            .map((e) => OnePlusTwoSlot.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

/// Snake layout: 6 alternating slots, each with 1-2 rewards and a free/paid price.
@immutable
class SnakeSlot {
  final List<String> rewards;
  final dynamic price; // num or 'free'

  const SnakeSlot({required this.rewards, required this.price});

  factory SnakeSlot.fromJson(Map<String, dynamic> j) => SnakeSlot(
        rewards: _asList(j['rewards'])
            .map((e) => _asString(e))
            .whereType<String>()
            .toList(growable: false),
        price: j['price'],
      );

  bool get isFree => price is String && (price as String) == 'free';
  double? get priceUsd => isFree ? null : _asDouble(price);
}

@immutable
class SnakeOffer {
  final String assetId;
  final List<SnakeSlot> slots;
  const SnakeOffer({required this.assetId, required this.slots});
  factory SnakeOffer.fromJson(Map<String, dynamic> j) => SnakeOffer(
        assetId: _asString(j['asset_id']) ?? '',
        slots: _asList(j['slots'])
            .whereType<Map>()
            .map((e) => SnakeSlot.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

/// Generic layout: 4 rewards in one paid bundle.
@immutable
class GenericOffer {
  final String assetId;
  final List<String> rewards;
  final double price;

  const GenericOffer({
    required this.assetId,
    required this.rewards,
    required this.price,
  });

  factory GenericOffer.fromJson(Map<String, dynamic> j) => GenericOffer(
        assetId: _asString(j['asset_id']) ?? '',
        rewards: _asList(j['rewards'])
            .map((e) => _asString(e))
            .whereType<String>()
            .toList(growable: false),
        price: _asDouble(j['price']) ?? 0,
      );
}

@immutable
class OfferTemplates {
  final List<OnePlusTwoOffer> onePlusTwo;
  final List<SnakeOffer> snake;
  final List<GenericOffer> generic;

  const OfferTemplates({
    required this.onePlusTwo,
    required this.snake,
    required this.generic,
  });

  factory OfferTemplates.fromJson(Map<String, dynamic> j) => OfferTemplates(
        onePlusTwo: _asList(j['one_plus_two'])
            .whereType<Map>()
            .map((e) => OnePlusTwoOffer.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        snake: _asList(j['snake'])
            .whereType<Map>()
            .map((e) => SnakeOffer.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        generic: _asList(j['generic'])
            .whereType<Map>()
            .map((e) => GenericOffer.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

@immutable
class MonetizationConfig {
  final List<OfferConfig> configs;
  final Map<String, String> rules;
  final OfferTemplates templates;

  const MonetizationConfig({
    required this.configs,
    required this.rules,
    required this.templates,
  });

  factory MonetizationConfig.fromJson(Map<String, dynamic> j) {
    final rules = <String, String>{};
    _asMap(j['rules']).forEach((k, v) {
      final s = _asString(v);
      if (s != null) rules[k] = s;
    });
    return MonetizationConfig(
      configs: _asList(j['configs'])
          .whereType<Map>()
          .map((e) => OfferConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      rules: rules,
      templates: OfferTemplates.fromJson(_asMap(j['templates'])),
    );
  }

  OfferConfig? configByAssetName(String assetName) =>
      configs.cast<OfferConfig?>().firstWhere(
            (c) => c?.assetName == assetName,
            orElse: () => null,
          );

  /// Returns offers whose trigger_challenge_id matches and unlock_level <= playerLevel.
  List<OfferConfig> activeOffersFor({
    required String? currentChallengeId,
    required int playerLevel,
  }) =>
      configs
          .where((c) =>
              c.active &&
              c.unlockLevel <= playerLevel &&
              (c.triggerChallengeId == currentChallengeId ||
                  c.triggerChallengeId == 'none'))
          .toList(growable: false);
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService I = RemoteConfigService._();

  static const _defaultsAssetDir = 'assets/remote_config_defaults';

  late final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  // Parsed-model caches (reset on each successful fetchAndActivate)
  MetaInfo? _meta;
  List<LevelConfig>? _levels;
  List<JetConfig>? _jets;
  ChestsConfig? _chests;
  CoinsDropConfig? _coinsDrop;
  List<PowerUpConfig>? _powerUps;
  ShopConfig? _shop;
  DailyRewardConfig? _dailyReward;
  List<ChallengeConfig>? _challenges;
  Map<String, List<StageConfig>>? _stages;
  MonetizationConfig? _monetization;
  EnemyGlowConfig? _enemyGlow;

  /// Initialize with sensible polling intervals.
  /// In debug builds we allow frequent fetches; in release we cache for 1h.
  Future<void> initialize({
    Duration fetchTimeout = const Duration(seconds: 10),
    Duration? minimumFetchInterval,
  }) async {
    if (_initialized) return;
    _initialized = true;

    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: fetchTimeout,
      minimumFetchInterval: minimumFetchInterval ??
          (kDebugMode ? const Duration(minutes: 1) : const Duration(hours: 1)),
    ));

    await _loadAssetDefaults();

    try {
      await _rc.fetchAndActivate();
    } catch (e, st) {
      debugPrint('RemoteConfigService: fetchAndActivate failed: $e\n$st');
      // Continue with cached or default values; getters below still work.
    }

    _clearCaches();
  }

  /// Re-fetch from Firebase (respects minimumFetchInterval) and clear caches.
  Future<bool> refresh() async {
    final ok = await _rc.fetchAndActivate();
    _clearCaches();
    return ok;
  }

  Future<void> _loadAssetDefaults() async {
    final defaults = <String, Object>{};
    for (final key in RcKeys.all) {
      try {
        final raw = await rootBundle.loadString('$_defaultsAssetDir/$key.json');
        defaults[key] = raw;
      } catch (e) {
        debugPrint('RemoteConfigService: missing default asset for "$key" ($e)');
      }
    }
    defaults.addAll(_enemyGlowPrimitiveDefaults);
    if (defaults.isNotEmpty) {
      await _rc.setDefaults(defaults);
    }
  }

  void _clearCaches() {
    _meta = null;
    _levels = null;
    _jets = null;
    _chests = null;
    _coinsDrop = null;
    _powerUps = null;
    _shop = null;
    _dailyReward = null;
    _challenges = null;
    _stages = null;
    _monetization = null;
    _enemyGlow = null;
  }

  /// Seeds the challenge caches directly so unit tests can exercise the
  /// challenge state machine without a live Firebase app. Populating these
  /// caches makes the [challengeStages] / [challenges] getters short-circuit
  /// before they ever touch [FirebaseRemoteConfig.instance] (which throws
  /// `[core/no-app]` in the test harness). Passing empty collections — the
  /// default — mirrors the production "RC has no ladder for this challenge"
  /// path, where callers fall back to their formula defaults. Call
  /// [debugResetForTest] in tearDown to clear seeded fixtures.
  @visibleForTesting
  void debugSeedChallengeConfig({
    Map<String, List<StageConfig>> stages = const {},
    List<ChallengeConfig> challenges = const [],
  }) {
    _stages = stages;
    _challenges = challenges;
  }

  /// Restores the caches seeded by [debugSeedChallengeConfig] to their
  /// uninitialised state so seeded fixtures don't leak between tests.
  @visibleForTesting
  void debugResetForTest() {
    _clearCaches();
    _initialized = false;
  }

  // ── Raw access (for debugging / passthrough) ──────────────────────────────

  String rawString(String key) => _rc.getString(key);

  dynamic rawJson(String key) {
    final s = _rc.getString(key);
    if (s.isEmpty) return null;
    try {
      return jsonDecode(s);
    } catch (e) {
      debugPrint('RemoteConfigService: bad JSON for "$key": $e');
      return null;
    }
  }

  // ── Typed accessors ───────────────────────────────────────────────────────

  MetaInfo get meta =>
      _meta ??= MetaInfo.fromJson(_asMap(rawJson(RcKeys.meta)));

  List<LevelConfig> get levels => _levels ??= _asList(rawJson(RcKeys.levelsEconomy))
      .whereType<Map>()
      .map((e) => LevelConfig.fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);

  List<JetConfig> get jets => _jets ??= _asList(rawJson(RcKeys.jets))
      .whereType<Map>()
      .map((e) => JetConfig.fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);

  ChestsConfig get chests =>
      _chests ??= ChestsConfig.fromJson(_asMap(rawJson(RcKeys.chests)));

  CoinsDropConfig get coinsDrop =>
      _coinsDrop ??= CoinsDropConfig.fromJson(_asMap(rawJson(RcKeys.coinsDrop)));

  List<PowerUpConfig> get powerUps =>
      _powerUps ??= _asList(rawJson(RcKeys.powerUps))
          .whereType<Map>()
          .map((e) => PowerUpConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);

  ShopConfig get shop =>
      _shop ??= ShopConfig.fromJson(_asMap(rawJson(RcKeys.shop)));

  DailyRewardConfig get dailyReward => _dailyReward ??=
      DailyRewardConfig.fromJson(_asMap(rawJson(RcKeys.dailyReward)));

  List<ChallengeConfig> get challenges =>
      _challenges ??= _asList(rawJson(RcKeys.challengesConfig))
          .whereType<Map>()
          .map((e) => ChallengeConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);

  Map<String, List<StageConfig>> get challengeStages {
    if (_stages != null) return _stages!;
    final out = <String, List<StageConfig>>{};
    _asMap(rawJson(RcKeys.challengeStages)).forEach((cid, list) {
      out[cid] = _asList(list)
          .whereType<Map>()
          .map((e) => StageConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    });
    return _stages = out;
  }

  MonetizationConfig get monetization => _monetization ??=
      MonetizationConfig.fromJson(_asMap(rawJson(RcKeys.monetization)));

  /// Cached enemy-glow config. Rebuilt once per successful fetch
  /// (cleared in [_clearCaches]); never rebuild per frame.
  EnemyGlowConfig get enemyGlow {
    final cached = _enemyGlow;
    if (cached != null) return cached;
    try {
      return _enemyGlow = EnemyGlowConfig.fromRemote(
        enabled: _rc.getBool(RcKeys.enemyGlowEnabled),
        blurSigma: _rc.getDouble(RcKeys.enemyGlowBlurSigma),
        baseOpacity: _rc.getDouble(RcKeys.enemyGlowBaseOpacity),
        pulseAmplitude: _rc.getDouble(RcKeys.enemyGlowPulseAmplitude),
        pulsePeriodMs: _rc.getInt(RcKeys.enemyGlowPulsePeriodMs),
        colorsJson: _rc.getString(RcKeys.enemyGlowColors),
      );
    } catch (_) {
      return _enemyGlow = EnemyGlowConfig.fallback;
    }
  }

  // ── Convenience helpers ───────────────────────────────────────────────────

  /// Returns the level config for a given (biome, level) pair, or null.
  LevelConfig? levelFor({required String biome, required int level}) {
    for (final l in levels) {
      if (l.biome == biome && l.level == level) return l;
    }
    return null;
  }

  /// Returns the jet config for an id (e.g. 'basic', 'Wraith X'), or null.
  JetConfig? jetById(String jetId) {
    for (final j in jets) {
      if (j.jetId == jetId) return j;
    }
    return null;
  }

  /// Returns the challenge config by id, or null.
  ChallengeConfig? challengeById(String challengeId) {
    for (final c in challenges) {
      if (c.challengeId == challengeId) return c;
    }
    return null;
  }

  /// Stage ladder for a challenge, or an empty list if unknown.
  List<StageConfig> stagesFor(String challengeId) =>
      challengeStages[challengeId] ?? const <StageConfig>[];

  /// Returns the power-up by id (slugified, e.g. 'speed_boost'), or null.
  PowerUpConfig? powerUpById(String id) {
    for (final p in powerUps) {
      if (p.id == id) return p;
    }
    return null;
  }
}
