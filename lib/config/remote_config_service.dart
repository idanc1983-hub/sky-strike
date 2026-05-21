// remote_config_service.dart
//
// SkyStrike / Air Strike Remote Config integration — v2 (13 parameters).
//
// Wraps firebase_remote_config: fetch + activate once, then read each of the
// 13 parameters by key and parse the JSON-string value into a Dart Map.
//
// Every parameter is stored as a JSON STRING in Remote Config (valueType:
// JSON), so we read getString(key) and json.decode it. Every getter is
// defensive: if the key is missing, empty, or garbled, it falls back to an
// empty map/list — the game never crashes on a bad LiveOps push.
//
// Bundled defaults are loaded from assets/remote_config_defaults/ so a
// brand-new install with no network plays with the same config that was
// published to Firebase.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Parameter keys — keep these in ONE place so a rename is a single edit.
class RcKeys {
  // levels group
  static const levelsBiomeLevels = 'levels__biome_levels__v1';

  // economy group
  static const economyJetBasePowers = 'economy__jet_base_powers__v1';
  static const economyShopPowerups = 'economy__shop_powerups__v1';
  static const economyChests = 'economy__chests__v1';
  static const economyCoinDrops = 'economy__coin_drops__v1';
  static const economyShopIap = 'economy__shop_iap__v1';

  // challenges group
  static const challengesCyclePlan = 'challenges__cycle_plan__v1';
  static const challengesStageLadders = 'challenges__stage_ladders__v1';
  static const challengesDailyReward = 'challenges__daily_reward__v1';

  // monetization group
  static const monetizationPopupConfig = 'monetization__popup_config__v1';
  static const monetizationOffers1_3 = 'monetization__offers_1_3__v1';
  static const monetizationOffersGeneric = 'monetization__offers_generic__v1';
  static const monetizationOffersSnake = 'monetization__offers_snake__v1';

