import '../../config/remote_config_service.dart';
import 'economy_config.dart';

/// [EconomyConfigSource] backed by [RemoteConfigService]. Reads the
/// already-bounds-clamped numerics produced by the RC adapter; nothing
/// here trusts raw RC strings.
///
/// `null` returns mean "RC has no tuning for this value" — the caller
/// falls back to [EconomyConstants]. That keeps an empty / unreachable
/// RC from zeroing out the economy.
class RemoteEconomyConfigSource implements EconomyConfigSource {
  final RemoteConfigService _rc;

  RemoteEconomyConfigSource({RemoteConfigService? rc})
      : _rc = rc ?? RemoteConfigService.instance;

  @override
  int? waveClearCoins(int wave1to10) {
    if (wave1to10 < 1 || wave1to10 > 10) return null;
    final drops = _rc.coinDrops;
    final list = drops['wave_clear_W1'];
    if (list is! List || wave1to10 - 1 >= list.length) return null;
    final v = list[wave1to10 - 1];
    if (v is num) {
      final i = v.toInt();
      return i < 0 ? 0 : i;
    }
    return null;
  }

  @override
  double? worldCoinMultiplier(int world) {
    if (world < 1 || world > 6) return null;
    // Per-biome multiplier lives on the first level of each biome in
    // the canonical RC `levels_economy` blob: `world_coin_mult`. Same
    // value across all 10 levels in the biome — we just sample level 1.
    final levels = _rc.biomeLevels;
    final biomeKey = _biomeKey(world);
    if (biomeKey == null) return null;
    final entry = levels['${biomeKey}_1'];
    if (entry is! Map) return null;
    final v = entry['world_coin_mult'];
    if (v is num) {
      final d = v.toDouble();
      if (d.isNaN || d.isInfinite || d < 0) return null;
      return d;
    }
    return null;
  }

  @override
  int? stageClearBonus() => _intFromCoinDrops('stage_clear_bonus');

  @override
  int? starBonus(int stars) {
    switch (stars) {
      case 0:
      case 1:
        return 0;
      case 2:
        return _intFromCoinDrops('star_bonus_2star');
      case 3:
        return _intFromCoinDrops('star_bonus_3star');
      default:
        return null;
    }
  }

  @override
  int? coinPickupRegular() => _intFromCoinDrops('coin_pickup_regular');

  @override
  int? coinPickupElite() => _intFromCoinDrops('coin_pickup_elite');

  @override
  int? coinPickupBossPhase() => _intFromCoinDrops('coin_pickup_boss_phase');

  @override
  int? hpDropAtMaxHpCoinValue() => _intFromCoinDrops('hp_pack_at_max_hp');

  @override
  int? powerUpSinglePrice(String powerUpId) {
    final prices = _rc.shopIap['powerup_prices'];
    if (prices is! Map) return null;
    final entry = prices[powerUpId];
    if (entry is! Map) return null;
    final v = entry['coin_price'];
    if (v is num) {
      final i = v.toInt();
      return i < 0 ? 0 : i;
    }
    return null;
  }

  int? _intFromCoinDrops(String key) {
    final v = _rc.coinDrops[key];
    if (v is num) {
      final i = v.toInt();
      return i < 0 ? 0 : i;
    }
    return null;
  }

  static String? _biomeKey(int world) {
    switch (world) {
      case 1:
        return 'jungle';
      case 2:
        return 'desert';
      case 3:
        return 'sea';
      case 4:
        return 'ice';
      case 5:
        return 'volcano';
      case 6:
        return 'city';
    }
    return null;
  }
}
