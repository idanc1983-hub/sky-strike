import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../constants/ace_dialogue_catalog.dart';
import '../constants/ad_placement_catalog.dart';
import '../constants/economy_constants.dart';
import '../constants/iap_catalog.dart';
import '../constants/power_up_catalog.dart';
import '../services/ads_service.dart';
import '../services/challenge_formulas.dart';
import '../services/challenge_lifecycle.dart';
import '../services/coin_reward_calculator.dart';
import '../services/day7_chest_formula.dart';
import '../services/economy_api.dart';
import '../services/economy_persistence.dart';
import '../services/ftue_triggers.dart';
import '../services/iap_service.dart';
import '../services/pack_pricing.dart';
import '../services/pickup_handler.dart';
import '../services/power_up_picker.dart';
import '../services/revive_pricing.dart';
import '../services/streak_clock.dart';
import 'challenge_state.dart';
import 'loadout.dart';
import 'reward.dart';

/// Result of an in-mission pickup processed by [EconomyState.onPowerUpPickup].
class PowerUpPickupReport {
  final PickupResult result;
  final int? slotIndex;
  final List<String> queueAfter;
  const PowerUpPickupReport({
    required this.result,
    required this.queueAfter,
    this.slotIndex,
  });
}

/// Outcome of a stage-clear event. Carries the granted [Reward] plus
/// flags the host UI uses to drive cinematics (Stage 3 challenge reveal,
/// power-up unlock celebration on world advance).
class StageClearOutcome {
  final Reward reward;
  final bool shouldShowChallengeReveal;
  final List<String> newlyUnlockedPowerUps;
  const StageClearOutcome({
    required this.reward,
    required this.shouldShowChallengeReveal,
    required this.newlyUnlockedPowerUps,
  });
}

/// Single source of truth for the entire economy. Wires together the
/// pure-function calculators, persistence, and the IAP/Ads boundaries.
///
/// **Threading note**: every public mutator calls [notifyListeners] and
/// stages a debounced backend sync via [EconomyApi]. Reads are
/// synchronous; writes never block on I/O (persistence is fire-and-
/// forget; debounced sync is fire-and-forget).
class EconomyState extends ChangeNotifier {
  final EconomyPersistence _persistence;
  final EconomyApi _api;
  final IapService _iap;
  final AdsService _ads;
  final Random _rng;
  final DateTime Function() _now;

  // ---------------------------------------------------------------------------
  // Currency & progression
  // ---------------------------------------------------------------------------
  int _coins = 0;
  int _gems = 0;
  int _xp = 0;
  int _xpMax = 1000;
  int _level = 1;
  int _currentWorld = 1;
  int _maxWorldReached = 1;

  // ---------------------------------------------------------------------------
  // Power-ups & loadouts
  // ---------------------------------------------------------------------------
  final Map<String, int> _powerUpInventory = <String, int>{};
  int _unlockedLoadoutSlots = EconomyConstants.defaultUnlockedLoadoutSlots;
  late List<Loadout> _loadouts;
  int _activeLoadoutIndex = 0;

  // ---------------------------------------------------------------------------
  // Daily streak
  // ---------------------------------------------------------------------------
  int _streakDay = 1;
  int _streakWeeksCompleted = 0;
  int _longestStreak = 0;
  DateTime? _lastClaimDate;
  int _dailyAdWatchCount = 0;
  DateTime? _dailyAdWatchDate;

  // ---------------------------------------------------------------------------
  // Challenge System — GDD v1.3 §4. Replaces the old single-chest
  // operation. `null` activeChallengeType means the challenge slot is
  // hidden (player has not yet cleared Stage 3).
  // ---------------------------------------------------------------------------
  ChallengeType? _activeChallengeType;
  DateTime? _challengeStartedAt;
  int _challengeProgress = 0;
  int _challengeTarget = 0;
  bool _challenge50ClaimedThisCycle = false;
  bool _challenge100ClaimedThisCycle = false;
  bool _challengeRevealed = false;

  // ---------------------------------------------------------------------------
  // Stage / session
  // ---------------------------------------------------------------------------
  int _accumulatedRunCoins = 0;
  int _stageRevivesUsed = 0;
  int _currentStage = 1;
  bool _playerDiedThisStage = false;
  final Set<String> _completedStages = <String>{};
  final Set<String> _threeStarStages = <String>{};
  final Set<String> _defeatedBosses = <String>{};
  final List<String> _pickupQueue = <String>[];

  // ---------------------------------------------------------------------------
  // Monetization
  // ---------------------------------------------------------------------------
  bool _adsRemoved = false;
  final Set<String> _packsPurchased = <String>{};
  DateTime? _installDate;
  int _pendingNextJetDiscountPct = 0;

  // ---------------------------------------------------------------------------
  // Ace NPC + FTUE — GDD v1.3 §10
  // ---------------------------------------------------------------------------
  bool _aceDialogueEnabled = true;
  final Set<String> _firedFtueTriggers = <String>{};
  final Set<String> _shownAceLines = <String>{};

  /// Pending Ace dialogue line key — UI listens for this and shows the
  /// corresponding overlay. The UI clears it via [consumePendingAceLine]
  /// after presentation.
  String? _pendingAceLine;

  /// Pending challenge milestone for which the UI should surface a
  /// celebratory toast on next app open. One of `'50'` / `'100'` / null.
  String? _pendingMilestoneToast;

  bool _initialized = false;

  // Reentrancy guards — protect synchronous double-fire (e.g. UI button
  // tapped twice in one frame before rebuild disables it).
  bool _claimingDaily = false;
  bool _claiming50 = false;
  bool _claiming100 = false;

  // Cap to prevent xpMax overflow as level grows. 2^30 fits comfortably
  // in a 64-bit int and exceeds any realistic player XP curve.
  static const int _xpMaxCap = 1 << 30;

  EconomyState({
    required EconomyPersistence persistence,
    required EconomyApi api,
    required IapService iap,
    required AdsService ads,
    Random? rng,
    DateTime Function()? now,
  })  : _persistence = persistence,
        _api = api,
        _iap = iap,
        _ads = ads,
        _rng = rng ?? Random(),
        _now = now ?? DateTime.now {
    _loadouts = List<Loadout>.generate(
      EconomyConstants.maxLoadoutSlots,
      Loadout.defaultFor,
    );
    _api.registerFlushHandler(_flushToBackend);
  }

