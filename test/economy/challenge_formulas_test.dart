import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/challenge_formulas.dart';
import 'package:skystrike/economy/state/challenge_state.dart';

void main() {
  group('ChallengeFormulas.targetFor', () {
    test('Hunter targets match GDD §4.2 examples', () {
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.hunter,
          playerLevel: 1,
        ),
        104,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.hunter,
          playerLevel: 14,
        ),
        156,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.hunter,
          playerLevel: 30,
        ),
        220,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.hunter,
          playerLevel: 50,
        ),
        300,
      );
    });

    test('Survivor targets match GDD examples', () {
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.survivor,
          playerLevel: 1,
        ),
        3,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.survivor,
          playerLevel: 14,
        ),
        4,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.survivor,
          playerLevel: 30,
        ),
        6,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.survivor,
          playerLevel: 50,
        ),
        8,
      );
    });

    test('Treasure Hunter targets match GDD examples', () {
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.treasure,
          playerLevel: 1,
        ),
        2700,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.treasure,
          playerLevel: 14,
        ),
        5300,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.treasure,
          playerLevel: 30,
        ),
        8500,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.treasure,
          playerLevel: 50,
        ),
        12500,
      );
    });

    test('Conqueror targets match GDD examples', () {
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.conqueror,
          playerLevel: 1,
        ),
        8,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.conqueror,
          playerLevel: 14,
        ),
        10,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.conqueror,
          playerLevel: 30,
        ),
        14,
      );
      expect(
        ChallengeFormulas.targetFor(
          type: ChallengeType.conqueror,
          playerLevel: 50,
        ),
        18,
      );
    });
  });

  group('ChallengeFormulas.gemRange (post-rebalance, -25%)', () {
    test('50% milestone tiers match GDD §4.3', () {
      expect(ChallengeFormulas.gemRange50ForLevel(1), (4, 11));
      expect(ChallengeFormulas.gemRange50ForLevel(10), (4, 11));
      expect(ChallengeFormulas.gemRange50ForLevel(11), (6, 14));
      expect(ChallengeFormulas.gemRange50ForLevel(25), (6, 14));
      expect(ChallengeFormulas.gemRange50ForLevel(26), (9, 17));
      expect(ChallengeFormulas.gemRange50ForLevel(50), (9, 17));
      expect(ChallengeFormulas.gemRange50ForLevel(51), (13, 22));
      expect(ChallengeFormulas.gemRange50ForLevel(200), (13, 22));
    });

    test('100% milestone tiers match GDD §4.3', () {
      expect(ChallengeFormulas.gemRange100ForLevel(1), (8, 15));
      expect(ChallengeFormulas.gemRange100ForLevel(10), (8, 15));
      expect(ChallengeFormulas.gemRange100ForLevel(11), (11, 22));
      expect(ChallengeFormulas.gemRange100ForLevel(25), (11, 22));
      expect(ChallengeFormulas.gemRange100ForLevel(26), (18, 30));
      expect(ChallengeFormulas.gemRange100ForLevel(50), (18, 30));
      expect(ChallengeFormulas.gemRange100ForLevel(51), (26, 37));
      expect(ChallengeFormulas.gemRange100ForLevel(200), (26, 37));
    });
  });

  group('ChallengeFormulas.reward50', () {
    test('coin formula at locked benchmark levels', () {
      // 300 × (1 + level × 0.05)
      final r = Random(0);
      final lv1 = ChallengeFormulas.reward50(
        playerLevel: 1,
        maxWorldReached: 1,
        rng: r,
      );
      expect(lv1.coins, 315);

      final lv14 = ChallengeFormulas.reward50(
        playerLevel: 14,
        maxWorldReached: 1,
        rng: r,
      );
      expect(lv14.coins, 510);

      final lv30 = ChallengeFormulas.reward50(
        playerLevel: 30,
        maxWorldReached: 1,
        rng: r,
      );
      expect(lv30.coins, 750);

      final lv50 = ChallengeFormulas.reward50(
        playerLevel: 50,
        maxWorldReached: 1,
        rng: r,
      );
      expect(lv50.coins, 1050);
    });

    test('grants exactly 1 power-up', () {
      final reward = ChallengeFormulas.reward50(
        playerLevel: 14,
        maxWorldReached: 3,
        rng: Random(42),
      );
      expect(reward.powerUps.length, 1);
    });

    test('gem reward stays within tier range', () {
      for (var seed = 0; seed < 30; seed++) {
        final reward = ChallengeFormulas.reward50(
          playerLevel: 14,
          maxWorldReached: 3,
          rng: Random(seed),
        );
        expect(reward.gems, greaterThanOrEqualTo(6));
        expect(reward.gems, lessThanOrEqualTo(14));
      }
    });
  });

  group('ChallengeFormulas.reward100', () {
    test('coin band falls within 0.8..1.2 jitter window', () {
      // For Lv 14: base = 800 × 1.7 = 1360; jitter window = 1088..1632.
      for (var seed = 0; seed < 20; seed++) {
        final reward = ChallengeFormulas.reward100(
          playerLevel: 14,
          maxWorldReached: 3,
          rng: Random(seed),
        );
        expect(reward.coins, greaterThanOrEqualTo(1088));
        expect(reward.coins, lessThanOrEqualTo(1632));
      }
    });

    test('grants exactly 1 power-up', () {
      final reward = ChallengeFormulas.reward100(
        playerLevel: 14,
        maxWorldReached: 3,
        rng: Random(0),
      );
      expect(reward.powerUps.length, 1);
    });
  });
}
