import 'dart:math';

import '../constants/economy_constants.dart';
import '../constants/power_up_catalog.dart';

/// Picks a random power-up id, restricted to the player's currently-
/// unlocked pool and weighted by recency per GDD §2.6.
///
/// Pure function — no global random; tests pass a seeded [Random].
class PowerUpPicker {
  PowerUpPicker._();

  /// Returns one power-up id from the unlocked pool.
  ///
  /// Weighting (50/30/20):
  ///   * 50% — most-recent biome's pool
  ///   * 30% — previous biome's pool (if any)
  ///   * 20% — earlier biomes' combined pool (if any)
  ///
  /// Edge cases (GDD): a W1 player draws 100% from W1; a W2 player draws
  /// 50% from W2 and 50% from W1 (no earlier pool exists).
  static String pick({
    required int maxWorldReached,
    required Random rng,
  }) {
    final w = maxWorldReached.clamp(1, 6);
    final recentPool = PowerUpCatalog.unlocksByWorld[w] ?? const <String>[];
    final previousPool = w >= 2
        ? PowerUpCatalog.unlocksByWorld[w - 1] ?? const <String>[]
        : const <String>[];
    final earlierPool = <String>[];
    for (var i = 1; i <= w - 2; i++) {
      earlierPool.addAll(
          PowerUpCatalog.unlocksByWorld[i] ?? const <String>[]);
    }

    if (w == 1) {
      return _pickFrom(recentPool, rng);
    }
    if (w == 2) {
      // 50/50 between recent and previous (no earlier pool exists yet).
      return rng.nextDouble() < 0.5
          ? _pickFrom(recentPool, rng)
          : _pickFrom(previousPool, rng);
    }

    final roll = rng.nextDouble();
    if (roll < EconomyConstants.powerUpRecentPoolWeight) {
      return _pickFrom(recentPool, rng);
    }
    const secondCutoff = EconomyConstants.powerUpRecentPoolWeight +
        EconomyConstants.powerUpPreviousPoolWeight;
    if (roll < secondCutoff && previousPool.isNotEmpty) {
      return _pickFrom(previousPool, rng);
    }
    if (earlierPool.isNotEmpty) {
      return _pickFrom(earlierPool, rng);
    }
    // Fallback when only the recent pool is non-empty.
    return _pickFrom(recentPool, rng);
  }

  /// Picks [count] power-up ids by repeatedly calling [pick]. Duplicates
  /// allowed — the caller's inventory adds them up.
  static List<String> pickMany({
    required int count,
    required int maxWorldReached,
    required Random rng,
  }) {
    return List<String>.generate(
      count,
      (_) => pick(maxWorldReached: maxWorldReached, rng: rng),
    );
  }

  static String _pickFrom(List<String> pool, Random rng) {
    if (pool.isEmpty) {
      // Fallback to the canonical W1 pool — keeps callers from crashing
      // if data is malformed in production.
      return PowerUpCatalog.unlocksByWorld[1]!.first;
    }
    return pool[rng.nextInt(pool.length)];
  }
}
