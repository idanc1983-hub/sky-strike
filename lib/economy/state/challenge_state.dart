import '../constants/challenge_constants.dart';

/// The four challenge types per GDD §4.2.
enum ChallengeType { hunter, survivor, treasure, conqueror }

extension ChallengeTypeJson on ChallengeType {
  /// Stable persistence/server id for this type.
  String get jsonValue {
    switch (this) {
      case ChallengeType.hunter:
        return 'hunter';
      case ChallengeType.survivor:
        return 'survivor';
      case ChallengeType.treasure:
        return 'treasure';
      case ChallengeType.conqueror:
        return 'conqueror';
    }
  }

  /// Display label shown on the operation banner and reveal sequence.
  String get displayName {
    switch (this) {
      case ChallengeType.hunter:
        return 'Hunter';
      case ChallengeType.survivor:
        return 'Survivor';
      case ChallengeType.treasure:
        return 'Treasure Hunter';
      case ChallengeType.conqueror:
        return 'Conqueror';
    }
  }

  /// One-line description used by the reveal sequence and detail screen.
  String get description {
    switch (this) {
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

  /// Ace's reveal line for the FIRST cycle of this type. The Hunter line
  /// is also used unconditionally for the very first cycle since it's
  /// locked to Hunter.
  String get aceRevealLine {
    switch (this) {
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

  /// Default rotation order. Real value comes from remote config.
  static const List<ChallengeType> defaultRotation = [
    ChallengeType.hunter,
    ChallengeType.survivor,
    ChallengeType.treasure,
    ChallengeType.conqueror,
  ];

  /// Parses a persisted/server JSON value back into a [ChallengeType].
  /// Returns `null` for unknown values.
  static ChallengeType? fromJsonValue(String? raw) {
    switch (raw) {
      case 'hunter':
        return ChallengeType.hunter;
      case 'survivor':
        return ChallengeType.survivor;
      case 'treasure':
        return ChallengeType.treasure;
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
class ChallengeView {
  final ChallengeType type;
  final DateTime startedAt;
  final int progress;
  final int target;
  final bool milestone50Claimed;
  final bool milestone100Claimed;

  const ChallengeView({
    required this.type,
    required this.startedAt,
    required this.progress,
    required this.target,
    required this.milestone50Claimed,
    required this.milestone100Claimed,
  });

  /// `0.0..1.0` fraction of target reached. Capped at 1.0 so the UI
  /// progress bar never overshoots.
  double get fraction {
    if (target <= 0) return 0.0;
    final raw = progress / target;
    return raw > 1.0 ? 1.0 : raw;
  }

  /// True when at least the 50% threshold is reached.
  bool get reached50 => fraction >= ChallengeConstants.milestone50Threshold;

  /// True when 100% target is reached.
  bool get reached100 => fraction >= ChallengeConstants.milestone100Threshold;

  /// True when 50% milestone is reached AND not yet claimed.
  bool get canClaim50 => reached50 && !milestone50Claimed;

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
}
