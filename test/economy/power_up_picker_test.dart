import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/constants/power_up_catalog.dart';
import 'package:skystrike/economy/services/power_up_picker.dart';

void main() {
  group('PowerUpPicker', () {
    test('W1 player only draws from W1 pool', () {
      final r = Random(7);
      final w1Pool = PowerUpCatalog.unlocksByWorld[1]!.toSet();
      for (var i = 0; i < 200; i++) {
        final pick = PowerUpPicker.pick(maxWorldReached: 1, rng: r);
        expect(w1Pool.contains(pick), isTrue,
            reason: 'pick $pick should be from W1');
      }
    });

    test('W2 player draws roughly 50/50 from W2 and W1', () {
      final r = Random(9);
      final w1Pool = PowerUpCatalog.unlocksByWorld[1]!.toSet();
      final w2Pool = PowerUpCatalog.unlocksByWorld[2]!.toSet();
      var w2Hits = 0;
      var w1Hits = 0;
      const samples = 4000;
      for (var i = 0; i < samples; i++) {
        final pick = PowerUpPicker.pick(maxWorldReached: 2, rng: r);
        if (w2Pool.contains(pick)) w2Hits++;
        if (w1Pool.contains(pick)) w1Hits++;
      }
      // Expect each pool ~50%. Allow ±5% variance for sample size 4000.
      expect(w2Hits / samples, closeTo(0.5, 0.05));
      expect(w1Hits / samples, closeTo(0.5, 0.05));
    });

    test('W6 player matches 50/30/20 distribution', () {
      final r = Random(11);
      final recent = PowerUpCatalog.unlocksByWorld[6]!.toSet();
      final previous = PowerUpCatalog.unlocksByWorld[5]!.toSet();
      var recentHits = 0;
      var previousHits = 0;
      var earlierHits = 0;
      const samples = 6000;
      for (var i = 0; i < samples; i++) {
        final pick = PowerUpPicker.pick(maxWorldReached: 6, rng: r);
        if (recent.contains(pick)) {
          recentHits++;
        } else if (previous.contains(pick)) {
          previousHits++;
        } else {
          earlierHits++;
        }
      }
      // Allow ±4% variance with 6000 samples.
      expect(recentHits / samples, closeTo(0.50, 0.04));
      expect(previousHits / samples, closeTo(0.30, 0.04));
      expect(earlierHits / samples, closeTo(0.20, 0.04));
    });

    test('pickMany returns the requested count', () {
      final r = Random(0);
      final picks = PowerUpPicker.pickMany(
          count: 5, maxWorldReached: 3, rng: r);
      expect(picks.length, 5);
    });
  });
}
