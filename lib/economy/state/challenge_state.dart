import '../constants/challenge_constants.dart';

/// Challenge cycle types per the v2 economy plan.
///
/// `newPlayers` is the **intro-only** cycle — runs exactly once per
/// account when challenges first unlock (player clears stage 3), then
/// never appears in rotation again. The other four rotate randomly with
/// the "no repeat back-to-back" rule. The reveal flag is persisted, so
/// the 72h timer continues across app launches and only resets when
/// the app is reinstalled.
enum ChallengeType {
  newPlayers,
  hunter,
  survivor,
  treasure,
  conqueror,
}

extension ChallengeTypeJson on ChallengeType {
  /// Stable persistence/server id for this type. Matches the RC keys in
  /// `challenges__cycle_plan__v1` / `challenges__stage_ladders__v1`.
  String get jsonValue {
    switch (this) {
      case ChallengeType.newPlayers:
        return 'new_players';
      case ChallengeType.hunter:
        return 'iron_skies';
      case ChallengeType.survivor:
        return 'last_stand';
      case ChallengeType.treasure:
        return 'golden_sky';
      case ChallengeType.conqueror:
        return 'star_ascent';
    }
  }

  /// Display label shown on the operation banner.
  String get displayName {
    switch (this) {
      case ChallengeType.newPlayers:
        return 'New Pilots';
      case ChallengeType.hunter:
        return 'Iron Skies';
      case ChallengeType.survivor:
        return 'Last Stand';
      case ChallengeType.treasure:
        return 'Golden Sky';
      case ChallengeType.conqueror:
        return 'Star Ascent';
    }
  }

  /// One-line description used by the challenge detail screen.
  String get description {
    switch (this) {
      case ChallengeType.newPlayers:
        return 'First operation — get a feel for the cycle';
      case ChallengeType.hunter:
        return 'Destroy enemies of the current biome';
      case ChallengeType.survivor:
        return 'Clear stages without dying';
      case ChallengeType.treasure:
        return 'Earn coins from stage gameplay';
      case ChallengeType.conqueror:
        return 'Clear stages with 2★ or higher';
    }
  }

  /// Ace's reveal line for the FIRST cycle of this type. New Pilots is
  /// shown once at level-4 unlock; the other lines run on first
  /// rotation pick of each type.
  String get aceRevealLine {
    switch (this) {
      case ChallengeType.newPlayers:
        return 'New op unlocked. Take it slow — this one\'s a warm-up.';
      case ChallengeType.hunter:
        return 'Big op coming up — grind some kills, claim a chest.';
      case ChallengeType.survivor:
        return "Tricky one — clear stages WITHOUT dying. You got this.";
      case ChallengeType.treasure:
        return 'Time to stack coins. Big haul if you do it right.';
      case ChallengeType.conqueror:
        return "Clean clears only. 2 stars or better. Show 'em who's boss.";
    }
  }

  /// Post-intro rotation pool — the 4 types that cycle randomly after
  /// the one-time `newPlayers` intro. **Does NOT include `newPlayers`**
  /// by design: that type is intro-only.
  static const List<ChallengeType> defaultRotation = [
    ChallengeType.hunter,
    ChallengeType.survivor,
    ChallengeType.treasure,
    ChallengeType.conqueror,
  ];

  /// Parses a persisted/server JSON value back into a [ChallengeType].
  /// Accepts both the new v2 RC ids (e.g. `iron_skies`) and the legacy
  /// pre-v2 ids (e.g. `hunter`) so old saves still load.
  static ChallengeType? fromJsonValue(String? raw) {
    switch (raw) {
      case 'new_players':
        return ChallengeType.newPlayers;
      case 'iron_skies':
      case 'hunter':
        return ChallengeType.hunter;
      case 'last_stand':
      case 'survivor':
        return ChallengeType.survivor;
      case 'golden_sky':
      case 'treasure':
        return ChallengeType.treasure;
      case 'star_ascent':
      case 'conqueror':
        return ChallengeType.conqueror;
      default:
        return null;
    }
  }
}

/// Read-only computed view of the current challenge — used by UI widgets
/// that don't need to mutate state. EconomyState builds one of these on
/// demand from its mutable backing fields.
///
/// **v2 change:** the 50% mid-cycle milestone was removed. Players see a
/// single reward at cycle completion (100%).
class ChallengeView {
  final ChallengeType type;
  final DateTime startedAt;
  final int progress;
  final int target;
  final bool milestone100Claimed;

  /// RC `metric` for the active cycle: 'kills', 'survival', 'score', or
  /// 'stars'. Drives the unit label in the progress bar (e.g. "44/50
  /// kills"). Falls back to 'kills' when RC is unavailable.
  final String metric;

  /// 0-based index of the current stage in the RC ladder.
  final int stageIndex;

  /// Total number of stages in the active cycle's RC ladder.
  final int stageCount;

  const ChallengeView({
    required this.type,
    required this.startedAt,
    required this.progress,
    required this.target,
    required this.milestone100Claimed,
    required this.metric,
    required this.stageIndex,
    required this.stageCount,
  });

  /// True when the player is on the final stage of the ladder. Used by
  /// the progression code to clamp progress and stop counting once the
  /// last goal is met.
  bool get isOnFinalStage =>
      stageCount > 0 && stageIndex >= stageCount - 1;

  /// True when every stage in the ladder has been cleared (i.e. progress
  /// has reached the final stage's goal). Once true, gameplay events no
  /// longer increment progress for this cycle.
  bool get allStagesComplete =>
      isOnFinalStage && target > 0 && progress >= target;

  /// `0.0..1.0` fraction of target reached. Capped at 1.0 so the UI
  /// progress bar never overshoots.
  double get fraction {
    if (target <= 0) return 0.0;
    final raw = progress / target;
    return raw > 1.0 ? 1.0 : raw;
  }

  /// True when 100% target is reached.
  bool get reached100 => fraction >= ChallengeConstants.milestone100Threshold;

  /// True when 100% milestone is reached AND not yet claimed.
  bool get canClaim100 => reached100 && !milestone100Claimed;

  /// Time remaining in the current cycle. Returns Duration.zero when the
  /// cycle has elapsed (caller should auto-claim and start a new cycle).
  Duration remainingFrom(DateTime now) {
    final endsAt = startedAt.add(ChallengeConstants.cycleDuration);
    final diff = endsAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// True when the cycle has elapsed (regardless of progress).
  bool isExpired(DateTime now) {
    return !now.isBefore(startedAt.add(ChallengeConstants.cycleDuration));
  }

  /// Player-facing unit label for the active metric. Used to swap the
  /// generic "pts" suffix on the progress bar for something the player
  /// recognises ("44/50 kills" reads better than "44/50 pts").
  String get metricLabel => metricLabelFor(metric);
}

/// Returns the player-facing unit string for an RC `metric` value.
/// Centralised so the popup, home card, and operation banner all show
/// the same label. Unknown metrics fall back to 'pts' so a future RC
/// addition never renders an empty unit.
String metricLabelFor(String metric) {
  switch (metric) {
    case 'kills':
      return 'kills';
    case 'survival':
      return 'survives';
    case 'score':
      return 'score';
    case 'stars':
      return 'stars';
    default:
      return 'pts';
  }
}
