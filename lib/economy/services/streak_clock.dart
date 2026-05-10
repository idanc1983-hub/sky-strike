import '../constants/economy_constants.dart';
import '../state/reward.dart';

/// Outcome of evaluating the daily-streak state on app foreground.
enum StreakAdvanceResult {
  /// Player has already claimed today; nothing to do.
  alreadyClaimedToday,

  /// A fresh day has started — claim is now available.
  claimable,

  /// One or more days were missed since the last claim — streak resets to
  /// Day 1 and is now claimable.
  brokenAndReset,
}

/// Local-time day-boundary detection and streak progression. Pure
/// functions — `now()` is injected so tests don't depend on wall-clock
/// time. See GDD §5.1.
class StreakClock {
  StreakClock._();

  /// Returns the calendar date (year/month/day) for [moment] in the
  /// device's local timezone, dropping the time-of-day component. The
  /// [DateTime] returned is at local midnight.
  static DateTime localDate(DateTime moment) {
    final local = moment.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Number of full local-calendar days between the dates of [a] and [b].
  /// Returns 0 if the same day, positive if [b] is later than [a].
  ///
  /// DST-safe: differences computed off local-midnight `DateTime`s on a
  /// DST-transition day yield 23h or 25h, which `.inDays` truncates to 0
  /// or 1 — wrong by one. We add 12h before truncating so the DST hour
  /// offset cannot push the result below or above the true day count.
  static int dayDelta(DateTime a, DateTime b) {
    final diff =
        localDate(b).difference(localDate(a)) + const Duration(hours: 12);
    return diff.isNegative
        ? -((-diff).inDays)
        : diff.inDays;
  }

  /// Decides the next streak state given the last-claim timestamp.
  ///
  /// * Same calendar day as [lastClaim]: [StreakAdvanceResult.alreadyClaimedToday]
  /// * Exactly 1 day later: [StreakAdvanceResult.claimable] — caller advances `streakDay`
  /// * 2+ days later: [StreakAdvanceResult.brokenAndReset]
  /// * `lastClaim` null (first ever): [StreakAdvanceResult.claimable]
  /// * `lastClaim` is in the future relative to [now] (clock rolled
  ///   back): treated as [StreakAdvanceResult.brokenAndReset] so the
  ///   player isn't permanently locked out of streaks.
  static StreakAdvanceResult evaluate({
    required DateTime now,
    required DateTime? lastClaim,
  }) {
    if (lastClaim == null) return StreakAdvanceResult.claimable;
    final delta = dayDelta(lastClaim, now);
    if (delta < 0) return StreakAdvanceResult.brokenAndReset;
    if (delta == 0) return StreakAdvanceResult.alreadyClaimedToday;
    if (delta == 1) return StreakAdvanceResult.claimable;
    return StreakAdvanceResult.brokenAndReset;
  }

  /// Computes the loyalty multiplier given completed weeks. Capped at
  /// [EconomyConstants.loyaltyBonusCap].
  static double loyaltyMultiplier(int weeksCompleted) {
    final raw = weeksCompleted * EconomyConstants.loyaltyBonusStep;
    return raw > EconomyConstants.loyaltyBonusCap
        ? EconomyConstants.loyaltyBonusCap
        : raw;
  }

  /// Returns the *base* daily-ladder reward for [streakDay] (1..7) before
  /// loyalty scaling. Day 7 is returned as a sentinel `Reward.empty` —
  /// the caller is expected to use [Day7ChestFormula] for that day.
  static Reward baseLadderReward(int streakDay) {
    if (streakDay < 1 || streakDay > 7) return Reward.empty;
    if (streakDay == 7) return Reward.empty;
    final idx = streakDay - 1;
    return Reward(
      coins: EconomyConstants.streakDailyCoins[idx],
      gems: EconomyConstants.streakDailyGems[idx],
      // Power-up grants are filled in by EconomyState using the picker
      // (constants only encode the *count*, not the ids).
    );
  }
}
