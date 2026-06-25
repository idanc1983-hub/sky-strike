/// How a queued reward should be celebrated on screen.
enum CelebrationKind {
  /// Stage-clear / salvage / daily / purchase coins & gems — aggregated
  /// into a single "total" fly when several queue up.
  currency,

  /// A challenge ladder prize — preceded by the challenge-bar fill
  /// animation, then collected on its own (never merged with [currency]).
  challenge,

  /// A won/bought chest — opened with the chest-open sequence.
  chest,
}

/// A reward that has already been credited to the wallet but whose
/// arrival should still be *celebrated* on screen — the coins/gems fly
/// into the top-right holder and the displayed balance ticks up as they
/// land (see [EconomyState] display-lag handling).
///
/// Purely in-memory: the real balance is persisted immediately at grant
/// time, so a celebration that never plays (e.g. app killed mid-run) just
/// means the animation is skipped — never a lost reward.
class PendingCelebration {
  final CelebrationKind kind;

  /// Coins to fly to the coin holder (0 = none).
  final int coins;

  /// Gems to fly to the gem holder (0 = none).
  final int gems;

  /// For [CelebrationKind.challenge]: whether the prize is a chest (bar
  /// fill → chest open) rather than plain currency (bar fill → fly).
  final bool isChest;

  /// For [CelebrationKind.challenge]: the bar's fill fraction (0..1) before
  /// the goal was crossed, so the animation can fill from there to 100%.
  final double fromFraction;

  /// For [CelebrationKind.challenge]: the challenge's display name.
  final String label;

  const PendingCelebration({
    required this.kind,
    this.coins = 0,
    this.gems = 0,
    this.isChest = false,
    this.fromFraction = 0,
    this.label = '',
  });

  @override
  String toString() => 'PendingCelebration($kind, coins=$coins, gems=$gems, '
      'chest=$isChest, from=$fromFraction, "$label")';
}
