// remote_config_service.dart
//
// SkyStrike Remote Config integration — v3 (10 parameters, per
// Firebase_RemoteConfig_Instructions.md §Option B).
//
// Wraps firebase_remote_config: fetch + activate once, then read each of
// the 10 top-level parameters and adapt the canonical list-of-objects
// shape into the maps-keyed-by-id shape the rest of the codebase
// expects. Adapter lives entirely inside this file — callers see the
// same public API as the v2 service.
//
// Every parameter is stored as a JSON STRING in Remote Config (valueType:
// JSON). Every getter is defensive: missing / empty / garbled value falls
// back to an empty map/list so the game never crashes on a bad LiveOps push.
//
// Bundled defaults are loaded from assets/remote_config_defaults/ so a
// brand-new install with no network plays with the same config that was
// published to Firebase.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// The 10 top-level Remote Config parameter names, per
/// Firebase_RemoteConfig_Instructions.md.
class RcKeys {
  static const levelsEconomy    = 'levels_economy';
  static const powerUps         = 'power_ups';
  static const jets             = 'jets';
  static const challengesConfig = 'challenges_config';
  static const challengeStages  = 'challenge_stages';
  static const chests           = 'chests';
  static const coinsDrop        = 'coins_drop';
  static const dailyReward      = 'daily_reward';
  static const monetization     = 'monetization';
  static const shop             = 'shop';

