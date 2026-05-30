import '../constants/economy_constants.dart';

/// Live-tunable economy values. Production wires this to
/// `RemoteConfigService` so LiveOps tuning takes effect at runtime;
/// unit tests leave it untouched and fall back to [EconomyConstants].
///
/// The contract is intentionally narrow — only values that LiveOps
/// genuinely tunes go here. Stable mechanical constants (revive cost
/// brackets, challenge formula coefficients) stay in
/// [EconomyConstants] for now and can be promoted in a later pass.
///
/// All getters are nullable; the calculators do the fallback themselves
/// so the source of truth is always visible at the call site.
abstract class EconomyConfigSource {
  /// Coin reward for clearing wave [wave1to10] of stage in World 1.
  /// Returns null if RC has no entry for this wave.
  int? waveClearCoins(int wave1to10);

  /// World-N coin multiplier. Returns null when no RC tuning is set;
  /// caller falls back to the constants step formula.
  double? worldCoinMultiplier(int world);

  /// First-time stage-clear bonus (World 1 baseline). Returns null if
  /// RC has no value.
  int? stageClearBonus();

  /// Star bonus by star count (0..3). Returns null if RC has no value.
  int? starBonus(int stars);

  /// Coin pickup values. Returns null if RC has no value.
  int? coinPickupRegular();
  int? coinPickupElite();
  int? coinPickupBossPhase();
  int? hpDropAtMaxHpCoinValue();

  /// Shop power-up single-unit price (coin). Returns null if RC has no
  /// value for [powerUpId].
  int? powerUpSinglePrice(String powerUpId);
}

/// Default source: every getter returns null so calculators fall back
/// to [EconomyConstants]. Used in tests + before RC initialises.
class _ConstantOnlySource implements EconomyConfigSource {
  const _ConstantOnlySource();
  @override
  int? waveClearCoins(int _) => null;
  @override
  double? worldCoinMultiplier(int _) => null;
  @override
  int? stageClearBonus() => null;
  @override
  int? starBonus(int _) => null;
  @override
  int? coinPickupRegular() => null;
  @override
  int? coinPickupElite() => null;
  @override
  int? coinPickupBossPhase() => null;
  @override
  int? hpDropAtMaxHpCoinValue() => null;
  @override
  int? powerUpSinglePrice(String _) => null;
}

/// Singleton accessor. The default source is `_ConstantOnlySource` —
/// production replaces it via [setSource] after Firebase + RC init in
/// `main.dart`. Tests are unaffected.
class EconomyConfig {
  EconomyConfig._();

  static EconomyConfigSource _source = const _ConstantOnlySource();

  /// Install a real RC-backed source. Idempotent in practice (just
  /// overwrites). Call once during app startup.
  static void setSource(EconomyConfigSource source) {
    _source = source;
  }

  /// Restore the constants-only fallback. Used by tests to undo a
  /// [setSource] call.
  static void resetForTest() {
    _source = const _ConstantOnlySource();
  }

  // ---- typed accessors ------------------------------------------------------

  static int coinsForWave(int wave1to10) {
    final live = _source.waveClearCoins(wave1to10);
    if (live != null) return live;
    if (wave1to10 < 1 ||
        wave1to10 > EconomyConstants.waveCoinCurveW1.length) {
      return 0;
    }
    return EconomyConstants.waveCoinCurveW1[wave1to10 - 1];
  }

  static double worldCoinMultiplier(int world) {
    final live = _source.worldCoinMultiplier(world);
    if (live != null) return live;
    final w = world < 1 ? 1 : world;
    return 1.0 + EconomyConstants.worldCoinMultiplierStep * (w - 1);
  }

  static int stageClearBonus() =>
      _source.stageClearBonus() ?? EconomyConstants.stageClearBonus;

  static int starBonus(int stars) {
    final live = _source.starBonus(stars);
    if (live != null) return live;
    if (stars < 0 || stars >= EconomyConstants.starBonus.length) return 0;
    return EconomyConstants.starBonus[stars];
  }

  static int coinPickupRegular() =>
      _source.coinPickupRegular() ??
      EconomyConstants.coinPickupValueRegular;

  static int coinPickupElite() =>
      _source.coinPickupElite() ?? EconomyConstants.coinPickupValueElite;

  static int coinPickupBossPhase() =>
      _source.coinPickupBossPhase() ??
      EconomyConstants.coinPickupValueBossPhase;

  static int hpDropAtMaxHpCoinValue() =>
      _source.hpDropAtMaxHpCoinValue() ??
      EconomyConstants.hpDropAtMaxHpCoinValue;

  static int? powerUpSinglePrice(String powerUpId) =>
      _source.powerUpSinglePrice(powerUpId);
}
