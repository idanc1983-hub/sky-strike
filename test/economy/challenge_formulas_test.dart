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
    // v2: 50% mid-cycle milestone removed; only the 100% tier remains.
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
