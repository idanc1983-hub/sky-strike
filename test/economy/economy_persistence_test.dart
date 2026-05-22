import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skystrike/economy/services/economy_persistence.dart';
import 'package:skystrike/economy/state/challenge_state.dart';
import 'package:skystrike/economy/state/loadout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EconomyPersistence', () {
    test('round-trip preserves all fields', () async {
      final p = EconomyPersistence();
      final original = EconomySnapshot(
        coins: 4200,
        gems: 80,
        xp: 620,
        xpMax: 1000,
        level: 14,
        currentWorld: 1,
        maxWorldReached: 3,
        powerUpInventory: const {'bomb': 5, 'magnet': 2},
        unlockedLoadoutSlots: 4,
        loadouts: [
          Loadout(name: 'Speed Run', jetId: 'phantom', trayPowerUps: const [
            'rapid_fire',
            'speed_boost',
            null,
            null,
            null,
          ]),
          Loadout.defaultFor(1),
          Loadout.defaultFor(2),
          Loadout.defaultFor(3),
          Loadout.defaultFor(4),
        ],
        activeLoadoutIndex: 0,
        streakDay: 4,
        streakWeeksCompleted: 2,
        longestStreak: 18,
        lastClaimDate: DateTime.utc(2026, 5, 7, 12, 30),
        dailyAdWatchCount: 2,
        dailyAdWatchDate: DateTime.utc(2026, 5, 8, 8),
        completedStages: const {'w1_s1', 'w1_s2'},
        threeStarStages: const {'w1_s1'},
        defeatedBosses: const {'w1'},
        adsRemoved: true,
        packsPurchased: const {'starter_pack'},
        installDate: DateTime.utc(2026, 5, 1),
        pendingNextJetDiscountPct: 25,
        activeChallengeType: ChallengeType.hunter,
        challengeStartedAt: DateTime.utc(2026, 5, 7, 12, 0),
        challengeProgress: 64,
        challengeTarget: 156,
        challenge100Claimed: false,
        challengeRevealed: true,
        aceDialogueEnabled: false,
        firedFtueTriggers: const {
          'stage1_completed',
          'milestone_level_10',
        },
        shownAceLines: const {
          'ftue_pre_mission_1',
          'ftue_stage_1_clear',
        },
      );
      await p.save(original);
      final restored = await p.load();
      expect(restored.coins, original.coins);
      expect(restored.gems, original.gems);
      expect(restored.xp, original.xp);
      expect(restored.xpMax, original.xpMax);
      expect(restored.level, original.level);
      expect(restored.maxWorldReached, original.maxWorldReached);
      expect(restored.powerUpInventory, original.powerUpInventory);
      expect(restored.unlockedLoadoutSlots, original.unlockedLoadoutSlots);
      expect(restored.loadouts.length, original.loadouts.length);
      expect(restored.loadouts.first.name, 'Speed Run');
      expect(restored.loadouts.first.jetId, 'phantom');
      expect(restored.loadouts.first.trayPowerUps[0], 'rapid_fire');
      expect(restored.streakDay, 4);
      expect(restored.streakWeeksCompleted, 2);
      expect(restored.longestStreak, 18);
      expect(restored.lastClaimDate, original.lastClaimDate);
      expect(restored.completedStages, original.completedStages);
      expect(restored.threeStarStages, original.threeStarStages);
      expect(restored.defeatedBosses, original.defeatedBosses);
      expect(restored.adsRemoved, isTrue);
      expect(restored.packsPurchased, original.packsPurchased);
      expect(restored.installDate, original.installDate);
      expect(restored.activeChallengeType, ChallengeType.hunter);
      expect(restored.challengeStartedAt, original.challengeStartedAt);
      expect(restored.challengeProgress, 64);
      expect(restored.challengeTarget, 156);
      expect(restored.challenge100Claimed, isFalse);
      expect(restored.challengeRevealed, isTrue);
      expect(restored.aceDialogueEnabled, isFalse);
      expect(restored.firedFtueTriggers, original.firedFtueTriggers);
      expect(restored.shownAceLines, original.shownAceLines);
    });

    test('empty SharedPreferences returns defaults', () async {
      final p = EconomyPersistence();
      final snap = await p.load();
      expect(snap.coins, 0);
      expect(snap.gems, 0);
      expect(snap.level, 1);
      expect(snap.maxWorldReached, 1);
      expect(snap.unlockedLoadoutSlots, 3);
      expect(snap.adsRemoved, isFalse);
      expect(snap.challengeRevealed, isFalse);
      expect(snap.activeChallengeType, isNull);
      expect(snap.aceDialogueEnabled, isTrue);
      expect(snap.firedFtueTriggers, isEmpty);
      expect(snap.shownAceLines, isEmpty);
    });
  });
}