  // ---------------------------------------------------------------------------
  // Public read surface
  // ---------------------------------------------------------------------------
  int get coins => _coins;
  int get gems => _gems;
  int get xp => _xp;
  int get xpMax => _xpMax;
  int get level => _level;
  int get currentWorld => _currentWorld;
  int get maxWorldReached => _maxWorldReached;
  int get unlockedLoadoutSlots => _unlockedLoadoutSlots;
  /// Read-only snapshot of all loadouts. The returned list and the inner
  /// objects are defensive copies — mutating them does not feed back into
  /// state. Use [renameLoadout]/[resolveQueuedPickupToSlot] etc. to make
  /// changes that should persist.
  List<Loadout> get loadouts => List<Loadout>.unmodifiable(
        _loadouts.map((l) => l.clone()).toList(growable: false),
      );
  int get activeLoadoutIndex => _activeLoadoutIndex;
  Loadout get activeLoadout => _loadouts[_activeLoadoutIndex];
  Map<String, int> get powerUpInventory =>
      Map<String, int>.unmodifiable(_powerUpInventory);
  int get streakDay => _streakDay;
  int get streakWeeksCompleted => _streakWeeksCompleted;
  int get longestStreak => _longestStreak;
  DateTime? get lastClaimDate => _lastClaimDate;
  int get dailyAdWatchCount => _dailyAdWatchCount;
  // Challenge / operation surface (replaces v1.2's static operation fields)
  bool get challengeRevealed => _challengeRevealed;
  ChallengeType? get activeChallengeType => _activeChallengeType;
  int get challengeProgress => _challengeProgress;
  int get challengeTarget => _challengeTarget;
  DateTime? get challengeStartedAt => _challengeStartedAt;
  bool get challenge50Claimed => _challenge50ClaimedThisCycle;
  bool get challenge100Claimed => _challenge100ClaimedThisCycle;
  String? get pendingMilestoneToast => _pendingMilestoneToast;

  /// Read-only computed view of the current challenge, or `null` if no
  /// challenge is active yet (player hasn't cleared Stage 3).
  ChallengeView? get challengeView {
    final type = _activeChallengeType;
    final start = _challengeStartedAt;
    if (type == null || start == null) return null;
    return ChallengeView(
      type: type,
      startedAt: start,
      progress: _challengeProgress,
      target: _challengeTarget,
      milestone50Claimed: _challenge50ClaimedThisCycle,
      milestone100Claimed: _challenge100ClaimedThisCycle,
    );
  }

  /// Backwards-compat shim — older HomeScreen code that referenced the
  /// v1.2 operation fields can keep reading these. They proxy to the
  /// active challenge.
  String get operationName =>
      _activeChallengeType?.displayName ?? 'No active operation';
  int get killCount => _challengeProgress;
  int get targetCount => _challengeTarget == 0 ? 1 : _challengeTarget;
  DateTime get operationEndsAt {
    // Anchor to a stable timestamp so successive UI rebuilds don't see
    // the end-time creep forward each frame. Pre-reveal we anchor to
    // installDate (or epoch) — the home screen treats the operation
    // slot as hidden in that state anyway.
    final start = _challengeStartedAt ??
        _installDate ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return start.add(const Duration(hours: 72));
  }

  int get currentStage => _currentStage;
  int get stageRevivesUsed => _stageRevivesUsed;
  int get accumulatedRunCoins => _accumulatedRunCoins;
  List<String> get pickupQueue => List<String>.unmodifiable(_pickupQueue);
  bool get adsRemoved => _adsRemoved;
  Set<String> get packsPurchased => Set<String>.unmodifiable(_packsPurchased);
  int get pendingNextJetDiscountPct => _pendingNextJetDiscountPct;

  // Ace + FTUE surface
  bool get aceDialogueEnabled => _aceDialogueEnabled;
  Set<String> get firedFtueTriggers =>
      Set<String>.unmodifiable(_firedFtueTriggers);
  Set<String> get shownAceLines =>
      Set<String>.unmodifiable(_shownAceLines);
  String? get pendingAceLine => _pendingAceLine;

  /// Whether the home-screen coin balance chip should be visible.
  /// Returns true once Stage 1 has been completed (per FTUE rules).
  bool get showHomeBalance =>
      FtueRules.shouldShowHomeBalance(_firedFtueTriggers);

  /// Derived: every power-up unlocked through the player's max biome.
  Set<String> get unlockedPowerUps {
    final out = <String>{};
    for (var w = 1; w <= _maxWorldReached; w++) {
      out.addAll(PowerUpCatalog.unlocksByWorld[w] ?? const <String>[]);
    }
    return out;
  }

