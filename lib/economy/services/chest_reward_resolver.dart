import 'dart:math';

import '../state/reward.dart';

/// Pure-function reward roll for a Remote-Config chest definition.
///
/// Reads the canonical chest record produced by
/// `RemoteConfigService.chests[<chest_id>]` (already bounds-clamped by
/// the RC layer) and produces a [ChestRollResult] containing the coin
/// payout, gem payout, and the optional jet id when the jet roll hits.
///
/// Splitting this out of the UI keeps the spend → grant atomicity easy
/// to reason about and unit-test: the shop screen calls `resolve()`,
/// applies the returned [Reward] via [EconomyState], and surfaces the
/// jet drop separately. Network/store calls live nowhere near here.
class ChestRollResult {
  final Reward reward;
  final String? jetId;

  const ChestRollResult({required this.reward, this.jetId});

  bool get hasJet => jetId != null && jetId!.isNotEmpty;
}

class ChestRewardResolver {
  ChestRewardResolver._();

  /// Rolls a chest payout. [definition] is the RC entry (already
  /// clamped); [rng] is injected so tests can pin outcomes.
  ///
  /// `coin_min / coin_max` and `gem_min / gem_max` are inclusive. A
  /// `null` or empty `jet_id` suppresses the jet roll regardless of
  /// `jet_drop_chance`.
  static ChestRollResult resolve({
    required Map<String, dynamic> definition,
    required Random rng,
  }) {
    final coinMin = _readInt(definition['coin_min']);
    final coinMax = _readInt(definition['coin_max']);
    final gemMin = _readInt(definition['gem_min']);
    final gemMax = _readInt(definition['gem_max']);
    final jetChance = _readDouble(definition['jet_drop_chance']);
    final jetId = definition['jet_id'];

    final coins = _rollInclusive(coinMin, coinMax, rng);
    final gems = _rollInclusive(gemMin, gemMax, rng);

    String? grantedJet;
    if (jetId is String && jetId.isNotEmpty && jetChance > 0) {
      if (rng.nextDouble() < jetChance) {
        grantedJet = jetId;
      }
    }

    return ChestRollResult(
      reward: Reward(coins: coins, gems: gems),
      jetId: grantedJet,
    );
  }

  static int _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  static double _readDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return 0.0;
  }

  /// Inclusive `[min, max]` roll. When `max <= min` returns `min` so a
  /// degenerate RC push (e.g. `coin_max: 0`) still produces a deterministic
  /// non-negative payout.
  static int _rollInclusive(int min, int max, Random rng) {
    if (max <= min) return min < 0 ? 0 : min;
    if (min < 0) return rng.nextInt(max + 1);
    return min + rng.nextInt(max - min + 1);
  }
}
