import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skystrike/economy/services/economy_api.dart';
import 'package:skystrike/economy/services/economy_persistence.dart';
import 'package:skystrike/economy/services/mock_ads_service.dart';
import 'package:skystrike/economy/services/mock_iap_service.dart';
import 'package:skystrike/economy/state/challenge_state.dart';
import 'package:skystrike/economy/state/economy_state.dart';

EconomyState _buildState({DateTime Function()? now, Random? rng}) {
  return EconomyState(
    persistence: EconomyPersistence(),
    api: EconomyApi(),
    iap: MockIapService(latency: Duration.zero),
    ads: MockAdsService(latency: Duration.zero),
    rng: rng ?? Random(0),
    now: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EconomyState', () {
    test('initial state matches default snapshot', () async {
      final s = _buildState();
      await s.initialize();
      expect(s.coins, 0);
      expect(s.gems, 0);
      expect(s.level, 1);
      expect(s.unlockedLoadoutSlots, 3);
      expect(s.unlockedPowerUps,
          containsAll(<String>{'rapid_fire', 'speed_boost'}));
      s.dispose();
    });

    test('addCoins / spendCoins enforces non-negative balance', () async {
      final s = _buildState();
      await s.initialize();
      s.addCoins(100);
      expect(s.coins, 100);
      expect(s.spendCoins(40), isTrue);
      expect(s.coins, 60);
      expect(s.spendCoins(200), isFalse);
      expect(s.coins, 60);
      s.dispose();
    });

    test('XP cascades a level-up', () async {
      final s = _buildState();
      await s.initialize();
      // xpMax starts at 1000.
      s.addXP(2000);
      expect(s.level, 2);
      // After level 2, xpMax = 1100; remaining 1000 XP → still on level 2.
      expect(s.xp, lessThan(s.xpMax));
      s.dispose();
    });

    test('advanceToWorld returns newly unlocked power-ups', () async {
      final s = _buildState();
      await s.initialize();
      // World 2 (desert) unlocks shield + split_shot per v2 catalog.
      final unlocked = s.advanceToWorld(2);
      expect(unlocked, containsAll(<String>{'shield', 'split_shot'}));
      expect(s.maxWorldReached, 2);
      // Calling again with the same world is a no-op.
      expect(s.advanceToWorld(2), isEmpty);
      s.dispose();
    });

    test('canBuySlot4WithGems requires 25 gems and W5 reach', () async {
      final s = _buildState();
      await s.initialize();
      expect(s.canBuySlot4WithGems(), isFalse);
      s.advanceToWorld(5);
      s.addGems(30);
      expect(s.canBuySlot4WithGems(), isTrue);
      s.dispose();
    });

    test('claimDailyReward grants Day 1 reward and advances streak',
        () async {
      var clock = DateTime.utc(2026, 5, 8, 10);
      final s = _buildState(now: () => clock);
      await s.initialize();
      final reward = s.claimDailyReward();
      expect(reward.coins, greaterThan(0));
      expect(s.streakDay, 2);
      // Same day → already claimed.
      final secondTry = s.claimDailyReward();
      expect(secondTry.isEmpty, isTrue);
      // Next day → claimable again.
      clock = DateTime.utc(2026, 5, 9, 9);
      final next = s.claimDailyReward();
      expect(next.isEmpty, isFalse);
      expect(s.streakDay, 3);
      s.dispose();
    });

    test('IAP success grants gems and records the pack', () async {
      final s = _buildState();
      await s.initialize();
      final outcome = await s.purchaseIap('starter_pack');
      expect(outcome.result.toString(), contains('success'));
      expect(s.gems, 12);
      expect(s.packsPurchased.contains('starter_pack'), isTrue);
      s.dispose();
    });

    test('Salvage on death is 40% of accumulated coins', () async {
      final s = _buildState();
      await s.initialize();
      s.beginStage(1);
      // Simulate clearing waves 1 and 2 in W1 → 20 + 22 = 42 coins.
      s.onWaveCleared(1);
      s.onWaveCleared(2);
      final salvage = s.salvageOnDeath();
      expect(salvage.coins, 16); // floor(42 × 0.40)
      s.commitDeathAndEndStage();
      expect(s.coins, 16);
      s.dispose();
    });

    test('Stage 1 first-clear marks completion + flips home balance flag',
        () async {
      final s = _buildState();
      await s.initialize();
      expect(s.showHomeBalance, isFalse);
      s.beginStage(1);
      final outcome = s.onStageCleared(stars: 1, isBossDefeat: false);
      // Stage 1 forces 3★ regardless of input → reward includes star bonus.
      expect(outcome.reward.coins, greaterThan(0));
      expect(s.showHomeBalance, isTrue);
      s.dispose();
    });

    test('v2: crossing the level-4 gate starts the newPlayers cycle',
        () async {
      final s = _buildState();
      await s.initialize();
      expect(s.challengeRevealed, isFalse);

      // Cross the level-4 gate (xpMax default = 1000, so award 4*1000
      // XP to land on level 5 — past the gate). markChallengeRevealed
      // fires inside addXP.
      s.addXP(EconomyState.challengeUnlockLevel * 1000);
      expect(s.challengeRevealed, isTrue);

      // First-ever cycle is the newPlayers intro per v2.
      expect(s.activeChallengeType, ChallengeType.newPlayers);
      expect(s.challengeTarget, greaterThan(0));
      s.dispose();
    });

    test('challenge progress increments on enemy kills', () async {
      final s = _buildState();
      await s.initialize();
      s.markChallengeRevealed(); // starts the newPlayers intro cycle.
      expect(s.activeChallengeType, ChallengeType.newPlayers);
      final initialProgress = s.challengeProgress;
      s.onEnemyKilled();
      s.onEnemyKilled();
      s.onEnemyKilled();
      expect(s.challengeProgress, initialProgress + 3);
      s.dispose();
    });

    test('claim100 fails before threshold, succeeds at completion', () async {
      final s = _buildState();
      await s.initialize();
      s.markChallengeRevealed();
      // Below 100% → empty reward.
      final tooEarly = s.claimChallengeMilestone100();
      expect(tooEarly.isEmpty, isTrue);
      // Push progress to 100% of target.
      while (s.challengeProgress < s.challengeTarget) {
        s.onEnemyKilled();
      }
      final reward = s.claimChallengeMilestone100();
      expect(s.challenge100Claimed, isTrue);
      // A second claim is rejected (idempotent).
      final repeat = s.claimChallengeMilestone100();
      expect(repeat.isEmpty, isTrue);
      // Reward arrived in wallet.
      expect(s.coins, greaterThan(0));
      // ignore: unnecessary_statements
      reward;
      s.dispose();
    });

  });
}
