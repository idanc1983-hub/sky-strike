import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/pickup_handler.dart';
import 'package:skystrike/economy/state/loadout.dart';

void main() {
  group('PickupHandler', () {
    test('Case 1: tray has empty slot → addedToTray', () {
      final loadout = Loadout(name: 'L', jetId: 'jet_player');
      final queue = <String>[];
      final outcome = PickupHandler.process(
        powerUpId: 'bomb',
        loadout: loadout,
        unlockedLoadoutSlots: 3,
        pickupQueue: queue,
      );
      expect(outcome.result, PickupResult.addedToTray);
      expect(loadout.trayPowerUps[0], 'bomb');
      expect(queue, isEmpty);
    });

    test('Case 2: tray full but contains same type → stacked', () {
      final loadout = Loadout(name: 'L', jetId: 'jet_player');
      loadout.setSlot(0, 'bomb');
      loadout.setSlot(1, 'magnet');
      loadout.setSlot(2, 'shield');
      final queue = <String>[];
      final outcome = PickupHandler.process(
        powerUpId: 'bomb',
        loadout: loadout,
        unlockedLoadoutSlots: 3,
        pickupQueue: queue,
      );
      expect(outcome.result, PickupResult.stacked);
      expect(queue, isEmpty);
    });

    test('Case 3: tray full + new type + queue space → queued', () {
      final loadout = Loadout(name: 'L', jetId: 'jet_player');
      loadout.setSlot(0, 'bomb');
      loadout.setSlot(1, 'magnet');
      loadout.setSlot(2, 'shield');
      final queue = <String>[];
      final outcome = PickupHandler.process(
        powerUpId: 'laser',
        loadout: loadout,
        unlockedLoadoutSlots: 3,
        pickupQueue: queue,
      );
      expect(outcome.result, PickupResult.queued);
      expect(queue, ['laser']);
    });

    test('Case 4: queue full → drop oldest, append new', () {
      final loadout = Loadout(name: 'L', jetId: 'jet_player');
      loadout.setSlot(0, 'bomb');
      loadout.setSlot(1, 'magnet');
      loadout.setSlot(2, 'shield');
      final queue = <String>['laser', 'ghost_mode'];
      final outcome = PickupHandler.process(
        powerUpId: 'freeze_time',
        loadout: loadout,
        unlockedLoadoutSlots: 3,
        pickupQueue: queue,
      );
      expect(outcome.result, PickupResult.droppedOldestAndQueued);
      expect(queue, ['ghost_mode', 'freeze_time']);
    });

    test('Owned-slot count restricts addedToTray', () {
      final loadout = Loadout(name: 'L', jetId: 'jet_player');
      // Player owns only 3 slots; cells 3 and 4 must not be filled even
      // though the underlying list has 5 cells.
      final queue = <String>[];
      final outcome = PickupHandler.process(
        powerUpId: 'bomb',
        loadout: loadout,
        unlockedLoadoutSlots: 3,
        pickupQueue: queue,
      );
      expect(outcome.result, PickupResult.addedToTray);
      expect(outcome.slotIndex, 0);
      expect(loadout.trayPowerUps[3], isNull);
      expect(loadout.trayPowerUps[4], isNull);
    });
  });
}
