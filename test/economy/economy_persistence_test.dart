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
          Loadout(name: 'Speed Run', jetId: 'phantom'),
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
        ownedJets: const {'jet_player', 'wraith_x'},
        installDate: DateTime.utc(2026, 5, 1),
        pendingNextJetDiscountPct: 25,
        activeChallengeType: ChallengeType.hunter,
        challengeStartedAt: DateTime.utc(2026, 5, 7, 12, 0),
        challengeProgress: 64,
        challengeTarget: 156,
        challenge100Claimed: false,
        challengeRevealed: true,
        firedFtueTriggers: const {
          'stage1_completed',
          'milestone_level_10',
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
      expect(restored.streakDay, 4);
      expect(restored.streakWeeksCompleted, 2);
      expect(restored.longestStreak, 18);
      expect(restored.lastClaimDate, original.lastClaimDate);
      expect(restored.completedStages, original.completedStages);
      expect(restored.threeStarStages, original.threeStarStages);
      expect(restored.defeatedBosses, original.defeatedBosses);
      expect(restored.adsRemoved, isTrue);
      expect(restored.packsPurchased, original.packsPurchased);
      expect(restored.ownedJets, original.ownedJets);
      expect(restored.installDate, original.installDate);
      expect(restored.activeChallengeType, ChallengeType.hunter);
      expect(restored.challengeStartedAt, original.challengeStartedAt);
      expect(restored.challengeProgress, 64);
      expect(restored.challengeTarget, 156);
      expect(restored.challenge100Claimed, isFalse);
      expect(restored.challengeRevealed, isTrue);
      expect(restored.firedFtueTriggers, original.firedFtueTriggers);
    });

    test('empty SharedPreferences returns defaults', () async {
      final p = EconomyPersistence();
      final snap = await p.load();
      // Brand-new player starter grant per Game Economy GDD v1.1 §3.
      expect(snap.coins, 100);
      expect(snap.gems, 10);
      expect(snap.level, 1);
      expect(snap.maxWorldReached, 1);
      expect(snap.unlockedLoadoutSlots, 3);
      expect(snap.adsRemoved, isFalse);
      expect(snap.challengeRevealed, isFalse);
      expect(snap.activeChallengeType, isNull);
      expect(snap.firedFtueTriggers, isEmpty);
      expect(snap.ownedJets, {'jet_player'});
    });

    test('tampered blob falls back to defaults', () async {
      final p = EconomyPersistence();
      // Seed legitimate data via a real save so the signature pair is
      // written alongside the blob.
      final saved = EconomySnapshot(
        coins: 1000,
        gems: 50,
        xp: 0,
        xpMax: 1000,
        level: 5,
        currentWorld: 1,
        maxWorldReached: 2,
        powerUpInventory: const {},
        unlockedLoadoutSlots: 3,
        loadouts: List.generate(5, Loadout.defaultFor),
        activeLoadoutIndex: 0,
        streakDay: 1,
        streakWeeksCompleted: 0,
        longestStreak: 0,
        lastClaimDate: null,
        dailyAdWatchCount: 0,
        dailyAdWatchDate: null,
        completedStages: const {},
        threeStarStages: const {},
        defeatedBosses: const {},
        adsRemoved: false,
        packsPurchased: const {},
        ownedJets: const {'jet_player'},
        installDate: DateTime.utc(2026, 5, 1),
        pendingNextJetDiscountPct: 0,
        activeChallengeType: null,
        challengeStartedAt: null,
        challengeProgress: 0,
        challengeTarget: 0,
        challenge100Claimed: false,
        challengeRevealed: false,
        firedFtueTriggers: const {},
      );
      await p.save(saved);

      // Now overwrite the blob value directly (simulating a hand-edit
      // via `adb shell` / a backup-extract tool). The signature still
      // matches the original blob, not the new one.
      final prefs = await SharedPreferences.getInstance();
      final original = prefs.getString('ss_state_v1')!;
      final tampered = original.replaceFirst('"coins":1000', '"coins":99999999');
      expect(tampered, isNot(original));
      await prefs.setString('ss_state_v1', tampered);

      final reloaded = await p.load();
      // Defaults (GDD v1.1 §3) — not 99,999,999 coins.
      expect(reloaded.coins, equals(100));
      expect(reloaded.gems, equals(10));
      expect(reloaded.level, equals(1));
    });

    test('missing signature key falls back to defaults', () async {
      final p = EconomyPersistence();
      await p.save(EconomySnapshot.defaults().rebuiltWithCoins(500));

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ss_state_v1_sig');

      final reloaded = await p.load();
      // A blob without its signature is discarded → defaults (GDD v1.1 §3).
      expect(reloaded.coins, equals(100));
    });
  });
}

extension on EconomySnapshot {
  EconomySnapshot rebuiltWithCoins(int newCoins) => EconomySnapshot(
        coins: newCoins,
        gems: gems,
        xp: xp,
        xpMax: xpMax,
        level: level,
        currentWorld: currentWorld,
        maxWorldReached: maxWorldReached,
        powerUpInventory: powerUpInventory,
        unlockedLoadoutSlots: unlockedLoadoutSlots,
        loadouts: loadouts,
        activeLoadoutIndex: activeLoadoutIndex,
        streakDay: streakDay,
        streakWeeksCompleted: streakWeeksCompleted,
        longestStreak: longestStreak,
        lastClaimDate: lastClaimDate,
        dailyAdWatchCount: dailyAdWatchCount,
        dailyAdWatchDate: dailyAdWatchDate,
        completedStages: completedStages,
        threeStarStages: threeStarStages,
        defeatedBosses: defeatedBosses,
        adsRemoved: adsRemoved,
        packsPurchased: packsPurchased,
        ownedJets: ownedJets,
        installDate: installDate,
        pendingNextJetDiscountPct: pendingNextJetDiscountPct,
        activeChallengeType: activeChallengeType,
        challengeStartedAt: challengeStartedAt,
        challengeProgress: challengeProgress,
        challengeTarget: challengeTarget,
        challenge100Claimed: challenge100Claimed,
        challengeRevealed: challengeRevealed,
        firedFtueTriggers: firedFtueTriggers,
      );
}
