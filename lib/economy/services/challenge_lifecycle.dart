import '../state/challenge_state.dart';

/// Picks the next challenge type given the previous type and a rotation
/// list. The rotation defaults to [ChallengeTypeJson.defaultRotation]
/// but can be overridden by remote config.
///
/// First-ever cycle is FORCED to Hunter (called externally — this
/// function only handles the rotation chain after the first cycle).
ChallengeType nextChallengeType({
  required ChallengeType previous,
  List<ChallengeType> rotation = ChallengeTypeJson.defaultRotation,
}) {
  if (rotation.isEmpty) {
    // Defensive: if remote config sends an empty rotation, stick with
    // the previous type rather than crash.
    return previous;
  }
  final idx = rotation.indexOf(previous);
  if (idx < 0) {
    // Previous type isn't in the current rotation (rotation list was
    // changed server-side). Restart the rotation.
    return rotation.first;
  }
  final nextIdx = (idx + 1) % rotation.length;
  return rotation[nextIdx];
}

/// Returns the type to use when starting a brand-new cycle.
///
/// * If [isFirstEverCycle] is true, returns Hunter unconditionally
///   (GDD §4.1: "First-ever cycle: Always Hunter for predictability").
/// * Otherwise advances the rotation from [previousType].
ChallengeType pickCycleType({
  required bool isFirstEverCycle,
  required ChallengeType? previousType,
  List<ChallengeType> rotation = ChallengeTypeJson.defaultRotation,
}) {
  if (isFirstEverCycle) return ChallengeType.hunter;
  if (previousType == null) return ChallengeType.hunter;
  return nextChallengeType(previous: previousType, rotation: rotation);
}
