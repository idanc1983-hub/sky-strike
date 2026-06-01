/// A bundle of granted rewards. Returned by chest formulas, daily-streak
/// claims, and ad-watch handlers. Applied to [EconomyState] in a single
/// atomic update via `EconomyState.applyReward`.
class Reward {
  final int coins;
  final int gems;

  /// Power-up ids granted (with multiplicity — duplicates mean +1 each).
  final List<String> powerUps;

  /// Optional XP grant. Most economy events do not grant XP through here
  /// — XP comes from kills via `EconomyState.addXP`.
  final int xp;

  /// Optional jet code-id granted (added to ownedJets when applied).
  /// Currently set by the Day-7 streak resolver when the biome jet is
  /// unowned. A reward carries at most one jet — additive `plus()`
  /// keeps the left-hand side's jet if both have one.
  final String? jet;

  const Reward({
    this.coins = 0,
    this.gems = 0,
    this.powerUps = const <String>[],
    this.xp = 0,
    this.jet,
  });

  /// Empty reward. Used as a sentinel for "nothing to grant".
  static const Reward empty = Reward();

  bool get isEmpty =>
      coins == 0 && gems == 0 && powerUps.isEmpty && xp == 0 && jet == null;

  /// Returns a copy of this reward with all numeric fields scaled by
  /// [multiplier]. Used for the loyalty bonus on streak rewards and the
  /// 2× ad-double on biome-end rewards. The jet grant is not scaled —
  /// you either get the jet or you don't.
  ///
  /// Uses round-to-nearest (vs. truncate) so a 50% loyalty bonus on a
  /// 1-gem day actually nudges the value up to 2 instead of silently
  /// flooring back to 1.
  Reward scaled(double multiplier) {
    return Reward(
      coins: (coins * multiplier).round(),
      gems: (gems * multiplier).round(),
      powerUps: powerUps,
      xp: (xp * multiplier).round(),
      jet: jet,
    );
  }

  /// Returns a new reward whose contents are the sum of two rewards. The
  /// power-up lists are concatenated; jets prefer the left-hand side
  /// (the receiver) when both rewards carry one.
  Reward plus(Reward other) {
    return Reward(
      coins: coins + other.coins,
      gems: gems + other.gems,
      powerUps: <String>[...powerUps, ...other.powerUps],
      xp: xp + other.xp,
      jet: jet ?? other.jet,
    );
  }

  /// Returns a copy with the jet field overwritten. Use a non-null
  /// [jetCodeId] to set; pass null to clear.
  Reward copyWithJet(String? jetCodeId) => Reward(
        coins: coins,
        gems: gems,
        powerUps: powerUps,
        xp: xp,
        jet: jetCodeId,
      );

  @override
  String toString() =>
      'Reward(coins=$coins, gems=$gems, powerUps=$powerUps, xp=$xp'
      '${jet == null ? '' : ', jet=$jet'})';
}