  /// Whether the Starter Pack should still display the "BEST FIRST DEAL"
  /// banner — within the 7-day install window AND not yet purchased.
  bool get showStarterBestDeal {
    if (_packsPurchased.contains('starter_pack')) return false;
    final installed = _installDate;
    if (installed == null) return true;
    return _now().difference(installed) < IapCatalog.starterBestDealWindow;
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Loads the persisted snapshot and applies it. Idempotent — calling
  /// twice is a no-op. Call once at app startup, before the UI mounts.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final snap = await _persistence.load();
    _coins = snap.coins;
    _gems = snap.gems;
    _xp = snap.xp;
    _xpMax = snap.xpMax;
    _level = snap.level;
    _currentWorld = snap.currentWorld;
    _maxWorldReached = snap.maxWorldReached;
    _powerUpInventory
      ..clear()
      ..addAll(snap.powerUpInventory);
    // Persistence layer already clamps unlockedLoadoutSlots into the
    // valid range, but be defensive — a min of `defaultUnlockedLoadoutSlots`
    // ensures `clamp(0, _unlockedLoadoutSlots - 1)` is always valid.
    _unlockedLoadoutSlots = snap.unlockedLoadoutSlots
        .clamp(EconomyConstants.defaultUnlockedLoadoutSlots,
            EconomyConstants.maxLoadoutSlots);
    if (snap.loadouts.isNotEmpty) {
      _loadouts = snap.loadouts;
      while (_loadouts.length < EconomyConstants.maxLoadoutSlots) {
        _loadouts.add(Loadout.defaultFor(_loadouts.length));
      }
    }
    _activeLoadoutIndex =
        snap.activeLoadoutIndex.clamp(0, _unlockedLoadoutSlots - 1);
    _pendingNextJetDiscountPct = snap.pendingNextJetDiscountPct;
    _streakDay = snap.streakDay;
    _streakWeeksCompleted = snap.streakWeeksCompleted;
    _longestStreak = snap.longestStreak;
    _lastClaimDate = snap.lastClaimDate;
    _dailyAdWatchCount = snap.dailyAdWatchCount;
    _dailyAdWatchDate = snap.dailyAdWatchDate;
    _completedStages
      ..clear()
      ..addAll(snap.completedStages);
    _threeStarStages
      ..clear()
      ..addAll(snap.threeStarStages);
    _defeatedBosses
      ..clear()
      ..addAll(snap.defeatedBosses);
    _adsRemoved = snap.adsRemoved;
    _packsPurchased
      ..clear()
      ..addAll(snap.packsPurchased);
    _installDate = snap.installDate ?? _now();

    // Challenge / FTUE / Ace fields (added in v1.3)
    _activeChallengeType = snap.activeChallengeType;
    _challengeStartedAt = snap.challengeStartedAt;
    _challengeProgress = snap.challengeProgress;
    _challengeTarget = snap.challengeTarget;
    _challenge50ClaimedThisCycle = snap.challenge50Claimed;
    _challenge100ClaimedThisCycle = snap.challenge100Claimed;
    _challengeRevealed = snap.challengeRevealed;
    _aceDialogueEnabled = snap.aceDialogueEnabled;
    _firedFtueTriggers
      ..clear()
      ..addAll(snap.firedFtueTriggers);
    _shownAceLines
      ..clear()
      ..addAll(snap.shownAceLines);

    if (snap.installDate == null) {
      // First launch — mark install timestamp so the BEST FIRST DEAL
      // window has a starting point.
      await _persist();
    }
    _resetDailyAdWatchIfNewDay();
    _checkChallengeCycleExpiry();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Challenge System (GDD v1.3 §4)
  // ---------------------------------------------------------------------------

  /// Starts a brand-new challenge cycle. The first-ever cycle is locked
  /// to Hunter; subsequent cycles advance through the rotation.
  ///
  /// Caller is responsible for ensuring the challenge has been revealed
  /// (i.e. Stage 3 cleared at least once).
  void startNewChallengeCycle() {
    final isFirstEver = _activeChallengeType == null;
    final type = pickCycleType(
      isFirstEverCycle: isFirstEver,
      previousType: _activeChallengeType,
    );
    _activeChallengeType = type;
    _challengeStartedAt = _now();
    _challengeProgress = 0;
    _challengeTarget =
        ChallengeFormulas.targetFor(type: type, playerLevel: _level);
    _challenge50ClaimedThisCycle = false;
    _challenge100ClaimedThisCycle = false;
    _scheduleSync();
    notifyListeners();
  }

  /// Marks the challenge as revealed (Stage 3 first clear) and starts
  /// the very first cycle. No-op if [_challengeRevealed] is already true.
  void markChallengeRevealed() {
    if (_challengeRevealed) return;
    _challengeRevealed = true;
    startNewChallengeCycle();
  }

  /// Auto-claims any unclaimed milestones reached during an expired
  /// cycle, then starts the next cycle. Called from
  /// [_checkChallengeCycleExpiry] on app foreground.
  void _autoClaimAndAdvanceIfExpired() {
    final view = challengeView;
    if (view == null) return;
    if (!view.isExpired(_now())) return;

    var milestoneFired = false;
    if (view.canClaim50) {
      _applyReward(ChallengeFormulas.reward50(
        playerLevel: _level,
        maxWorldReached: _maxWorldReached,
        rng: _rng,
      ));
      _challenge50ClaimedThisCycle = true;
      milestoneFired = true;
    }
    if (view.canClaim100) {
      _applyReward(ChallengeFormulas.reward100(
        playerLevel: _level,
        maxWorldReached: _maxWorldReached,
        rng: _rng,
      ));
      _challenge100ClaimedThisCycle = true;
      milestoneFired = true;
    }
    if (milestoneFired) {
      _pendingMilestoneToast = view.canClaim100 ? '100' : '50';
    }
    startNewChallengeCycle();
  }

  void _checkChallengeCycleExpiry() {
    if (!_challengeRevealed || _challengeStartedAt == null) return;
    final view = challengeView;
    if (view != null && view.isExpired(_now())) {
      _autoClaimAndAdvanceIfExpired();
    }
  }

  /// Should be called from the host (typically on app foreground) so
  /// expired cycles auto-claim and a fresh cycle starts.
  void onAppForeground() {
    _checkChallengeCycleExpiry();
    _resetDailyAdWatchIfNewDay();
    notifyListeners();
  }

  /// Manual claim of the 50% milestone reward. Returns the reward, or
  /// [Reward.empty] if the milestone is not currently claimable.
  Reward claimChallengeMilestone50() {
    if (_claiming50) return Reward.empty;
    final view = challengeView;
    if (view == null || !view.canClaim50) return Reward.empty;
    _claiming50 = true;
    // Set the gate flag BEFORE granting so a synchronous re-entry sees
    // the claim already in flight.
    _challenge50ClaimedThisCycle = true;
    try {
      final reward = ChallengeFormulas.reward50(
        playerLevel: _level,
        maxWorldReached: _maxWorldReached,
        rng: _rng,
      );
      _applyReward(reward);
      _scheduleSync();
      notifyListeners();
      return reward;
    } finally {
      _claiming50 = false;
    }
  }

  /// Manual claim of the 100% milestone reward. Returns the reward, or
  /// [Reward.empty] if the milestone is not currently claimable.
  Reward claimChallengeMilestone100() {
    if (_claiming100) return Reward.empty;
    final view = challengeView;
    if (view == null || !view.canClaim100) return Reward.empty;
    _claiming100 = true;
    _challenge100ClaimedThisCycle = true;
    try {
      final reward = ChallengeFormulas.reward100(
        playerLevel: _level,
        maxWorldReached: _maxWorldReached,
        rng: _rng,
      );
      _applyReward(reward);
      _scheduleSync();
      notifyListeners();
      return reward;
    } finally {
      _claiming100 = false;
    }
  }

  /// Consumes the pending milestone toast — UI calls this once it has
  /// shown the toast so it doesn't fire twice.
  void consumePendingMilestoneToast() {
    if (_pendingMilestoneToast == null) return;
    _pendingMilestoneToast = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Challenge progress hooks (called from gameplay)
  // ---------------------------------------------------------------------------

  /// Deprecated alias for [onEnemyKilled]. Kept so older callers compile;
  /// delegating prevents the historical double-count where both methods
  /// incremented Hunter progress on the same kill.
  @Deprecated('Use onEnemyKilled')
  void onEnemyKillForChallenge() => onEnemyKilled();

  /// Survivor + Conqueror trackers — called by [onStageCleared] which
  /// already knows the stars and death state of the run. Survivor
  /// resets to 0 on death; Conqueror increments only on 2★+ clears.
  void _updateChallengeOnStageClear({
    required int stars,
    required bool diedThisStage,
  }) {
    if (_activeChallengeType == ChallengeType.survivor) {
      if (diedThisStage) {
        _challengeProgress = 0;
      } else {
        _challengeProgress += 1;
      }
    } else if (_activeChallengeType == ChallengeType.conqueror) {
      if (stars >= 2) _challengeProgress += 1;
    }
  }

  // ---------------------------------------------------------------------------
  // Currency mutators
  // ---------------------------------------------------------------------------

  /// Adds [amount] coins. [source] is for analytics. No-op for non-positive.
  void addCoins(int amount, {String source = 'unspecified'}) {
    if (amount <= 0) return;
    _coins += amount;
    _scheduleSync();
    notifyListeners();
  }

  /// Adds [amount] gems. [source] is for analytics. No-op for non-positive.
  void addGems(int amount, {String source = 'unspecified'}) {
    if (amount <= 0) return;
    _gems += amount;
    _scheduleSync();
    notifyListeners();
  }

  /// Tries to spend [amount] coins. Returns true on success; balance is
  /// unchanged on failure.
  bool spendCoins(int amount) {
    if (amount <= 0 || _coins < amount) return false;
    _coins -= amount;
    _scheduleSync();
    notifyListeners();
    return true;
  }

  /// Tries to spend [amount] gems. Returns true on success.
  bool spendGems(int amount) {
    if (amount <= 0 || _gems < amount) return false;
    _gems -= amount;
    _scheduleSync();
    notifyListeners();
    return true;
  }

  /// Adds XP and cascades level-ups. Each level raises [xpMax] by 10%
  /// (capped — see [_xpMaxCap]). Players never lose XP (GDD §2.3). Fires
  /// Ace milestone lines on Lv 10 / 25 / 50 transitions even if multiple
  /// milestones are crossed in a single call.
  void addXP(int amount) {
    if (amount <= 0) return;
    final priorLevel = _level;
    _xp += amount;
    while (_xp >= _xpMax) {
      _xp -= _xpMax;
      _level += 1;
      final scaled = (_xpMax * 1.10).floor();
      _xpMax = scaled > _xpMaxCap ? _xpMaxCap : scaled;
    }
    if (_level > priorLevel) {
      _maybeFireLevelMilestonesCrossed(priorLevel, _level);
    }
    notifyListeners();
  }

  /// Fires every milestone trigger crossed by a level transition. A big
  /// XP grant that jumps level 9 → level 50 must fire 10/25/50 in turn,
  /// not just the highest.
  void _maybeFireLevelMilestonesCrossed(int from, int to) {
    const milestones = <int, ({String trigger, String aceLine})>{
      10: (
        trigger: FtueTriggers.milestoneLevel10,
        aceLine: 'ace_level_10',
      ),
      25: (
        trigger: FtueTriggers.milestoneLevel25,
        aceLine: 'ace_level_25',
      ),
      50: (
        trigger: FtueTriggers.milestoneLevel50,
        aceLine: 'ace_level_50',
      ),
    };
    for (final entry in milestones.entries) {
      final ml = entry.key;
      if (ml > from && ml <= to) {
        if (_firedFtueTriggers.add(entry.value.trigger)) {
          requestAceLine(entry.value.aceLine);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Wave / stage flow
  // ---------------------------------------------------------------------------

  /// Begins a new run of [stage] in [_currentWorld]. Resets per-session
  /// counters. The active loadout is what the player took into the stage.
  void beginStage(int stage) {
    _currentStage = stage;
    _accumulatedRunCoins = 0;
    _stageRevivesUsed = 0;
    _playerDiedThisStage = false;
    _pickupQueue.clear();
    notifyListeners();
  }

  /// Records a wave clear. Adds the per-wave coin reward to the run
  /// accumulator (those coins become persistent on stage clear or via
  /// 40% salvage on death).
  int onWaveCleared(int wave1to10) {
    final reward = CoinRewardCalculator.coinsForWave(
      wave1to10: wave1to10,
      world: _currentWorld,
    );
    _accumulatedRunCoins += reward;
    return reward;
  }

  /// Records the player's death. Returns the salvage reward (40% coins,
  /// 0 gems). Caller is responsible for offering revive options before
  /// committing the salvage.
  Reward salvageOnDeath() {
    final coins = CoinRewardCalculator.salvageOnDeath(_accumulatedRunCoins);
    return Reward(coins: coins);
  }

  /// Marks that the player died at least once this stage. Used by the
  /// Survivor challenge tracker (which resets to 0 on death) and by the
  /// FTUE forced-revive logic.
  void recordDeathThisStage() {
    _playerDiedThisStage = true;
    notifyListeners();
  }

  /// Commits the salvage to the player's wallet and ends the stage. Used
  /// when the player declines revive (or runs out of revives).
  void commitDeathAndEndStage() {
    final salvage = salvageOnDeath();
    _coins += salvage.coins;
    _accumulatedRunCoins = 0;
    _stageRevivesUsed = 0;
    _playerDiedThisStage = true;
    _pickupQueue.clear();
    _scheduleSync();
    notifyListeners();
  }

  /// Records a stage clear. Pays out wave coins + stage bonus + star
  /// bonus + first-time gem milestones. Returns a [StageClearOutcome]
  /// containing the reward and any cinematics the host UI should drive
  /// (Stage 3 challenge reveal, world-advance unlock popup).
  StageClearOutcome onStageCleared({
    required int stars,
    required bool isBossDefeat,
  }) {
    // FTUE: Stage 1 always awards 3★ regardless of perf (GDD §10.4).
    final effectiveStars = FtueRules.shouldForceThreeStar(
      currentWorld: _currentWorld,
      currentStage: _currentStage,
    )
        ? 3
        : stars;

    final stageId = 'w${_currentWorld}_s$_currentStage';
    final isFirstClear = !_completedStages.contains(stageId);
    final isFirstThreeStar =
        effectiveStars >= 3 && !_threeStarStages.contains(stageId);
    final isFirstBoss = isBossDefeat &&
        !_defeatedBosses.contains('w$_currentWorld');

    final waveCoins = _accumulatedRunCoins;
    final clearBonus = isFirstClear
        ? CoinRewardCalculator.stageClearBonus(_currentWorld)
        : 0;
    final star = CoinRewardCalculator.starBonus(
      stars: effectiveStars,
      world: _currentWorld,
    );
    final coins = waveCoins + clearBonus + star;

    var gems = 0;
    if (isFirstClear) gems += EconomyConstants.gemFirstStageClear;
    if (isFirstThreeStar) gems += EconomyConstants.gemFirstThreeStarClear;
    if (isFirstBoss) gems += EconomyConstants.gemFirstBossDefeat;

    _coins += coins;
    _gems += gems;

    // Drive Treasure Hunter challenge counter (gameplay coins only).
    if (_activeChallengeType == ChallengeType.treasure && coins > 0) {
      _challengeProgress += coins;
    }

    // Drive Survivor + Conqueror challenge counters.
    _updateChallengeOnStageClear(
      stars: effectiveStars,
      diedThisStage: _playerDiedThisStage,
    );

    if (isFirstClear) _completedStages.add(stageId);
    if (isFirstThreeStar) _threeStarStages.add(stageId);
    if (isFirstBoss) _defeatedBosses.add('w$_currentWorld');

    // FTUE: mark Stage 1 completion → unblocks home-screen coin chip,
    // fires Ace's celebration line + the shop-intro suggestion.
    if (_currentWorld == 1 &&
        _currentStage == 1 &&
        !_firedFtueTriggers.contains(FtueTriggers.stage1Completed)) {
      _firedFtueTriggers.add(FtueTriggers.stage1Completed);
      // "Hell yes! That's how it's done!" — one-shot via shownAceLines.
      requestAceLine(AceLineKeys.ftueStage1Clear);
    }

    // Stage 3 challenge reveal trigger (one-time per account).
    final shouldShowChallengeReveal = _currentWorld == 1 &&
        _currentStage == 3 &&
        !_challengeRevealed;

    // Reset per-stage session state.
    _accumulatedRunCoins = 0;
    _stageRevivesUsed = 0;
    _playerDiedThisStage = false;
    _pickupQueue.clear();

    _scheduleSync();
    notifyListeners();
    return StageClearOutcome(
      reward: Reward(coins: coins, gems: gems),
      shouldShowChallengeReveal: shouldShowChallengeReveal,
      newlyUnlockedPowerUps: const <String>[],
    );
  }

  /// Test/debug-only helper: drives the same code path as a real
  /// gameplay-loop stage clear. Use from the long-press LAUNCH debug
  /// hook to simulate a Stage 3 clear and trigger the reveal cinematic.
  StageClearOutcome debugSimulateStageClear({
    required int world,
    required int stage,
    required int stars,
    required bool isBossDefeat,
    required bool diedDuringRun,
    int simulatedRunCoins = 0,
  }) {
    setCurrentWorld(world);
    _currentStage = stage;
    _accumulatedRunCoins = simulatedRunCoins;
    _playerDiedThisStage = diedDuringRun;
    return onStageCleared(stars: stars, isBossDefeat: isBossDefeat);
  }

  // ---------------------------------------------------------------------------
  // Revive
  // ---------------------------------------------------------------------------

  /// Attempts a paid revive on [wave1to10]. Deducts the gem cost on
  /// success and returns true. The caller continues the run with the run
  /// accumulator preserved.
  bool spendOnRevive(int wave1to10) {
    final cost = RevivePricing.gemsForWave(wave1to10);
    return spendGems(cost);
  }

  /// Whether the player has any ad-revives left in this stage attempt.
  /// Use as the gate before calling [showRewardedAd]; on a `rewardEarned`
  /// outcome, the caller must follow up with [commitAdRevive] to consume
  /// one of the stage-cap slots.
  bool canTakeAdRevive() => RevivePricing.canTakeAdRevive(_stageRevivesUsed);

  /// Authorizes a free ad-revive without consuming a cap slot. Kept for
  /// backwards compatibility — new callers should prefer the
  /// [canTakeAdRevive] / [commitAdRevive] pair so a failed/skipped ad
  /// doesn't burn one of the player's three per-stage revives.
  bool tryAdRevive() => canTakeAdRevive();

  /// Commits one ad-revive against the stage cap. Call this *after* the
  /// ad SDK confirms `rewardEarned` (not on dismiss). Returns true if
  /// the cap allowed the commit; false if it would overflow (caller
  /// should silently absorb).
  bool commitAdRevive() {
    if (!RevivePricing.canTakeAdRevive(_stageRevivesUsed)) return false;
    _stageRevivesUsed += 1;
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Power-up pickups & purchases
  // ---------------------------------------------------------------------------

  /// Routes an in-mission power-up pickup through [PickupHandler]. Also
  /// increments the player's inventory counter — pickups always grant a
  /// copy regardless of where the visual lands.
  PowerUpPickupReport onPowerUpPickup(String powerUpId) {
    _powerUpInventory[powerUpId] =
        (_powerUpInventory[powerUpId] ?? 0) + 1;
    final outcome = PickupHandler.process(
      powerUpId: powerUpId,
      loadout: activeLoadout,
      unlockedLoadoutSlots: _unlockedLoadoutSlots,
      pickupQueue: _pickupQueue,
    );
    _scheduleSync();
    notifyListeners();
    return PowerUpPickupReport(
      result: outcome.result,
      slotIndex: outcome.slotIndex,
      queueAfter: outcome.queueAfter,
    );
  }

  /// Buys [packSize] of [powerUpId] in the shop. Returns true on success.
  bool buyPowerUp(String powerUpId, {int packSize = 1}) {
    final price =
        PackPricing.totalPrice(powerUpId: powerUpId, packSize: packSize);
    if (!spendCoins(price)) return false;
    _powerUpInventory[powerUpId] =
        (_powerUpInventory[powerUpId] ?? 0) + packSize;
    _scheduleSync();
    notifyListeners();
    return true;
  }

  /// Resolves the queued pickup at [queueIndex]: sends it into [slotIndex]
  /// of the active tray. The queued entry is consumed.
  void resolveQueuedPickupToSlot({
    required int queueIndex,
    required int slotIndex,
  }) {
    if (queueIndex < 0 || queueIndex >= _pickupQueue.length) return;
    if (slotIndex < 0 || slotIndex >= _unlockedLoadoutSlots) return;
    final id = _pickupQueue.removeAt(queueIndex);
    activeLoadout.setSlot(slotIndex, id);
    _scheduleSync();
    notifyListeners();
  }

  /// Discards the queued pickup at [queueIndex] without using it. Player
  /// keeps the inventory copy that the pickup already granted.
  void discardQueuedPickup(int queueIndex) {
    if (queueIndex < 0 || queueIndex >= _pickupQueue.length) return;
    _pickupQueue.removeAt(queueIndex);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Loadout slots
  // ---------------------------------------------------------------------------

  /// Whether the player meets the conditions to buy [slot] (4 or 5) with
  /// coins right now. Slots 1-3 are always considered owned.
  bool canBuyLoadoutSlot(int slot) {
    if (slot < 4 || slot > 5) return false;
    if (_unlockedLoadoutSlots >= slot) return false;
    final biomeReq = slot == 4
        ? EconomyConstants.loadoutSlot4BiomeReq
        : EconomyConstants.loadoutSlot5BiomeReq;
    final cost = slot == 4
        ? EconomyConstants.loadoutSlot4CoinCost
        : EconomyConstants.loadoutSlot5CoinCost;
    return _maxWorldReached >= biomeReq && _coins >= cost;
  }

  /// Whether the contextual gem-shortcut to slot 4 is offerable right
  /// now. Only used inside the pickup overflow popup (GDD §2.7.1).
  bool canBuySlot4WithGems() {
    return _maxWorldReached >= EconomyConstants.loadoutSlot4BiomeReq &&
        _unlockedLoadoutSlots == 3 &&
        _gems >= EconomyConstants.loadoutSlot4GemShortcutCost;
  }

  /// Buys loadout slot 4 or 5 with coins. Returns true on success.
  bool buyLoadoutSlot(int slot) {
    if (!canBuyLoadoutSlot(slot)) return false;
    final cost = slot == 4
        ? EconomyConstants.loadoutSlot4CoinCost
        : EconomyConstants.loadoutSlot5CoinCost;
    if (!spendCoins(cost)) return false;
    _unlockedLoadoutSlots = slot;
    _scheduleSync();
    notifyListeners();
    return true;
  }

  /// Buys loadout slot 4 with gems and seats [pickupId] in it directly.
  /// Used by the pickup overflow popup's "BUY SLOT 4" button. The
  /// pickup id must be currently in the queue — this method does NOT
  /// grant an inventory copy on its own; it relies on
  /// [onPowerUpPickup] having already done so when the pickup was
  /// queued. Returns false if the pickup id isn't queued (caller
  /// passed bogus data).
  bool buySlot4WithGemsAndSeat(String pickupId) {
    if (!canBuySlot4WithGems()) return false;
    if (!_pickupQueue.contains(pickupId)) return false;
    if (!spendGems(EconomyConstants.loadoutSlot4GemShortcutCost)) return false;
    _unlockedLoadoutSlots = 4;
    activeLoadout.setSlot(3, pickupId);
    _pickupQueue.remove(pickupId);
    _scheduleSync();
    notifyListeners();
    return true;
  }

  /// Selects [index] as the active loadout. Clamped to owned slots.
  void selectLoadout(int index) {
    final clamped = index.clamp(0, _unlockedLoadoutSlots - 1);
    if (_activeLoadoutIndex == clamped) return;
    _activeLoadoutIndex = clamped;
    notifyListeners();
  }

  /// Renames a loadout. No-op if the index is out of range.
  void renameLoadout(int index, String newName) {
    if (index < 0 || index >= _loadouts.length) return;
    _loadouts[index].name = newName;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Daily streak
  // ---------------------------------------------------------------------------

  /// Returns true if the streak is claimable right now (a new day has
  /// started since the last claim).
  bool get canClaimStreakToday {
    return StreakClock.evaluate(now: _now(), lastClaim: _lastClaimDate) !=
        StreakAdvanceResult.alreadyClaimedToday;
  }

  /// Resets the streak to Day 1 if a day was missed. Called by the host
  /// on app foreground. Returns the post-evaluation result for telemetry.
  StreakAdvanceResult resetStreakIfMissed() {
    final result =
        StreakClock.evaluate(now: _now(), lastClaim: _lastClaimDate);
    if (result == StreakAdvanceResult.brokenAndReset) {
      _streakDay = 1;
      notifyListeners();
    }
    return result;
  }

  /// Claims today's streak reward. Returns the granted [Reward], or
  /// [Reward.empty] if the streak is not currently claimable.
  Reward claimDailyReward() {
    if (_claimingDaily) return Reward.empty;
    final result =
        StreakClock.evaluate(now: _now(), lastClaim: _lastClaimDate);
    if (result == StreakAdvanceResult.alreadyClaimedToday) {
      return Reward.empty;
    }
    _claimingDaily = true;
    // Stamp lastClaimDate up-front so any synchronous re-entry hits
    // `alreadyClaimedToday` and bails. We set the timestamp now and the
    // value we ultimately persist is the same `_now()` call.
    final claimAt = _now();
    _lastClaimDate = claimAt;
    if (result == StreakAdvanceResult.brokenAndReset) {
      _streakDay = 1;
    }

    try {
      Reward reward;
      if (_streakDay == 7) {
        reward = Day7ChestFormula.compute(
          playerLevel: _level,
          maxWorldReached: _maxWorldReached,
          rng: _rng,
        );
      } else {
        var base = StreakClock.baseLadderReward(_streakDay);
        // Layer in random power-ups (counts come from constants).
        final powerUpCount =
            EconomyConstants.streakDailyPowerUps[_streakDay - 1];
        if (powerUpCount > 0) {
          final picks = PowerUpPicker.pickMany(
            count: powerUpCount,
            maxWorldReached: _maxWorldReached,
            rng: _rng,
          );
          base = base.plus(Reward(powerUps: picks));
        }
        // Loyalty bonus stacks on top of the base reward.
        final loyalty = StreakClock.loyaltyMultiplier(_streakWeeksCompleted);
        reward = loyalty > 0 ? base.scaled(1 + loyalty) : base;
      }

      _applyReward(reward);

      // Record longest-streak BEFORE advancing the cycle so we capture
      // the correct day count (a Day-7 claim is 7 days, not 8).
      final claimedDayAbsolute = _streakWeeksCompleted * 7 + _streakDay;
      if (claimedDayAbsolute > _longestStreak) {
        _longestStreak = claimedDayAbsolute;
      }

      // Advance the cycle.
      if (_streakDay >= 7) {
        _streakDay = 1;
        _streakWeeksCompleted += 1;
      } else {
        _streakDay += 1;
      }
      _scheduleSync();
      notifyListeners();
      return reward;
    } finally {
      _claimingDaily = false;
    }
  }

  // ---------------------------------------------------------------------------
  // FTUE window helper
  // ---------------------------------------------------------------------------

  /// Whether the player is currently in their FTUE 24-hour window. Used
  /// by analytics and any event-flag gating.
  bool get isFtueActive {
    final installed = _installDate;
    if (installed == null) return true;
    return _now().difference(installed) < const Duration(hours: 24);
  }

  /// Increments the operation kill counter. Called from the gameplay
  /// loop on every confirmed enemy kill — drives the Hunter challenge
  /// type when active.
  void onEnemyKilled() {
    if (_activeChallengeType == ChallengeType.hunter) {
      _challengeProgress += 1;
    }
    _scheduleSync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Other gem sinks
  // ---------------------------------------------------------------------------
  bool spendOnTrayRefill() => spendGems(EconomyConstants.gemCostTrayRefill);
  bool spendOnOperationSkip(int hours) {
    // Reject non-positive hours — earlier code charged just 1 gem in
    // that branch, which let a malformed call skip the entire 72h
    // cycle for a single gem. Hours over the operation length are
    // clamped to the cycle so a UI bug can't overcharge either.
    if (hours <= 0) return false;
    final clamped = hours.clamp(1, 72);
    return spendGems(
      clamped * EconomyConstants.gemCostOperationSkipPerHour,
    );
  }
  bool spendOnDealReroll() => spendGems(EconomyConstants.gemCostDealReroll);

  // ---------------------------------------------------------------------------
  // World progression / unlock popup
  // ---------------------------------------------------------------------------

  /// Whether [world] is reachable (the player has unlocked it as their
  /// max biome).
  bool isWorldUnlocked(int world) => _maxWorldReached >= world;

  /// Sets the *currently playing* world (does NOT advance unlock state).
  /// Use [advanceToWorld] for the new-biome path.
  void setCurrentWorld(int world) {
    if (world < 1 || world > 6) return;
    if (_currentWorld == world) return;
    _currentWorld = world;
    notifyListeners();
  }

  /// Sets the home-screen "Current Mission" stage label. Used after a
  /// successful stage clear to advance the next-mission marker. Does
  /// NOT reset per-session counters — call [beginStage] when actually
  /// starting a run.
  void setCurrentStage(int stage) {
    if (stage <= 0) return;
    if (_currentStage == stage) return;
    _currentStage = stage;
    _scheduleSync();
    notifyListeners();
  }

  /// Advances [maxWorldReached] up to [newWorld] if greater. Returns the
  /// list of newly unlocked power-up ids — caller drives the unlock popup.
  List<String> advanceToWorld(int newWorld) {
    final clampedTarget = newWorld.clamp(1, 6);
    if (clampedTarget <= _maxWorldReached) return const <String>[];
    final unlocked = <String>[];
    for (var w = _maxWorldReached + 1; w <= clampedTarget; w++) {
      unlocked.addAll(PowerUpCatalog.unlocksByWorld[w] ?? const <String>[]);
    }
    _maxWorldReached = clampedTarget;
    _scheduleSync();
    notifyListeners();
    return unlocked;
  }

  // ---------------------------------------------------------------------------
  // IAP & Ads
  // ---------------------------------------------------------------------------

  /// Issues a purchase request via [IapService]. On success applies the
  /// reward locally and persists the packsPurchased flag.
  Future<IapPurchaseOutcome> purchaseIap(String productId) async {
    final outcome = await _iap.requestPurchase(productId);
    if (outcome.result == IapPurchaseResult.success) {
      _applyIapReward(productId);
    }
    return outcome;
  }

  /// Shows a rewarded ad for [placement] via [AdsService]. On success
  /// applies the placement's reward and updates daily counters.
  Future<AdShowOutcome> showRewardedAd(AdPlacement placement) async {
    if (placement == AdPlacement.extraGemsDaily &&
        _dailyAdWatchCount >= EconomyConstants.dailyAdWatchCap) {
      return AdShowOutcome(
        result: AdShowResult.capReached,
        placement: placement,
      );
    }

    final outcome = await _ads.show(placement);
    if (outcome.result == AdShowResult.rewardEarned) {
      _applyAdReward(placement);
    }
    return outcome;
  }

  void _applyIapReward(String productId) {
    final mainGems = IapCatalog.mainPackGems[productId];
    if (mainGems != null) {
      _gems += mainGems;
      final disc = IapCatalog.mainPackNextJetDiscount[productId];
      if (disc != null) {
        // Take the larger of the existing pending discount and the new
        // one so a player who buys two discount-bearing packs in a row
        // doesn't silently lose the better deal.
        final candidate = (disc * 100).round();
        if (candidate > _pendingNextJetDiscountPct) {
          _pendingNextJetDiscountPct = candidate;
        }
      }
    }
    final coinPack = IapCatalog.coinPackCoins[productId];
    if (coinPack != null) {
      _coins += coinPack;
      _gems += IapCatalog.coinPackGems[productId] ?? 0;
      final picks = PowerUpPicker.pickMany(
        count: IapCatalog.coinPackPowerUps[productId] ?? 0,
        maxWorldReached: _maxWorldReached,
        rng: _rng,
      );
      for (final id in picks) {
        _powerUpInventory[id] = (_powerUpInventory[id] ?? 0) + 1;
      }
    }
    if (productId == IapCatalog.removeAdsProductId) {
      _adsRemoved = true;
      // The mock ads service exposes a setter; real impls don't. The
      // try/catch keeps the swap mechanical.
      try {
        // ignore: avoid_dynamic_calls
        (_ads as dynamic).adsRemoved = true;
      } catch (_) {
        // Real implementations don't take a setter; that's fine.
      }
    }
    _packsPurchased.add(productId);
    _scheduleSync();
    notifyListeners();
  }

  void _applyAdReward(AdPlacement placement) {
    final mult = _adsRemoved ? EconomyConstants.removeAdsRewardMultiplier : 1.0;
    switch (placement) {
      case AdPlacement.reviveMidStage:
        // Revive itself is free — placement reward is the revive event,
        // applied by the caller (which also bumped _stageRevivesUsed).
        break;
      case AdPlacement.doubleBiomeEnd:
        // The 2× is applied by the caller against the biome reward (it
        // hasn't been granted yet at the moment of ad-watch).
        break;
      case AdPlacement.extraGemsDaily:
        _resetDailyAdWatchIfNewDay();
        final gems = AdPlacementCatalog.extraGemsMin +
            _rng.nextInt(AdPlacementCatalog.extraGemsMax -
                AdPlacementCatalog.extraGemsMin +
                1);
        _gems += (gems * mult).floor();
        _dailyAdWatchCount += 1;
        _dailyAdWatchDate = _now();
        break;
      case AdPlacement.chestBoost:
        // The +25% bonus is applied at chest-claim time via the
        // adBoosted flag; nothing to do here besides notifying.
        break;
    }
    _scheduleSync();
    notifyListeners();
  }

  void _resetDailyAdWatchIfNewDay() {
    final last = _dailyAdWatchDate;
    if (last == null) return;
    if (StreakClock.dayDelta(last, _now()) >= 1) {
      _dailyAdWatchCount = 0;
      _dailyAdWatchDate = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence & sync
  // ---------------------------------------------------------------------------

  /// Forces an immediate persist + backend flush. Called on app
  /// background. Returns when both have settled.
  Future<void> persist() async {
    await _persist();
    await _api.flushNow();
  }

  Future<void> _persist() async {
    final snap = EconomySnapshot(
      coins: _coins,
      gems: _gems,
      xp: _xp,
      xpMax: _xpMax,
      level: _level,
      currentWorld: _currentWorld,
      maxWorldReached: _maxWorldReached,
      powerUpInventory: Map<String, int>.from(_powerUpInventory),
      unlockedLoadoutSlots: _unlockedLoadoutSlots,
      loadouts: _loadouts,
      activeLoadoutIndex: _activeLoadoutIndex,
      streakDay: _streakDay,
      streakWeeksCompleted: _streakWeeksCompleted,
      longestStreak: _longestStreak,
      lastClaimDate: _lastClaimDate,
      dailyAdWatchCount: _dailyAdWatchCount,
      dailyAdWatchDate: _dailyAdWatchDate,
      completedStages: Set<String>.from(_completedStages),
      threeStarStages: Set<String>.from(_threeStarStages),
      defeatedBosses: Set<String>.from(_defeatedBosses),
      adsRemoved: _adsRemoved,
      packsPurchased: Set<String>.from(_packsPurchased),
      installDate: _installDate,
      pendingNextJetDiscountPct: _pendingNextJetDiscountPct,
      activeChallengeType: _activeChallengeType,
      challengeStartedAt: _challengeStartedAt,
      challengeProgress: _challengeProgress,
      challengeTarget: _challengeTarget,
      challenge50Claimed: _challenge50ClaimedThisCycle,
      challenge100Claimed: _challenge100ClaimedThisCycle,
      challengeRevealed: _challengeRevealed,
      aceDialogueEnabled: _aceDialogueEnabled,
      firedFtueTriggers: Set<String>.from(_firedFtueTriggers),
      shownAceLines: Set<String>.from(_shownAceLines),
    );
    await _persistence.save(snap);
  }

  void _scheduleSync() {
    // Persistence is fire-and-forget — never await on the UI thread.
    unawaited(_persist());
    _api.enqueue(EconomySyncPayload(
      coins: _coins,
      gems: _gems,
      killCount: _challengeProgress,
      powerUpInventory: Map<String, int>.from(_powerUpInventory),
    ));
  }

  Future<void> _flushToBackend(EconomySyncPayload payload) async {
    // Stub — real backend wires here. Today this is a no-op so the
    // EconomyApi debounce smoke-tests are observable in dev.
  }

  void _applyReward(Reward reward) {
    _coins += reward.coins;
    _gems += reward.gems;
    for (final id in reward.powerUps) {
      _powerUpInventory[id] = (_powerUpInventory[id] ?? 0) + 1;
    }
    if (reward.xp > 0) addXP(reward.xp);
  }

  // ---------------------------------------------------------------------------
  // Ace dialogue + FTUE triggers (GDD v1.3 §10)
  // ---------------------------------------------------------------------------

  /// Toggles whether Ace dialogue overlays should appear at all. Wired
  /// to the Settings switch and to the master-skip confirmation prompt.
  void setAceDialogueEnabled(bool enabled) {
    if (_aceDialogueEnabled == enabled) return;
    _aceDialogueEnabled = enabled;
    _scheduleSync();
    notifyListeners();
  }

  /// Returns true when [key] is an FTUE-track line that should fire only
  /// once. We use the `ftue_` prefix as the convention.
  bool _isOneShotLine(String key) => key.startsWith('ftue_');

  /// Queues an Ace dialogue line for presentation. The host UI listens
  /// to `pendingAceLine`, shows the overlay, and calls
  /// [consumePendingAceLine] when dismissed.
  ///
  /// No-op if dialogue is disabled, the line is already shown
  /// (one-shot rule for `ftue_*` lines), or [_pendingAceLine] is
  /// already set (we never queue two lines).
  void requestAceLine(String key) {
    if (!_aceDialogueEnabled) return;
    if (_pendingAceLine != null) return;
    if (_isOneShotLine(key) && _shownAceLines.contains(key)) return;
    _pendingAceLine = key;
    _shownAceLines.add(key);
    _scheduleSync();
    notifyListeners();
  }

  /// Clears the pending Ace line — called by the overlay widget after
  /// it has been displayed and dismissed.
  void consumePendingAceLine() {
    if (_pendingAceLine == null) return;
    _pendingAceLine = null;
    notifyListeners();
  }

  /// Records that an FTUE one-time trigger has fired. Subsequent calls
  /// for the same trigger are no-ops.
  void markFtueTriggerFired(String triggerId) {
    if (_firedFtueTriggers.add(triggerId)) {
      _scheduleSync();
      notifyListeners();
    }
  }

  /// Whether [triggerId] has already fired this account's lifetime.
  bool isFtueTriggerFired(String triggerId) =>
      _firedFtueTriggers.contains(triggerId);

  // ---------------------------------------------------------------------------
  // Debug-only resets — used by the hidden dev-tools sheet in Settings.
  // Each method below mutates state directly and persists.
  // ---------------------------------------------------------------------------

  /// Clears all FTUE-track flags so Ace's intro lines fire again on the
  /// next pre-mission popup, the coin chip hides until Stage 1 first
  /// clear, and the Stage 3 reveal can replay. Does NOT touch wallets or
  /// progression.
  void debugReplayFtue() {
    _firedFtueTriggers.clear();
    _shownAceLines.clear();
    _challengeRevealed = false;
    _activeChallengeType = null;
    _challengeStartedAt = null;
    _challengeProgress = 0;
    _challengeTarget = 0;
    _challenge50ClaimedThisCycle = false;
    _challenge100ClaimedThisCycle = false;
    _pendingAceLine = null;
    _pendingMilestoneToast = null;
    _aceDialogueEnabled = true;
    _scheduleSync();
    notifyListeners();
  }

  /// Debug-only: simulates a Stage 1 clear so the player gets the
  /// Stage 1 reward + the FTUE "Hell yes!" Ace line + home-screen
  /// coin chip visibility flip without having to play through.
  StageClearOutcome debugSimulateStage1Clear() {
    return debugSimulateStageClear(
      world: 1,
      stage: 1,
      stars: 3,
      isBossDefeat: false,
      diedDuringRun: false,
      simulatedRunCoins: 448,
    );
  }

  /// Debug-only: overwrites the coin balance to an absolute value.
  /// Bypasses [addCoins]/[spendCoins] so QA can jump straight to a
  /// target balance without ladder-walking through deltas.
  void debugSetCoins(int value) {
    final clamped = value < 0 ? 0 : value;
    if (_coins == clamped) return;
    _coins = clamped;
    _scheduleSync();
    notifyListeners();
  }

  /// Debug-only: overwrites the gem balance to an absolute value.
  void debugSetGems(int value) {
    final clamped = value < 0 ? 0 : value;
    if (_gems == clamped) return;
    _gems = clamped;
    _scheduleSync();
    notifyListeners();
  }

  /// Wipes the active challenge cycle only (keeps `challengeRevealed`
  /// true). Long-press LAUNCH still re-fires the reveal because that
  /// path early-returns on `challengeRevealed`, so this resets that flag
  /// too.
  void debugResetChallengeCycle() {
    _challengeRevealed = false;
    _activeChallengeType = null;
    _challengeStartedAt = null;
    _challengeProgress = 0;
    _challengeTarget = 0;
    _challenge50ClaimedThisCycle = false;
    _challenge100ClaimedThisCycle = false;
    _scheduleSync();
    notifyListeners();
  }

  /// Wipes the entire economy back to first-launch defaults (coins,
  /// gems, level, streak, loadouts, FTUE flags, challenge, IAP records,
  /// install date). Equivalent to deleting + reinstalling the app
  /// without actually reinstalling.
  Future<void> debugHardReset() async {
    _coins = 0;
    _gems = 0;
    _xp = 0;
    _xpMax = 1000;
    _level = 1;
    _currentWorld = 1;
    _maxWorldReached = 1;
    _powerUpInventory.clear();
    _unlockedLoadoutSlots = EconomyConstants.defaultUnlockedLoadoutSlots;
    _loadouts = List<Loadout>.generate(
      EconomyConstants.maxLoadoutSlots,
      Loadout.defaultFor,
    );
    _activeLoadoutIndex = 0;
    _streakDay = 1;
    _streakWeeksCompleted = 0;
    _longestStreak = 0;
    _lastClaimDate = null;
    _dailyAdWatchCount = 0;
    _dailyAdWatchDate = null;
    _completedStages.clear();
    _threeStarStages.clear();
    _defeatedBosses.clear();
    _accumulatedRunCoins = 0;
    _stageRevivesUsed = 0;
    _currentStage = 1;
    _playerDiedThisStage = false;
    _pickupQueue.clear();
    _adsRemoved = false;
    _packsPurchased.clear();
    _pendingNextJetDiscountPct = 0;
    _installDate = _now();
    _activeChallengeType = null;
    _challengeStartedAt = null;
    _challengeProgress = 0;
    _challengeTarget = 0;
    _challenge50ClaimedThisCycle = false;
    _challenge100ClaimedThisCycle = false;
    _challengeRevealed = false;
    _aceDialogueEnabled = true;
    _firedFtueTriggers.clear();
    _shownAceLines.clear();
    _pendingAceLine = null;
    _pendingMilestoneToast = null;
    await _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    // Flush whatever's in memory to disk so the last frame of mutations
    // isn't lost. dispose() is sync, so fire-and-forget.
    unawaited(_persist());
    unawaited(_api.flushNow());
    _api.dispose();
    _iap.dispose();
    _ads.dispose();
    super.dispose();
  }

  /// Resolves a queued pickup at the head of the queue. Returns null if
  /// the queue is empty. Used in [buySlot4WithGemsAndSeat] sanity checks.
  String? peekQueueHead() => _pickupQueue.isEmpty ? null : _pickupQueue.first;
}
