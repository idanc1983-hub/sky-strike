import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/pack_pricing.dart';

void main() {
  group('PackPricing', () {
    test('Bomb pack pricing matches GDD §2.6 example table', () {
      expect(PackPricing.totalPrice(powerUpId: 'bomb', packSize: 1), 80);
      expect(PackPricing.totalPrice(powerUpId: 'bomb', packSize: 3), 216);
      expect(PackPricing.totalPrice(powerUpId: 'bomb', packSize: 5), 320);
      expect(PackPricing.totalPrice(powerUpId: 'bomb', packSize: 10), 560);
    });

    test('Drone pack pricing matches GDD §2.6 example table', () {
      expect(PackPricing.totalPrice(powerUpId: 'drone_wingman', packSize: 1), 250);
      expect(PackPricing.totalPrice(powerUpId: 'drone_wingman', packSize: 3), 675);
      expect(PackPricing.totalPrice(powerUpId: 'drone_wingman', packSize: 5), 1000);
      expect(PackPricing.totalPrice(powerUpId: 'drone_wingman', packSize: 10), 1750);
    });

    test('Unknown power-up throws ArgumentError (no silent free pack)', () {
      expect(
        () => PackPricing.totalPrice(powerUpId: 'nonexistent', packSize: 1),
        throwsArgumentError,
      );
      expect(
        PackPricing.totalPriceOrNull(
          powerUpId: 'nonexistent',
          packSize: 1,
        ),
        isNull,
      );
    });

    test('Non-positive pack size throws', () {
      expect(
        () => PackPricing.totalPrice(powerUpId: 'bomb', packSize: 0),
        throwsArgumentError,
      );
      expect(
        () => PackPricing.totalPrice(powerUpId: 'bomb', packSize: -1),
        throwsArgumentError,
      );
    });

    test('Unsupported pack size falls back to size-1 (no discount)', () {
      // Pack size 7 isn't in PACK_DISCOUNTS — should treat as 0% discount.
      expect(
        PackPricing.totalPrice(powerUpId: 'bomb', packSize: 7),
        80 * 7,
      );
    });
  });
}
