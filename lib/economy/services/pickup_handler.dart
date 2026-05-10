import '../constants/economy_constants.dart';
import '../state/loadout.dart';

/// Discriminator for the four pickup-overflow outcomes from GDD §2.7.1.
enum PickupResult {
  /// Tray had space — pickup landed in the first empty slot.
  addedToTray,

  /// Same-type pickup already in tray — stack incremented silently.
  stacked,

  /// Tray full, queue had space — pickup queued for between-wave popup.
  queued,

  /// Tray full and queue at max — oldest queued entry dropped, new
  /// pickup takes its place.
  droppedOldestAndQueued,
}

/// Outcome of one pickup. Carries the result tag plus a snapshot of any
/// affected slot/queue indices so the UI can show feedback.
class PickupOutcome {
  final PickupResult result;
  final int? slotIndex;
  final List<String> queueAfter;

  const PickupOutcome({
    required this.result,
    required this.queueAfter,
    this.slotIndex,
  });
}

/// Pure-function gameplay-loop handler for a single in-mission power-up
/// pickup. Mutates the [Loadout]'s tray and the [pickupQueue] in place
/// according to GDD §2.7.1. No side effects beyond those mutations.
class PickupHandler {
  PickupHandler._();

  /// Apply [powerUpId] against the active [loadout] and the session's
  /// [pickupQueue]. The number of *owned* tray slots is given by
  /// [unlockedLoadoutSlots] (3..5). Returns the [PickupOutcome] so the
  /// UI can render the appropriate feedback.
  static PickupOutcome process({
    required String powerUpId,
    required Loadout loadout,
    required int unlockedLoadoutSlots,
    required List<String> pickupQueue,
  }) {
    // Case 1: Tray has empty owned slots — fill the first empty slot.
    final emptyIdx = loadout.firstEmptySlotIndex(unlockedLoadoutSlots);
    if (emptyIdx >= 0) {
      loadout.setSlot(emptyIdx, powerUpId);
      return PickupOutcome(
        result: PickupResult.addedToTray,
        slotIndex: emptyIdx,
        queueAfter: List<String>.unmodifiable(pickupQueue),
      );
    }

    // Case 2: Same-type already in tray — stack increments are tracked by
    // [EconomyState.powerUpInventory], so we just signal the UI. This
    // path takes priority over queue-eviction so a player camping on a
    // single biome never drops a queued pickup just because the new
    // pickup also happens to be in their tray.
    if (loadout.trayContains(powerUpId, unlockedLoadoutSlots)) {
      return PickupOutcome(
        result: PickupResult.stacked,
        queueAfter: List<String>.unmodifiable(pickupQueue),
      );
    }

    // Case 3: Queue has space — enqueue. Defensive cap: enforce the
    // max strictly even if a caller mutated the queue out-of-band so
    // the post-process queue can never exceed the documented limit.
    if (pickupQueue.length < EconomyConstants.maxPickupQueue) {
      pickupQueue.add(powerUpId);
      return PickupOutcome(
        result: PickupResult.queued,
        queueAfter: List<String>.unmodifiable(pickupQueue),
      );
    }

    // Case 4: Queue full — drop oldest, append new.
    pickupQueue.removeAt(0);
    pickupQueue.add(powerUpId);
    while (pickupQueue.length > EconomyConstants.maxPickupQueue) {
      pickupQueue.removeAt(0);
    }
    return PickupOutcome(
      result: PickupResult.droppedOldestAndQueued,
      queueAfter: List<String>.unmodifiable(pickupQueue),
    );
  }
}