  static const all = <String>[
    levelsEconomy,
    powerUps,
    jets,
    challengesConfig,
    challengeStages,
    chests,
    coinsDrop,
    dailyReward,
    monetization,
    shop,
  ];
}

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  /// Call once during app startup, AFTER Firebase.initializeApp().
  /// Returns true if a fresh config was activated, false if it used
  /// cached/last values.
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

    final defaults = await _loadDefaultsFromAssets();
    await _rc.setDefaults(defaults);

    bool activated = false;
    try {
      activated = await _rc.fetchAndActivate();
    } catch (e) {
      // Network failure / timeout: defaults and last-activated values
      // remain in effect, so the game keeps running.
      // ignore: avoid_print
      print('[RemoteConfig] fetchAndActivate failed, using cached/defaults: $e');
    }

    _initialized = true;
    return activated;
  }

  // ---- defaults loading -------------------------------------------------

  static const Map<String, String> _defaultAssets = <String, String>{
    RcKeys.levelsEconomy:
        'assets/remote_config_defaults/levels_economy.json',
    RcKeys.powerUps:
        'assets/remote_config_defaults/power_ups.json',
    RcKeys.jets:
        'assets/remote_config_defaults/jets.json',
    RcKeys.challengesConfig:
        'assets/remote_config_defaults/challenges_config.json',
    RcKeys.challengeStages:
        'assets/remote_config_defaults/challenge_stages.json',
    RcKeys.chests:
        'assets/remote_config_defaults/chests.json',
    RcKeys.coinsDrop:
        'assets/remote_config_defaults/coins_drop.json',
    RcKeys.dailyReward:
        'assets/remote_config_defaults/daily_reward.json',
    RcKeys.monetization:
        'assets/remote_config_defaults/monetization.json',
    RcKeys.shop:
        'assets/remote_config_defaults/shop.json',
  };

  Future<Map<String, dynamic>> _loadDefaultsFromAssets() async {
    final out = <String, dynamic>{};
    for (final entry in _defaultAssets.entries) {
      try {
        out[entry.key] = await rootBundle.loadString(entry.value);
      } catch (e) {
        // ignore: avoid_print
        print('[RemoteConfig] default asset "${entry.value}" missing: $e');
        out[entry.key] = '{}';
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

  // ---- low-level safe readers -------------------------------------------

  /// Reads a raw string parameter. Returns [fallback] when Remote Config
  /// hasn't been initialised yet or the key has no value. Used for plain
  /// config keys that don't need JSON decoding (e.g. third-party API
  /// keys plumbed through RC instead of bundled in the binary).
  String getString(String key, {String fallback = ''}) {
    try {
      final raw = _rc.getString(key);
      return raw.isEmpty ? fallback : raw;
    } catch (_) {
      return fallback;
    }
  }

  dynamic _readJson(String key) {
    final raw = _rc.getString(key);
    if (raw.isEmpty) return null;
    try {
      return json.decode(raw);
    } catch (e) {
      // ignore: avoid_print
      print('[RemoteConfig] bad JSON for "$key", falling back to null: $e');
      return null;
    }
  }

  Map<String, dynamic> _readMap(String key) {
    final v = _readJson(key);
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  List<dynamic> _readList(String key) {
    final v = _readJson(key);
    return v is List ? v : const <dynamic>[];
  }

  // ---- defensive bounds for RC numerics ---------------------------------
  //
  // Mirrors the clamping in EconomyPersistence._Caps. A bad LiveOps push
  // (or a compromised RC project) can flip economy numbers to garbage —
  // these clamps make sure a downstream multiplication can't overflow
  // and that prices/payouts stay inside a sane window. Players see a
  // tuning bug but never a crash and never an outright free million.
  static const int _maxCoinAmount = 1 << 24;   // ~16.7M coins
  static const int _maxGemAmount  = 1 << 20;   // ~1.05M gems
  static const double _maxPriceUsd = 999.99;
  static const double _maxChance   = 1.0;

  /// Clamps a JSON-decoded int (or null) into `[min, max]`. Anything
  /// outside the window collapses to [fallback].
  static int _clampInt(dynamic raw, {
    required int min,
    required int max,
    required int fallback,
  }) {
    if (raw is! num) return fallback;
    final v = raw.toInt();
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  /// Clamps a JSON-decoded double (or null) into `[min, max]`.
  static double _clampDouble(dynamic raw, {
    required double min,
    required double max,
    required double fallback,
  }) {
    if (raw is! num) return fallback;
    final v = raw.toDouble();
    if (v.isNaN || v.isInfinite) return fallback;
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  static int _coin(dynamic raw) =>
      _clampInt(raw, min: 0, max: _maxCoinAmount, fallback: 0);
  static int _gem(dynamic raw) =>
      _clampInt(raw, min: 0, max: _maxGemAmount, fallback: 0);
  static double _priceUsd(dynamic raw) =>
      _clampDouble(raw, min: 0.0, max: _maxPriceUsd, fallback: 0.0);
  static double _chance(dynamic raw) =>
      _clampDouble(raw, min: 0.0, max: _maxChance, fallback: 0.0);

  /// Indexes a list of objects by [idField], dropping that field from
  /// each output value so the result matches the legacy
  /// "Map keyed by id" shape.
  Map<String, dynamic> _indexById(List<dynamic> list, String idField) {
    final out = <String, dynamic>{};
    for (final entry in list) {
      if (entry is! Map) continue;
      final id = entry[idField];
      if (id is! String) continue;
      out[id] = Map<String, dynamic>.from(entry)..remove(idField);
    }
    return out;
  }

  /// Returns true once the parameter blob decodes to something non-null —
  /// kept as a thin compat shim since the canonical v3 blobs no longer
  /// carry a `schema_version` field.
  bool schemaOk(String key, {int expected = 1}) => _readJson(key) != null;

  // ---- LEVELS group -----------------------------------------------------

  /// 60 entries keyed `"<biome>_<level>"` (e.g. `"jungle_1"`).
  /// Each entry preserves the canonical fields: biome, level, waves,
  /// jet_multiplier, world_coin_mult, enemies, boss.
  Map<String, dynamic> get biomeLevels {
    final list = _readList(RcKeys.levelsEconomy);
    final out = <String, dynamic>{};
    for (final entry in list) {
      if (entry is! Map) continue;
      final biome = entry['biome'];
      final level = entry['level'];
      if (biome is String && level is num) {
        out['${biome}_${level.toInt()}'] = Map<String, dynamic>.from(entry);
      }
    }
    return out;
  }

  // ---- JETS / ECONOMY ---------------------------------------------------

  /// Keyed by `jet_id`. Each entry: { base_power, unlock_biome,
  /// unlock_price_gems }.
  Map<String, dynamic> get jetBasePowers =>
      _indexById(_readList(RcKeys.jets), 'jet_id');

  /// 10 power-ups keyed by id. Field names normalized to the legacy
  /// shape so existing callers keep working:
  /// `name` → `display_name`, `duration_sec` → `duration`.
  Map<String, dynamic> get shopPowerups {
    final list = _readList(RcKeys.powerUps);
    final out = <String, dynamic>{};
    for (final entry in list) {
      if (entry is! Map) continue;
      final id = entry['id'];
      if (id is! String) continue;
      final durSec = entry['duration_sec'];
      out[id] = <String, dynamic>{
        if (entry['name'] != null) 'display_name': entry['name'],
        if (entry['unlock_biome'] != null) 'unlock_biome': entry['unlock_biome'],
        if (entry['category'] != null) 'category': entry['category'],
        if (durSec != null)
          'duration': durSec is num && durSec > 0 ? '${durSec.toInt()}s' : '-',
      };
    }
    return out;
  }

  /// 10 chests keyed by chest_id. Each entry: { coin_min, coin_max,
  /// gem_min, gem_max, jet_drop_chance, jet_id }. All numerics clamped
  /// — a malformed RC push can't make a chest pay millions of coins or
  /// a 200% jet-drop chance.
  Map<String, dynamic> get chests {
    final blob = _readMap(RcKeys.chests);
    final defs = blob['definitions'];
    if (defs is! List) return <String, dynamic>{};
    final indexed = _indexById(defs, 'chest_id');
    final out = <String, dynamic>{};
    indexed.forEach((id, raw) {
      if (raw is! Map) return;
      final coinMin = _coin(raw['coin_min']);
      var coinMax = _coin(raw['coin_max']);
      if (coinMax < coinMin) coinMax = coinMin;
      final gemMin = _gem(raw['gem_min']);
      var gemMax = _gem(raw['gem_max']);
      if (gemMax < gemMin) gemMax = gemMin;
      out[id] = <String, dynamic>{
        'coin_min': coinMin,
        'coin_max': coinMax,
        'gem_min': gemMin,
        'gem_max': gemMax,
        'jet_drop_chance': _chance(raw['jet_drop_chance']),
        'jet_id': raw['jet_id'] is String ? raw['jet_id'] : null,
      };
    });
    return out;
  }

  /// Flat numeric config. world1_sources keys are promoted to the top
  /// level (`coin_pickup_regular`, `stage_clear_bonus`, `star_bonus_*`,
  /// etc.) and the canonical `wave_clear: { wave_1: N, ... }` sub-map
  /// is unrolled into the legacy `wave_clear_W1` list indexed 0..9 for
  /// waves 1..10.
  Map<String, dynamic> get coinDrops {
    final blob = _readMap(RcKeys.coinsDrop);
    final out = <String, dynamic>{};
    final sources = blob['world1_sources'];
    if (sources is Map) {
      sources.forEach((k, v) => out[k.toString()] = v);
    }
    final waveClear = blob['wave_clear'];
    if (waveClear is Map) {
      final waves = <dynamic>[];
      for (var i = 1; i <= 10; i++) {
        final v = waveClear['wave_$i'];
        if (v != null) waves.add(v);
      }
      out['wave_clear_W1'] = waves;
    }
    return out;
  }

  /// Shop bundles, adapted from the canonical `shop` blob's lists into
  /// the legacy shape:
  /// - coin_packs:     { id: {coin_amount, price_usd}, ... }
  /// - gem_packs:      { id: {gem_amount,  price_usd}, ... }
  /// - chest_prices:   { chest_id: {coin_price, gem_price}, ... }
  /// - powerup_prices: { power_up_id: {coin_price}, ... }
  Map<String, dynamic> get shopIap {
    final blob = _readMap(RcKeys.shop);
    Map<String, dynamic> packs(String section, String amountField) {
      final raw = blob[section];
      if (raw is! List) return <String, dynamic>{};
      final isCoin = amountField == 'coin_amount';
      final out = <String, dynamic>{};
      for (final entry in raw) {
        if (entry is! Map) continue;
        final id = entry['id'];
        if (id is! String) continue;
        out[id] = <String, dynamic>{
          amountField: isCoin ? _coin(entry['amount']) : _gem(entry['amount']),
          'price_usd': _priceUsd(entry['price']),
        };
      }
      return out;
    }

    final chestDealsRaw = blob['chest_deals'];
    final powerUpsRaw = blob['power_ups'];

    return <String, dynamic>{
      'coin_packs': packs('coin_packs', 'coin_amount'),
      'gem_packs':  packs('gem_packs',  'gem_amount'),
      'chest_prices': chestDealsRaw is List
          ? _indexById(chestDealsRaw, 'chest_id')
          : <String, dynamic>{},
      'powerup_prices': powerUpsRaw is List
          ? _indexById(powerUpsRaw, 'power_up_id')
          : <String, dynamic>{},
    };
  }

  // ---- CHALLENGES group -------------------------------------------------

  /// Keyed by challenge_id. Each entry: { display_name, metric,
  /// target_enemy, duration_hours, popup_bg, active }.
  Map<String, dynamic> get challengeCyclePlan =>
      _indexById(_readList(RcKeys.challengesConfig), 'challenge_id');

  /// Resolves the prize-popup background for [cycleId] from the
  /// `challenges_config` RC entry. The field accepts either a bundled
  /// asset path (`assets/ui/challenges/bg_<cycle>.png`) or an absolute
  /// `http(s)` URL pushed via LiveOps. Returns null when RC has no entry
  /// — caller should pick a sensible fallback.
  String? challengeCyclePopupBg(String cycleId) {
    final entry = challengeCyclePlan[cycleId];
    if (entry is! Map) return null;
    final raw = entry['popup_bg'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// `{ cycle_id: { stages: [{stage, goal, prize}, ...] } }`. The
  /// canonical JSON stores each cycle as a bare list of stages; we wrap
  /// each into a `{stages: [...]}` map so callers reading `.stages`
  /// keep working.
  Map<String, dynamic> get challengeStageLadders {
    final blob = _readMap(RcKeys.challengeStages);
    final out = <String, dynamic>{};
    blob.forEach((cycleId, stages) {
      if (stages is List) {
        out[cycleId] = <String, dynamic>{'stages': stages};
      }
    });
    return out;
  }

  /// Daily login rewards keyed by `day_id` (e.g. "w1_d1"). Field names
  /// normalized: `coin_prize`→`coin`, `gem_prize`→`gem`,
  /// `chest_type`→`chest`, `jet_type`→`jet`.
  Map<String, dynamic> get dailyRewardDays {
    final blob = _readMap(RcKeys.dailyReward);
    final raw = blob['days'];
    if (raw is! List) return <String, dynamic>{};
    final out = <String, dynamic>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final id = entry['day_id'];
      if (id is! String) continue;
      out[id] = <String, dynamic>{
        if (entry['week'] != null) 'week': entry['week'],
        if (entry['coin_prize'] != null) 'coin': entry['coin_prize'],
        if (entry['gem_prize'] != null) 'gem': entry['gem_prize'],
        if (entry['chest_type'] != null) 'chest': entry['chest_type'],
        if (entry['jet_type'] != null) 'jet': entry['jet_type'],
        if (entry['jet_fallback'] != null)
          'jet_fallback': entry['jet_fallback'],
      };
    }
    return out;
  }

  // ---- MONETIZATION group ----------------------------------------------

  Map<String, dynamic> _monetizationTemplate(String section) {
    final blob = _readMap(RcKeys.monetization);
    final templates = blob['templates'];
    if (templates is! Map) return <String, dynamic>{};
    final raw = templates[section];
    return raw is List
        ? _indexById(raw, 'asset_id')
        : <String, dynamic>{};
  }

  /// Popup configs keyed by asset_name. Sourced from
  /// `monetization.configs` in the canonical JSON.
  Map<String, dynamic> get popupOffers {
    final blob = _readMap(RcKeys.monetization);
    final raw = blob['configs'];
    return raw is List
        ? _indexById(raw, 'asset_name')
        : <String, dynamic>{};
  }

  /// Human-readable rules from monetization.rules (reference only).
  Map<String, dynamic> get popupRules {
    final blob = _readMap(RcKeys.monetization);
    final r = blob['rules'];
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  /// 1+2 offers (FTO, first_purchase, per-challenge bundles).
  /// Each: { slots: [{reward, price}, ...] }.
  Map<String, dynamic> get offers1Plus3 =>
      _monetizationTemplate('one_plus_two');

  /// Generic per-challenge offers. Renames `price` → `price_usd` to
  /// match the field name generic_offer_popup reads.
  Map<String, dynamic> get offersGeneric {
    final raw = _monetizationTemplate('generic');
    final out = <String, dynamic>{};
    raw.forEach((id, entry) {
      if (entry is! Map) return;
      out[id] = <String, dynamic>{
        if (entry['rewards'] != null) 'rewards': entry['rewards'],
        if (entry['price'] != null) 'price_usd': entry['price'],
      };
    });
    return out;
  }

  /// "Snake" multi-slot offers. Adapts each slot's `rewards: [...]` list
  /// back into the legacy `reward_1` / `reward_2` field names that
  /// snake_offer_popup reads, and renames `price` → `price_usd`.
  Map<String, dynamic> get offersSnake {
    final raw = _monetizationTemplate('snake');
    final out = <String, dynamic>{};
    raw.forEach((id, entry) {
      if (entry is! Map) return;
      final slots = entry['slots'];
      if (slots is! List) return;
      final adaptedSlots = <Map<String, dynamic>>[];
      for (final slot in slots) {
        if (slot is! Map) continue;
        final rewards = slot['rewards'];
        final adapted = <String, dynamic>{};
        if (rewards is List) {
          if (rewards.isNotEmpty) adapted['reward_1'] = rewards[0];
          if (rewards.length >= 2) adapted['reward_2'] = rewards[1];
        }
        if (slot['price'] != null) adapted['price_usd'] = slot['price'];
        adaptedSlots.add(adapted);
      }
      out[id] = <String, dynamic>{'slots': adaptedSlots};
    });
    return out;
  }

  // ---- small typed convenience helpers ---------------------------------

  /// Base power for a given jet_id (e.g. "basic"), or null if unknown.
  int? jetBasePower(String jetId) {
    final j = jetBasePowers[jetId];
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
      if (v is num) return v.toInt();
    }
    return fallback;
  }

  /// Level entry for a biome and level number.
  Map<String, dynamic>? levelFor(String biome, int level) {
    final v = biomeLevels['${biome}_$level'];
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

  /// Returns the popup-config entry for an offer, or null if unknown.
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
