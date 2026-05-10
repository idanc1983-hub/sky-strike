import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/streak_clock.dart';

void main() {
  group('StreakClock', () {
    test('null lastClaim → claimable on first launch', () {
      final result = StreakClock.evaluate(
        now: DateTime(2026, 5, 8, 10, 0, 0),
        lastClaim: null,
      );
      expect(result, StreakAdvanceResult.claimable);
    });

    test('same calendar day → already claimed', () {
      final result = StreakClock.evaluate(
        now: DateTime(2026, 5, 8, 23, 59, 59),
        lastClaim: DateTime(2026, 5, 8, 0, 0, 1),
      );
      expect(result, StreakAdvanceResult.alreadyClaimedToday);
    });

    test('exactly one calendar day later → claimable', () {
      final result = StreakClock.evaluate(
        now: DateTime(2026, 5, 9, 0, 0, 1),
        lastClaim: DateTime(2026, 5, 8, 23, 59, 59),
      );
      expect(result, StreakAdvanceResult.claimable);
    });

    test('two or more days later → broken and reset', () {
      final result = StreakClock.evaluate(
        now: DateTime(2026, 5, 10, 12, 0, 0),
        lastClaim: DateTime(2026, 5, 8, 23, 0, 0),
      );
      expect(result, StreakAdvanceResult.brokenAndReset);
    });

    test('day boundary is local midnight', () {
      // 23:59:59 on day 1, 00:00:01 on day 2 → claimable.
      final lastClaim = DateTime(2026, 5, 8, 23, 59, 59);
      final justAfterMidnight = DateTime(2026, 5, 9, 0, 0, 1);
      expect(
        StreakClock.evaluate(now: justAfterMidnight, lastClaim: lastClaim),
        StreakAdvanceResult.claimable,
      );
    });

    test('loyalty multiplier ramps and caps at 0.50', () {
      expect(StreakClock.loyaltyMultiplier(0), 0);
      expect(StreakClock.loyaltyMultiplier(1), closeTo(0.10, 1e-9));
      expect(StreakClock.loyaltyMultiplier(3), closeTo(0.30, 1e-9));
      expect(StreakClock.loyaltyMultiplier(5), closeTo(0.50, 1e-9));
      expect(StreakClock.loyaltyMultiplier(10), 0.50); // capped
    });

    test('baseLadderReward returns the locked daily values', () {
      expect(StreakClock.baseLadderReward(1).coins, 100);
      expect(StreakClock.baseLadderReward(1).gems, 1);
      expect(StreakClock.baseLadderReward(2).coins, 200);
      expect(StreakClock.baseLadderReward(2).gems, 0);
      expect(StreakClock.baseLadderReward(3).gems, 2);
      expect(StreakClock.baseLadderReward(4).coins, 400);
      expect(StreakClock.baseLadderReward(5).gems, 3);
      expect(StreakClock.baseLadderReward(6).coins, 600);
      // Day 7 returns empty — caller uses Day7ChestFormula.
      expect(StreakClock.baseLadderReward(7).isEmpty, isTrue);
    });
  });
}
