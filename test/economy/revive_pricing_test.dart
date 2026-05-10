import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/revive_pricing.dart';

void main() {
  group('RevivePricing', () {
    test('gem cost by wave bucket matches GDD §2.4', () {
      expect(RevivePricing.gemsForWave(1), 5);
      expect(RevivePricing.gemsForWave(2), 5);
      expect(RevivePricing.gemsForWave(3), 5);
      expect(RevivePricing.gemsForWave(4), 10);
      expect(RevivePricing.gemsForWave(5), 10);
      expect(RevivePricing.gemsForWave(6), 10);
      expect(RevivePricing.gemsForWave(7), 15);
      expect(RevivePricing.gemsForWave(8), 15);
      expect(RevivePricing.gemsForWave(9), 15);
      expect(RevivePricing.gemsForWave(10), 20);
    });

    test('canTakeAdRevive caps at 3 per stage', () {
      expect(RevivePricing.canTakeAdRevive(0), isTrue);
      expect(RevivePricing.canTakeAdRevive(1), isTrue);
      expect(RevivePricing.canTakeAdRevive(2), isTrue);
      expect(RevivePricing.canTakeAdRevive(3), isFalse);
      expect(RevivePricing.canTakeAdRevive(99), isFalse);
    });
  });
}
