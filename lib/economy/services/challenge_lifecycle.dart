import 'dart:math';

import '../state/challenge_state.dart';

/// Cycle rotation rules per the v2 economy plan:
///
/// 1. **First-ever cycle**: locked to `newPlayers` (intro). Runs exactly
///    once per account, fired the first time the player crosses level 4.
/// 2. **After `newPlayers`**: random pick from the 4-type rotation.
/// 3. **Subsequent cycles**: random-without-back-to-back-repeat — random
///    from the rotation, excluding whichever type just finished.
///
/// All randomness is injected so unit tests can pin outcomes.

ChallengeType pickCycleType({
  required bool isFirstEverCycle,
  required ChallengeType? previousType,
  List<ChallengeType> rotation = ChallengeTypeJson.defaultRotation,
  Random? rng,
}) {
  // (1) First-ever cycle is always the intro.
  if (isFirstEverCycle) return ChallengeType.newPlayers;

  final r = rng ?? Random();

  // (2) After the intro, do a free random pick — no "previous" constraint
  // because newPlayers isn't in the rotation pool anyway.
  if (previousType == ChallengeType.newPlayers || previousType == null) {
    return _pickRandom(rotation, r);
  }

  // (3) Random-without-back-to-back-repeat over the post-intro pool.
  return nextChallengeType(
    previous: previousType,
    rotation: rotation,
    rng: r,
  );
}

/// Picks the next rotation entry. Excludes [previous] from the candidate
/// set so the same cycle never runs back-to-back.
///
/// Edge cases (defensive):
/// - Empty rotation → returns [previous] (caller decides what to do).
/// - Rotation contains only [previous] → returns [previous] (no choice).
/// - [previous] not in the rotation (e.g. live-ops shrank the pool) →
///   returns a random pick from the rotation as-is.
ChallengeType nextChallengeType({
  required ChallengeType previous,
  List<ChallengeType> rotation = ChallengeTypeJson.defaultRotation,
  Random? rng,
}) {
  if (rotation.isEmpty) return previous;
  final r = rng ?? Random();
  final candidates = rotation.where((t) => t != previous).toList();
  if (candidates.isEmpty) return previous;
  if (!rotation.contains(previous)) {
    // Previous type is no longer in the rotation — pick freely.
    return _pickRandom(rotation, r);
  }
  return _pickRandom(candidates, r);
}

ChallengeType _pickRandom(List<ChallengeType> list, Random rng) {
  return list[rng.nextInt(list.length)];
}
