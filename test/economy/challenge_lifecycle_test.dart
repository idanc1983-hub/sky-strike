import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/challenge_lifecycle.dart';
import 'package:skystrike/economy/state/challenge_state.dart';

void main() {
  group('pickCycleType — v2 (newPlayers intro + random rotation)', () {
    test('first-ever cycle is newPlayers (regardless of inputs)', () {
      expect(
        pickCycleType(isFirstEverCycle: true, previousType: null),
        ChallengeType.newPlayers,
      );
      expect(
        pickCycleType(
          isFirstEverCycle: true,
          previousType: ChallengeType.conqueror,
        ),
        ChallengeType.newPlayers,
      );
    });

    test('after newPlayers, picks freely from the rotation', () {
      // Seed Random so the result is deterministic for this assertion.
      final rng = Random(1);
      final pick = pickCycleType(
        isFirstEverCycle: false,
        previousType: ChallengeType.newPlayers,
        rng: rng,
      );
      expect(ChallengeTypeJson.defaultRotation, contains(pick));
    });

    test('after a normal cycle, never picks the same type back-to-back', () {
      // 500 picks with a free Random — none should equal `previous`.
      final rng = Random(42);
      const previous = ChallengeType.hunter;
      for (var i = 0; i < 500; i++) {
        final pick = pickCycleType(
          isFirstEverCycle: false,
          previousType: previous,
          rng: rng,
        );
        expect(pick, isNot(equals(previous)));
        expect(ChallengeTypeJson.defaultRotation, contains(pick));
      }
    });

    test('default rotation never includes newPlayers', () {
      expect(
        ChallengeTypeJson.defaultRotation,
        isNot(contains(ChallengeType.newPlayers)),
      );
    });
  });

  group('nextChallengeType — random-without-repeats', () {
    test('result is always in the rotation and never equals previous', () {
      final rng = Random(7);
      for (final prev in ChallengeTypeJson.defaultRotation) {
        for (var i = 0; i < 100; i++) {
          final next = nextChallengeType(previous: prev, rng: rng);
          expect(next, isNot(equals(prev)));
          expect(ChallengeTypeJson.defaultRotation, contains(next));
        }
      }
    });

    test('honors a remote-config-supplied custom rotation', () {
      const custom = [ChallengeType.treasure, ChallengeType.hunter];
      final rng = Random(0);
      // With a 2-entry rotation, the only non-repeat option is the other
      // type — verifies the no-back-to-back rule is honored.
      expect(
        nextChallengeType(
          previous: ChallengeType.treasure,
          rotation: custom,
          rng: rng,
        ),
        ChallengeType.hunter,
      );
      expect(
        nextChallengeType(
          previous: ChallengeType.hunter,
          rotation: custom,
          rng: rng,
        ),
        ChallengeType.treasure,
      );
    });

    test('previous type not in rotation falls back to a free pick', () {
      const custom = [ChallengeType.hunter, ChallengeType.survivor];
      final rng = Random(123);
      // Conqueror is not in the custom rotation — caller should get a
      // free pick from the rotation as-is.
      final pick = nextChallengeType(
        previous: ChallengeType.conqueror,
        rotation: custom,
        rng: rng,
      );
      expect(custom, contains(pick));
    });

    test('empty rotation defensively returns previous type', () {
      expect(
        nextChallengeType(
          previous: ChallengeType.hunter,
          rotation: const [],
        ),
        ChallengeType.hunter,
      );
    });

    test('single-entry rotation matching previous returns previous', () {
      // Pathological: rotation has only one type and it equals previous.
      // Caller should get the same type back rather than hanging.
      expect(
        nextChallengeType(
          previous: ChallengeType.hunter,
          rotation: const [ChallengeType.hunter],
        ),
        ChallengeType.hunter,
      );
    });
  });

  group('ChallengeView', () {
    final start = DateTime.utc(2026, 5, 8, 10, 0, 0);
    ChallengeView buildView({
      int progress = 0,
      int target = 100,
      bool m100 = false,
    }) {
      return ChallengeView(
        type: ChallengeType.hunter,
        startedAt: start,
        progress: progress,
        target: target,
        milestone100Claimed: m100,
        metric: 'kills',
        stageIndex: 0,
        stageCount: 1,
      );
    }

    test('fraction caps at 1.0', () {
      expect(buildView(progress: 200, target: 100).fraction, 1.0);
    });

    test('reached100 threshold', () {
      expect(buildView(progress: 99, target: 100).reached100, isFalse);
      expect(buildView(progress: 100, target: 100).reached100, isTrue);
    });

    test('canClaim100 respects already-claimed state', () {
      final v = buildView(progress: 100, target: 100);
      expect(v.canClaim100, isTrue);
      final claimed = buildView(
        progress: 100,
        target: 100,
        m100: true,
      );
      expect(claimed.canClaim100, isFalse);
    });

    test('isExpired returns true at exactly 72h', () {
      expect(
        buildView().isExpired(start.add(const Duration(hours: 71))),
        isFalse,
      );
      expect(
        buildView().isExpired(start.add(const Duration(hours: 72))),
        isTrue,
      );
      expect(
        buildView().isExpired(start.add(const Duration(hours: 100))),
        isTrue,
      );
    });

    test('remainingFrom never goes negative', () {
      final past = start.add(const Duration(hours: 100));
      expect(buildView().remainingFrom(past), Duration.zero);
    });
  });
}
