import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/challenge_lifecycle.dart';
import 'package:skystrike/economy/state/challenge_state.dart';

void main() {
  group('pickCycleType', () {
    test('first-ever cycle is locked to Hunter regardless of input', () {
      expect(
        pickCycleType(isFirstEverCycle: true, previousType: null),
        ChallengeType.hunter,
      );
      expect(
        pickCycleType(
          isFirstEverCycle: true,
          previousType: ChallengeType.conqueror,
        ),
        ChallengeType.hunter,
      );
    });

    test('null previous outside first-ever still falls back to Hunter', () {
      expect(
        pickCycleType(isFirstEverCycle: false, previousType: null),
        ChallengeType.hunter,
      );
    });

    test('default rotation advances Hunter → Survivor → Treasure → Conqueror',
        () {
      expect(
        nextChallengeType(previous: ChallengeType.hunter),
        ChallengeType.survivor,
      );
      expect(
        nextChallengeType(previous: ChallengeType.survivor),
        ChallengeType.treasure,
      );
      expect(
        nextChallengeType(previous: ChallengeType.treasure),
        ChallengeType.conqueror,
      );
      expect(
        nextChallengeType(previous: ChallengeType.conqueror),
        ChallengeType.hunter,
      );
    });

    test('honors a remote-config-supplied custom rotation', () {
      const custom = [ChallengeType.treasure, ChallengeType.hunter];
      expect(
        nextChallengeType(
          previous: ChallengeType.treasure,
          rotation: custom,
        ),
        ChallengeType.hunter,
      );
      expect(
        nextChallengeType(
          previous: ChallengeType.hunter,
          rotation: custom,
        ),
        ChallengeType.treasure,
      );
    });

    test('previous type missing from rotation restarts cycle', () {
      const custom = [ChallengeType.hunter, ChallengeType.survivor];
      // Conqueror is not in the custom rotation — should restart at first.
      expect(
        nextChallengeType(
          previous: ChallengeType.conqueror,
          rotation: custom,
        ),
        ChallengeType.hunter,
      );
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
  });

  group('ChallengeView', () {
    final start = DateTime.utc(2026, 5, 8, 10, 0, 0);
    ChallengeView buildView({
      int progress = 0,
      int target = 100,
      bool m50 = false,
      bool m100 = false,
    }) {
      return ChallengeView(
        type: ChallengeType.hunter,
        startedAt: start,
        progress: progress,
        target: target,
        milestone50Claimed: m50,
        milestone100Claimed: m100,
      );
    }

    test('fraction caps at 1.0', () {
      expect(buildView(progress: 200, target: 100).fraction, 1.0);
    });

    test('reached50 / reached100 thresholds', () {
      expect(buildView(progress: 49, target: 100).reached50, isFalse);
      expect(buildView(progress: 50, target: 100).reached50, isTrue);
      expect(buildView(progress: 99, target: 100).reached100, isFalse);
      expect(buildView(progress: 100, target: 100).reached100, isTrue);
    });

    test('canClaim flags respect already-claimed state', () {
      final v = buildView(progress: 100, target: 100);
      expect(v.canClaim50, isTrue);
      expect(v.canClaim100, isTrue);
      final claimed = buildView(
        progress: 100,
        target: 100,
        m50: true,
        m100: true,
      );
      expect(claimed.canClaim50, isFalse);
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
