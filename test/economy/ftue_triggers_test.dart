import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/ftue_triggers.dart';

void main() {
  group('FtueRules', () {
    test('home balance hidden until Stage 1 completed trigger fires', () {
      expect(FtueRules.shouldShowHomeBalance(<String>{}), isFalse);
      expect(
        FtueRules.shouldShowHomeBalance({FtueTriggers.stage1Completed}),
        isTrue,
      );
    });

    test('forced HP drop fires only on Stage 1 Wave 2 the first time', () {
      // Pre-fire: Stage 1 W2 → fires.
      expect(
        FtueRules.shouldForceHpDrop(
          currentWorld: 1,
          currentStage: 1,
          currentWave: 2,
          firedTriggers: const <String>{},
        ),
        isTrue,
      );
      // After firing: same context → does not fire again.
      expect(
        FtueRules.shouldForceHpDrop(
          currentWorld: 1,
          currentStage: 1,
          currentWave: 2,
          firedTriggers: const {FtueTriggers.stage1Wave2HpForced},
        ),
        isFalse,
      );
      // Wrong wave: never fires.
      expect(
        FtueRules.shouldForceHpDrop(
          currentWorld: 1,
          currentStage: 1,
          currentWave: 1,
          firedTriggers: const <String>{},
        ),
        isFalse,
      );
      // Wrong stage: never fires.
      expect(
        FtueRules.shouldForceHpDrop(
          currentWorld: 1,
          currentStage: 2,
          currentWave: 2,
          firedTriggers: const <String>{},
        ),
        isFalse,
      );
    });

    test('free auto-revive applies once during Stage 1', () {
      expect(
        FtueRules.shouldFreeReviveOnDeath(
          currentWorld: 1,
          currentStage: 1,
          firedTriggers: const <String>{},
        ),
        isTrue,
      );
      expect(
        FtueRules.shouldFreeReviveOnDeath(
          currentWorld: 1,
          currentStage: 1,
          firedTriggers: const {FtueTriggers.stage1FreeReviveUsed},
        ),
        isFalse,
      );
      expect(
        FtueRules.shouldFreeReviveOnDeath(
          currentWorld: 2,
          currentStage: 1,
          firedTriggers: const <String>{},
        ),
        isFalse,
      );
    });

    test('Stage 1 always force-clamps to 3★', () {
      expect(
        FtueRules.shouldForceThreeStar(currentWorld: 1, currentStage: 1),
        isTrue,
      );
      expect(
        FtueRules.shouldForceThreeStar(currentWorld: 1, currentStage: 2),
        isFalse,
      );
      expect(
        FtueRules.shouldForceThreeStar(currentWorld: 2, currentStage: 1),
        isFalse,
      );
    });

    test('milestoneTriggerForLevel routes to highest applicable trigger', () {
      expect(FtueRules.milestoneTriggerForLevel(9), isNull);
      expect(
        FtueRules.milestoneTriggerForLevel(10),
        FtueTriggers.milestoneLevel10,
      );
      expect(
        FtueRules.milestoneTriggerForLevel(24),
        FtueTriggers.milestoneLevel10,
      );
      expect(
        FtueRules.milestoneTriggerForLevel(25),
        FtueTriggers.milestoneLevel25,
      );
      expect(
        FtueRules.milestoneTriggerForLevel(49),
        FtueTriggers.milestoneLevel25,
      );
      expect(
        FtueRules.milestoneTriggerForLevel(50),
        FtueTriggers.milestoneLevel50,
      );
      expect(
        FtueRules.milestoneTriggerForLevel(100),
        FtueTriggers.milestoneLevel50,
      );
    });
  });
}
