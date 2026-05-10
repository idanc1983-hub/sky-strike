/// Stable string IDs for the one-time FTUE moments tracked by
/// `EconomyState.firedFtueTriggers`. Use these instead of magic strings
/// when calling `markFtueTriggerFired`.
class FtueTriggers {
  FtueTriggers._();

  // ---------------------------------------------------------------------------
  // Stage 1 forced behaviors — GDD §10
  // ---------------------------------------------------------------------------

  /// Fires the first time an HP pack drops in Stage 1 Wave 2 (forced
  /// drop bypassing normal RNG, exactly once).
  static const stage1Wave2HpForced = 'stage1_wave2_hp_forced';

  /// Marks Stage 1 as completed. Used to flip the home-screen coin
  /// balance from hidden → visible.
  static const stage1Completed = 'stage1_completed';

  /// Fires when the player's first death is auto-revived (free, no popup).
  static const stage1FreeReviveUsed = 'stage1_free_revive_used';

  // ---------------------------------------------------------------------------
  // Master skip + dialogue gating — GDD §10.3
  // ---------------------------------------------------------------------------

  /// Fired on the FIRST time the player taps the X on an Ace bubble.
  /// Drives the one-time "Skip Ace's lines?" confirmation modal.
  static const aceMasterSkipPrompted = 'ace_master_skip_prompted';

  // ---------------------------------------------------------------------------
  // Long-term milestones — fire-once gates
  // ---------------------------------------------------------------------------

  /// Player reached level 10 for the first time.
  static const milestoneLevel10 = 'milestone_level_10';

  /// Player reached level 25 for the first time.
  static const milestoneLevel25 = 'milestone_level_25';

  /// Player reached level 50 for the first time.
  static const milestoneLevel50 = 'milestone_level_50';

  /// Player completed their first Day 7 streak claim.
  static const milestoneDay7 = 'milestone_day7';

  /// Player bought their first jet from the shop.
  static const milestoneFirstJet = 'milestone_first_jet';
}

/// Pure-function decision rules for the FTUE forced behaviors. The
/// `shouldX` family read state without mutating; the `consumeX` family
/// atomically check-and-mark in a single call so a caller cannot fire
/// the same one-shot twice across an `await` boundary.
class FtueRules {
  FtueRules._();

  /// Whether the home-screen coin balance should be visible. Per GDD
  /// §10.4, the coin chip is hidden during the Stage 1 pre-mission
  /// popup and remains hidden until Stage 1 first clear.
  static bool shouldShowHomeBalance(Set<String> firedTriggers) {
    return firedTriggers.contains(FtueTriggers.stage1Completed);
  }

  /// Whether the next HP-pack RNG roll should be forced to drop. Per
  /// GDD §10.4, in Stage 1 Wave 2 the first HP pack is guaranteed.
  static bool shouldForceHpDrop({
    required int currentWorld,
    required int currentStage,
    required int currentWave,
    required Set<String> firedTriggers,
  }) {
    if (firedTriggers.contains(FtueTriggers.stage1Wave2HpForced)) {
      return false; // already used the one-time forced drop
    }
    return currentWorld == 1 && currentStage == 1 && currentWave == 2;
  }

  /// Atomic check-and-mark for the Stage 1 Wave 2 forced HP drop.
  /// Returns true the first time the predicate matches; subsequent
  /// calls always return false (the [firedTriggers] set is mutated in
  /// place). Use this at the call site instead of the predicate +
  /// post-hoc `markFtueTriggerFired` pair so a re-entry within the
  /// same frame can't fire twice.
  static bool consumeForceHpDrop({
    required int currentWorld,
    required int currentStage,
    required int currentWave,
    required Set<String> firedTriggers,
  }) {
    if (!shouldForceHpDrop(
      currentWorld: currentWorld,
      currentStage: currentStage,
      currentWave: currentWave,
      firedTriggers: firedTriggers,
    )) {
      return false;
    }
    return firedTriggers.add(FtueTriggers.stage1Wave2HpForced);
  }

  /// Whether to apply the free auto-revive on player death (Stage 1
  /// only, exactly once).
  static bool shouldFreeReviveOnDeath({
    required int currentWorld,
    required int currentStage,
    required Set<String> firedTriggers,
  }) {
    if (firedTriggers.contains(FtueTriggers.stage1FreeReviveUsed)) {
      return false;
    }
    return currentWorld == 1 && currentStage == 1;
  }

  /// Atomic check-and-mark for the free Stage 1 revive. Returns true
  /// the first time it fires.
  static bool consumeFreeReviveOnDeath({
    required int currentWorld,
    required int currentStage,
    required Set<String> firedTriggers,
  }) {
    if (!shouldFreeReviveOnDeath(
      currentWorld: currentWorld,
      currentStage: currentStage,
      firedTriggers: firedTriggers,
    )) {
      return false;
    }
    return firedTriggers.add(FtueTriggers.stage1FreeReviveUsed);
  }

  /// Whether to clamp Stage 1's awarded star count to 3★. GDD §10.4
  /// says Stage 1 always awards 3★ on completion.
  static bool shouldForceThreeStar({
    required int currentWorld,
    required int currentStage,
  }) {
    return currentWorld == 1 && currentStage == 1;
  }

  /// Returns the Ace milestone-line key that should fire when the
  /// player's level transitions across one of the locked milestones,
  /// or `null` if no line should fire for [newLevel].
  ///
  /// Note: this only returns the *highest* milestone reached. Callers
  /// fanning out across a multi-level XP grant should iterate the
  /// thresholds themselves so 9 → 50 fires 10/25/50 in turn.
  static String? milestoneTriggerForLevel(int newLevel) {
    if (newLevel >= 50) return FtueTriggers.milestoneLevel50;
    if (newLevel >= 25) return FtueTriggers.milestoneLevel25;
    if (newLevel >= 10) return FtueTriggers.milestoneLevel10;
    return null;
  }

  /// All milestone trigger ids whose thresholds were crossed by a
  /// transition `from` → `to`. Returned in ascending threshold order.
  static List<String> milestonesCrossed(int from, int to) {
    if (to <= from) return const <String>[];
    final out = <String>[];
    if (from < 10 && to >= 10) out.add(FtueTriggers.milestoneLevel10);
    if (from < 25 && to >= 25) out.add(FtueTriggers.milestoneLevel25);
    if (from < 50 && to >= 50) out.add(FtueTriggers.milestoneLevel50);
    return out;
  }
}
