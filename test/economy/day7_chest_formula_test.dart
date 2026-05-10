import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/day7_chest_formula.dart';

void main() {
  group('Day7ChestFormula', () {
    test('values at locked benchmark levels (GDD §5.3)', () {
      // Use a fixed seed so the random power-up picks don't vary.
      final r = Random(42);

      final lv1 = Day7ChestFormula.compute(
          playerLevel: 1, maxWorldReached: 1, rng: r);
      expect(lv1.coins, 540); // 500 × (1 + 0.08)
      expect(lv1.gems, 20); // 20 + floor(1 × 0.5) = 20

      final lv14 = Day7ChestFormula.compute(
          playerLevel: 14, maxWorldReached: 1, rng: r);
      expect(lv14.coins, 1060); // 500 × (1 + 14 × 0.08) = 500 × 2.12
      expect(lv14.gems, 27); // 20 + floor(14 × 0.5) = 27

      final lv30 = Day7ChestFormula.compute(
          playerLevel: 30, maxWorldReached: 1, rng: r);
      expect(lv30.coins, 1700); // 500 × 3.4
      expect(lv30.gems, 35); // 20 + 15

      final lv50 = Day7ChestFormula.compute(
          playerLevel: 50, maxWorldReached: 1, rng: r);
      expect(lv50.coins, 2500);
      expect(lv50.gems, 45);
    });

    test('gem cap at 75 for very high levels', () {
      final r = Random(7);
      final lv200 = Day7ChestFormula.compute(
          playerLevel: 200, maxWorldReached: 6, rng: r);
      expect(lv200.gems, 75);
    });

    test('always grants exactly 2 power-ups', () {
      final r = Random(1);
      final reward = Day7ChestFormula.compute(
          playerLevel: 14, maxWorldReached: 3, rng: r);
      expect(reward.powerUps.length, 2);
    });
  });
}