  static const all = <String>[
    levelsBiomeLevels,
    economyJetBasePowers,
    economyShopPowerups,
    economyChests,
    economyCoinDrops,
    economyShopIap,
    challengesCyclePlan,
    challengesStageLadders,
    challengesDailyReward,
    monetizationPopupConfig,
    monetizationOffers1_3,
    monetizationOffersGeneric,
    monetizationOffersSnake,
  ];
}

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  /// Call once during app startup, AFTER Firebase.initializeApp().
  /// Returns true if a fresh config was activated, false if it used cached/last.
  Future<bool> init({
    Duration fetchTimeout = const Duration(seconds: 10),
    // In production keep this at hours; for dev testing use Duration.zero
    // so every launch pulls the newest published template.
    Duration minimumFetchInterval = const Duration(hours: 1),
  }) async {
    if (_initialized) return false;

    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: fetchTimeout,
      minimumFetchInterval: minimumFetchInterval,
    ));

    // Real defaults loaded from bundled assets (generated from params/*.json).
    final defaults = await _loadDefaultsFromAssets();
    await _rc.setDefaults(defaults);

    bool activated = false;
    try {
      activated = await _rc.fetchAndActivate();
    } catch (e) {
      // Network failure / timeout: defaults and last-activated values remain
      // in effect, so the game keeps running. Log for diagnostics.
      // ignore: avoid_print
      print('[RemoteConfig] fetchAndActivate failed, using cached/defaults: $e');
    }

    _initialized = true;
    return activated;
  }

  // ---- defaults loading -------------------------------------------------

  /// Maps each RC key to its bundled asset file (generated from params/*.json).
  /// Add a new entry here whenever a new parameter is added to Remote Config.
  static const Map<String, String> _defaultAssets = <String, String>{
    RcKeys.levelsBiomeLevels:
        'assets/remote_config_defaults/levels__biome_levels__v1.json',
    RcKeys.economyJetBasePowers:
        'assets/remote_config_defaults/economy__jet_base_powers__v1.json',
    RcKeys.economyShopPowerups:
        'assets/remote_config_defaults/economy__shop_powerups__v1.json',
    RcKeys.economyChests:
        'assets/remote_config_defaults/economy__chests__v1.json',
    RcKeys.economyCoinDrops:
        'assets/remote_config_defaults/economy__coin_drops__v1.json',
    RcKeys.economyShopIap:
        'assets/remote_config_defaults/economy__shop_iap__v1.json',
    RcKeys.challengesCyclePlan:
        'assets/remote_config_defaults/challenges__cycle_plan__v1.json',
    RcKeys.challengesStageLadders:
        'assets/remote_config_defaults/challenges__stage_ladders__v1.json',
    RcKeys.challengesDailyReward:
        'assets/remote_config_defaults/challenges__daily_reward__v1.json',
    RcKeys.monetizationPopupConfig:
        'assets/remote_config_defaults/monetization__popup_config__v1.json',
    RcKeys.monetizationOffers1_3:
        'assets/remote_config_defaults/monetization__offers_1_3__v1.json',
    RcKeys.monetizationOffersGeneric:
        'assets/remote_config_defaults/monetization__offers_generic__v1.json',
    RcKeys.monetizationOffersSnake:
        'assets/remote_config_defaults/monetization__offers_snake__v1.json',
  };

  /// Reads each default JSON asset as a raw string. Remote Config defaults
  /// for JSON params are set as the JSON STRING (same form as getString
  /// returns), so the file contents pass through untouched.
  Future<Map<String, dynamic>> _loadDefaultsFromAssets() async {
    final out = <String, dynamic>{};
    for (final entry in _defaultAssets.entries) {
      try {
        out[entry.key] = await rootBundle.loadString(entry.value);
      } catch (e) {
        // Asset missing/misnamed: fall back to a minimal valid stub so
        // setDefaults still succeeds and the app boots.
        // ignore: avoid_print
        print('[RemoteConfig] default asset "${entry.value}" missing: $e');
        out[entry.key] = '{"schema_version":1}';
      }
    }
    return out;
  }

  /// Force a refresh at runtime (e.g. pull-to-refresh on a LiveOps screen).
  Future<bool> refresh() async {
    try {
      return await _rc.fetchAndActivate();
    } catch (e) {
      // ignore: avoid_print
      print('[RemoteConfig] refresh failed: $e');
      return false;
    }
  }

  // ---- core safe readers ------------------------------------------------

  Map<String, dynamic> _readJsonMap(String key) {
    final raw = _rc.getString(key);
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (e) {
      // ignore: avoid_print
      print('[RemoteConfig] bad JSON for "$key", falling back to empty: $e');
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _innerMap(String key, String container) {
    final m = _readJsonMap(key)[container];
    if (m is Map) return Map<String, dynamic>.from(m);
    return <String, dynamic>{};
  }

  /// Optional: warn if a param's schema_version is not what this build expects.
  bool schemaOk(String key, {int expected = 1}) {
    final v = _readJsonMap(key)['schema_version'];
    return v is int && v == expected;
  }

  // ---- LEVELS group -----------------------------------------------------

  /// 60 entries keyed `"<biome>_<level>"` (e.g. `"jungle_1"`).
  /// Each entry: { biome, level, waves, jet_multiplier, world_coin_mult,
  ///               enemies: [{tag, count, power}, ...] }
  Map<String, dynamic> get biomeLevels =>
      _innerMap(RcKeys.levelsBiomeLevels, 'levels');

  // ---- ECONOMY group ----------------------------------------------------

  /// { "Inferno": {base_power, unlock_biome}, ... }
  Map<String, dynamic> get jetBasePowers =>
      _innerMap(RcKeys.economyJetBasePowers, 'jets');

  /// 10 power-ups keyed by slug: { "speed_boost": {display_name, unlock_biome,
  /// category, duration}, ... }
  Map<String, dynamic> get shopPowerups =>
      _innerMap(RcKeys.economyShopPowerups, 'power_ups');

  /// 10 chests: 4 rarity (basic/unique/epic/special) + 6 biome chests.
  /// Each: { coin_min, coin_max, gem_min, gem_max, jet_drop_chance, jet_id }
  Map<String, dynamic> get chests =>
      _innerMap(RcKeys.economyChests, 'chests');

  /// Flat numeric config: coin_pickup_regular, stage_clear_bonus,
  /// wave_clear_W1 (list of 10), star_bonus_*, etc.
  Map<String, dynamic> get coinDrops =>
      _readJsonMap(RcKeys.economyCoinDrops);

  /// Shop bundles. Sub-maps:
  /// - coin_packs: { "coin_1": {coin_amount, price_usd}, ... } (6 packs)
  /// - gem_packs:  { "gem_1":  {gem_amount,  price_usd}, ... } (6 packs)
  /// - chest_prices: { "basic_chest": {coin_price, gem_price}, ... }
  /// - powerup_prices: { "rapid_fire": {coin_price}, ... }
  Map<String, dynamic> get shopIap =>
      _readJsonMap(RcKeys.economyShopIap);

  // ---- CHALLENGES group -------------------------------------------------

  /// 5 cycles: { "iron_skies": {display_name, metric, target_enemy,
  /// duration_hours, popup_bg, active}, ... }
  Map<String, dynamic> get challengeCyclePlan =>
      _innerMap(RcKeys.challengesCyclePlan, 'cycles');

  /// 5 cycles keyed by id, each: { display_name, metric, stages: [{stage,
  /// goal, prize}, ...] }
  Map<String, dynamic> get challengeStageLadders =>
      _innerMap(RcKeys.challengesStageLadders, 'cycles');

  /// Daily login rewards. Keys like "w1_d1".."w4_d7".
  /// Each: { week, coin, gem, chest, jet, jet_fallback }
  Map<String, dynamic> get dailyRewardDays =>
      _innerMap(RcKeys.challengesDailyReward, 'days');

  // ---- MONETIZATION group ----------------------------------------------

  /// Popup configs keyed by asset_name (e.g. "fto", "1+2_ironsky").
  /// Each: { display_name, duration_hours, cooldown_hours, popup_bg, active,
  /// is_intro, trigger_challenge_id, unlock_level, dismiss_trigger }
  Map<String, dynamic> get popupOffers =>
      _innerMap(RcKeys.monetizationPopupConfig, 'offers');

  /// Human-readable rules from the popup config xlsx (reference only).
  Map<String, dynamic> get popupRules =>
      _innerMap(RcKeys.monetizationPopupConfig, 'rules');

  /// 1+3 offers (FTO, first_purchase, per-challenge bundles).
  /// Each: { slots: [{reward, price}, {reward, price}, {reward, price}] }
  Map<String, dynamic> get offers1Plus3 =>
      _innerMap(RcKeys.monetizationOffers1_3, 'offers');

  /// Generic per-challenge offers.
  /// Each: { rewards: [list of strings], price_usd }
  Map<String, dynamic> get offersGeneric =>
      _innerMap(RcKeys.monetizationOffersGeneric, 'offers');

  /// "Snake" multi-slot offers per challenge.
  /// Each: { slots: [{reward_1, reward_2?, price}, ...] }
  Map<String, dynamic> get offersSnake =>
      _innerMap(RcKeys.monetizationOffersSnake, 'offers');

  // ---- small typed convenience helpers ---------------------------------

  /// Base power for a given jet name (e.g. "Inferno"), or null if unknown.
  int? jetBasePower(String jetName) {
    final j = jetBasePowers[jetName];
    if (j is Map && j['base_power'] is int) return j['base_power'] as int;
    if (j is Map && j['base_power'] is num) {
      return (j['base_power'] as num).toInt();
    }
    return null;
  }

  /// Coins awarded for clearing wave [waveIndex] (0-based) in world 1.
  int waveClearCoins(int waveIndex, {int fallback = 0}) {
    final list = coinDrops['wave_clear_W1'];
    if (list is List && waveIndex >= 0 && waveIndex < list.length) {
      final v = list[waveIndex];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return fallback;
  }

  /// Level entry for a biome and level number, e.g. levelFor('jungle', 1).
  /// Returns the full {biome, level, waves, jet_multiplier, world_coin_mult,
  /// enemies} map, or null if missing.
  Map<String, dynamic>? levelFor(String biome, int level) {
    final key = '${biome}_$level';
    final v = biomeLevels[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Coin pack price in USD, e.g. coinPackPriceUsd('coin_3') -> 4.99.
  double? coinPackPriceUsd(String packId) {
    final p = (shopIap['coin_packs'] as Map?)?[packId];
    if (p is Map && p['price_usd'] is num) {
      return (p['price_usd'] as num).toDouble();
    }
    return null;
  }

  /// Returns the popup-config entry for an offer (active/triggers/etc.),
  /// or null if unknown.
  Map<String, dynamic>? popupFor(String assetName) {
    final v = popupOffers[assetName];
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// True if a popup offer is marked active in Remote Config.
  bool isOfferActive(String assetName) {
    final p = popupFor(assetName);
    return p != null && p['active'] == true;
  }

  /// Daily reward for a given week (1-based) and day (1..7).
  Map<String, dynamic>? dailyReward(int week, int day) {
    final v = dailyRewardDays['w${week}_d$day'];
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }
}
