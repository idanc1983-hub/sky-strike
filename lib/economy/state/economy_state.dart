import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../config/remote_config_service.dart';
import '../constants/ad_placement_catalog.dart';
import '../constants/economy_constants.dart';
import '../constants/iap_catalog.dart';
import '../constants/power_up_catalog.dart';
import '../services/ads_service.dart';
import '../services/challenge_formulas.dart';
import '../services/challenge_lifecycle.dart';
import '../services/chest_reward_resolver.dart';
import '../services/coin_reward_calculator.dart';
import '../services/day7_chest_formula.dart';
import '../services/day7_reward_resolver.dart';
import '../services/economy_api.dart';
import '../services/economy_persistence.dart';
import '../services/ftue_triggers.dart';
import '../services/iap_service.dart';
import '../services/offer_reward_parser.dart';
import '../services/pack_pricing.dart';
import '../services/power_up_picker.dart';
import '../services/revive_pricing.dart';
import '../services/streak_clock.dart';
import 'challenge_state.dart';
import 'loadout.dart';
import 'pending_celebration.dart';
import 'reward.dart';

/// Outcome of a stage-clear event. Carries the granted [Reward] plus
/// the list of newly unlocked power-ups so the host UI can drive the
/// world-advance celebration.
class StageClearOutcome {
  final Reward reward;
  final List<String> newlyUnlockedPowerUps;
  const StageClearOutcome({
    required this.reward,
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
  // Portion of the real balance whose arrival is still being celebrated:
  // it has been credited to [_coins]/[_gems] but the displayed holder value
  // (see [displayCoins]/[displayGems]) holds it back until the flying
  // coins land. Transient — never persisted.
  int _withheldCoins = 0;
  int _withheldGems = 0;
  // Currency/chest celebrations played by the route-level host overlay.
  final List<PendingCelebration> _pendingCelebrations = <PendingCelebration>[];
  // Challenge celebrations are drained by the home screen so the bar fills
  // in place on the challenge card (not via a separate overlay).
  final List<PendingCelebration> _pendingChallengeCelebrations =
      <PendingCelebration>[];
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
  // Per-stage ladder: 0-based index into the RC stage list. Each cycle
  // walks 0..lastStage. When `_challengeProgress` hits the current
  // stage's goal, its prize auto-grants and the index advances. On the
  // final stage, progress is clamped at the goal (no further counting).
  int _challengeStageIndex = 0;
  // v2: only the 100% completion milestone exists. The old 50% mid-cycle
  // claim was removed — players see a single end-of-cycle reward.
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

  // ---------------------------------------------------------------------------
  // Monetization
  // ---------------------------------------------------------------------------
  bool _adsRemoved = false;
  final Set<String> _packsPurchased = <String>{};
  final Set<String> _ownedJets = <String>{'jet_player'};
  final Set<String> _ownedJetSkins = <String>{};
  DateTime? _installDate;
  int _pendingNextJetDiscountPct = 0;

  // ---------------------------------------------------------------------------
  // FTUE — GDD v1.3 §10
  // ---------------------------------------------------------------------------
  final Set<String> _firedFtueTriggers = <String>{};

  /// Pending challenge milestone for which the UI should surface a
  /// celebratory toast on next app open. One of `'50'` / `'100'` / null.
  String? _pendingMilestoneToast;

  bool _initialized = false;

  // Reentrancy guards — protect synchronous double-fire (e.g. UI button
  // tapped twice in one frame before rebuild disables it).
  bool _claimingDaily = false;
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

  /// Balance shown in the top-bar holder. Equals the real balance except
  /// while a reward celebration is in flight, when the just-won amount is
  /// withheld until the flying coins land (then [releaseCelebration] lets
  /// it tick up). All spend/gating logic uses the real [coins]/[gems].
  int get displayCoins => _coins - _withheldCoins;
  int get displayGems => _gems - _withheldGems;

  /// True when there are queued reward celebrations waiting to play.
  bool get hasPendingCelebration => _pendingCelebrations.isNotEmpty;

  int get xp => _xp;
  int get xpMax => _xpMax;
  int get level => _level;
  int get currentWorld => _currentWorld;
  int get maxWorldReached => _maxWorldReached;
  int get unlockedLoadoutSlots => _unlockedLoadoutSlots;
  /// Read-only snapshot of all loadouts. The returned list and the inner
  /// objects are defensive copies — mutating them does not feed back into
  /// state. Use [renameLoadout] etc. to make changes that should persist.
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
  int get challengeStageIndex => _challengeStageIndex;
  DateTime? get challengeStartedAt => _challengeStartedAt;
  bool get challenge100Claimed => _challenge100ClaimedThisCycle;
  String? get pendingMilestoneToast => _pendingMilestoneToast;

  /// Read-only computed view of the current challenge, or `null` if no
  /// challenge is active yet (player hasn't crossed the level-4 gate).
  ChallengeView? get challengeView {
    final type = _activeChallengeType;
    final start = _challengeStartedAt;
    if (type == null || start == null) return null;
    final stages = RemoteConfigService.I.stagesFor(type.jsonValue);
    final metric =
        RemoteConfigService.I.challengeById(type.jsonValue)?.metric ?? 'kills';
    return ChallengeView(
      type: type,
      startedAt: start,
      progress: _challengeProgress,
      target: _challengeTarget,
      milestone100Claimed: _challenge100ClaimedThisCycle,
      metric: metric,
      stageIndex: _challengeStageIndex,
      stageCount: stages.length,
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
  bool get adsRemoved => _adsRemoved;
  Set<String> get packsPurchased => Set<String>.unmodifiable(_packsPurchased);
  Set<String> get ownedJets => Set<String>.unmodifiable(_ownedJets);
  bool ownsJet(String jetId) => _ownedJets.contains(jetId);

  Set<String> get ownedJetSkins => Set<String>.unmodifiable(_ownedJetSkins);
  bool ownsJetSkin(String skinId) => _ownedJetSkins.contains(skinId);
  int get pendingNextJetDiscountPct => _pendingNextJetDiscountPct;

  // FTUE surface
  Set<String> get firedFtueTriggers =>
      Set<String>.unmodifiable(_firedFtueTriggers);

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
    _currentStage = snap.currentStage;
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
    _ownedJets
      ..clear()
      ..addAll(snap.ownedJets)
      ..add('jet_player');
    _ownedJetSkins
      ..clear()
      ..addAll(snap.ownedJetSkins);
    _installDate = snap.installDate ?? _now();

    // Challenge / FTUE / Ace fields (added in v1.3)
    _activeChallengeType = snap.activeChallengeType;
    _challengeStartedAt = snap.challengeStartedAt;
    _challengeProgress = snap.challengeProgress;
    _challengeTarget = snap.challengeTarget;
    _challengeStageIndex = snap.challengeStageIndex;
    _challenge100ClaimedThisCycle = snap.challenge100Claimed;
    _challengeRevealed = snap.challengeRevealed;
    _firedFtueTriggers
      ..clear()
      ..addAll(snap.firedFtueTriggers);

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

  /// Returns the active cycle's RC stage entries (each: `{stage, goal,
  /// prize}`) or an empty list when no cycle is active / RC has no
  /// ladder for it. Order matches RC (stage 1 first).
  List<Map<String, dynamic>> get activeChallengeStages {
    final type = _activeChallengeType;
    if (type == null) return const <Map<String, dynamic>>[];
    final stages = RemoteConfigService.I.stagesFor(type.jsonValue);
    if (stages.isEmpty) return const <Map<String, dynamic>>[];
    return stages
        .map((s) => <String, dynamic>{
              'stage': s.stage,
              'goal': s.goal,
              'prize': s.prize,
            })
        .toList();
  }

  /// Reads the goal of the stage at [stageIndex] in the RC ladder for
  /// [type]. Returns null if RC has no ladder entry or the index is out
  /// of range so the caller can fall back to [ChallengeFormulas.targetFor].
  int? _ladderGoalAt(ChallengeType type, int stageIndex) {
    final stages = RemoteConfigService.I.stagesFor(type.jsonValue);
    if (stages.isEmpty || stageIndex < 0 || stageIndex >= stages.length) {
      return null;
    }
    return stages[stageIndex].goal;
  }

  /// Reads the prize string of the stage at [stageIndex] in the RC
  /// ladder for [type]. Returns an empty string when the index is out
  /// of range so callers can short-circuit cleanly.
  String _ladderPrizeAt(ChallengeType type, int stageIndex) {
    final stages = RemoteConfigService.I.stagesFor(type.jsonValue);
    if (stages.isEmpty || stageIndex < 0 || stageIndex >= stages.length) {
      return '';
    }
    return stages[stageIndex].prize;
  }

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
    _challengeStageIndex = 0;
    _challengeTarget = _ladderGoalAt(type, 0) ??
        ChallengeFormulas.targetFor(type: type, playerLevel: _level);
    _challenge100ClaimedThisCycle = false;
    _scheduleSync();
    notifyListeners();
  }

  /// Marks the challenge as revealed (player just cleared stage 3) and
  /// starts the very first cycle — the one-time `newPlayers` intro. The
  /// `_challengeRevealed` flag persists in SharedPreferences, so the
  /// 72h timer keeps running across app launches and only "resets to
  /// new_players" on a clean install (which wipes prefs).
  ///
  /// No-op if [_challengeRevealed] is already true.
  void markChallengeRevealed() {
    if (_challengeRevealed) return;
    _challengeRevealed = true;
    startNewChallengeCycle();
  }

  /// Stage-progression gate for the new_players challenge. The first
  /// cycle starts when the player crosses *into* this stage — i.e.
  /// after clearing stage `challengeUnlockLevel - 1` (stage 3 today).
  ///
  /// Only [setCurrentStage] consults this — XP gains alone never
  /// reveal the challenge, since XP grants from FTUE/daily-reward etc.
  /// could otherwise burn the 72h window before the player has even
  /// engaged with the game loop.
  static const int challengeUnlockLevel = 4;

  /// Auto-claims the 100% completion reward if reached during an expired
  /// cycle, then starts the next cycle. Called from
  /// [_checkChallengeCycleExpiry] on app foreground.
  ///
  /// v2: there is only a single completion reward. If the player didn't
  /// hit 100% before the cycle expired, nothing is granted.
  void _autoClaimAndAdvanceIfExpired() {
    final view = challengeView;
    if (view == null) return;
    if (!view.isExpired(_now())) return;

    if (view.canClaim100) {
      _grantChallengeMilestoneReward();
      _challenge100ClaimedThisCycle = true;
      _pendingMilestoneToast = '100';
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

  /// Manual claim of the 100% milestone reward. Returns the reward, or
  /// [Reward.empty] if the milestone is not currently claimable.
  Reward claimChallengeMilestone100() {
    if (_claiming100) return Reward.empty;
    final view = challengeView;
    if (view == null || !view.canClaim100) return Reward.empty;
    _claiming100 = true;
    _challenge100ClaimedThisCycle = true;
    try {
      final reward = _grantChallengeMilestoneReward();
      _scheduleSync();
      notifyListeners();
      return reward;
    } finally {
      _claiming100 = false;
    }
  }

  /// Grants the 100% challenge-milestone reward. The coins are the
  /// deterministic figure the home card previews
  /// ([ChallengeFormulas.milestone100Coins]) and are flown into the holder so
  /// the reveal animation matches exactly what the player was shown — the
  /// ±20% jitter that [ChallengeFormulas.reward100] rolls is intentionally
  /// dropped here. The milestone gems and power-up are bonuses the card never
  /// advertises, so they're credited silently. Returns the granted reward.
  Reward _grantChallengeMilestoneReward() {
    final coins = ChallengeFormulas.milestone100Coins(playerLevel: _level);
    final bonus = ChallengeFormulas.reward100(
      playerLevel: _level,
      maxWorldReached: _maxWorldReached,
      rng: _rng,
    );
    // Power-up + gems are unadvertised → apply silently (no fly animation).
    for (final id in bonus.powerUps) {
      _powerUpInventory[id] = (_powerUpInventory[id] ?? 0) + 1;
    }
    if (bonus.gems > 0) _gems += bonus.gems;
    // Only the previewed coins fly into the holder.
    _grantCelebrated(coins: coins, kind: CelebrationKind.currency);
    return Reward(coins: coins, gems: bonus.gems, powerUps: bonus.powerUps);
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
        _addChallengeProgress(1);
      }
    } else if (_activeChallengeType == ChallengeType.conqueror) {
      if (stars >= 2) _addChallengeProgress(1);
    }
  }

  /// Single entry point for every metric (kills / survives / score /
  /// stars). Adds [amount] to `_challengeProgress`, then runs the
  /// ladder-advance loop:
  ///
  ///   • If the current stage's goal is met, grant its RC prize, reset
  ///     progress to 0, and advance `_challengeStageIndex` to the next
  ///     stage's goal — repeat in case a big single increment (e.g. a
  ///     score-metric coin haul) clears multiple stages at once.
  ///   • On the final stage, clamp progress at the goal so counting
  ///     stops (no more grants, no further +1 reads).
  ///
  /// A single increment can clear several stages in one call (only
  /// realistic for the Treasure `score` metric, which adds run coin
  /// totals), hence the while-loop. Callers should pass non-positive
  /// amounts (no-op) only when the metric explicitly resets — Survivor
  /// resets directly via `_challengeProgress = 0` to bypass this path.
  void _addChallengeProgress(int amount) {
    if (amount <= 0) return;
    if (_activeChallengeType == null) return;
    if (_challengeTarget <= 0) {
      // No RC ladder loaded — keep the legacy single-target behaviour
      // (just accumulate) so the cycle still records progress on a
      // misconfigured RC instead of silently swallowing kills.
      _challengeProgress += amount;
      return;
    }
    final type = _activeChallengeType!;
    final stages = RemoteConfigService.I.stagesFor(type.jsonValue);
    if (stages.isEmpty) {
      _challengeProgress += amount;
      return;
    }
    final lastIdx = stages.length - 1;
    // Bar fill animation start: where the bar sat before this increment.
    final preTarget = _challengeTarget;
    final preProgress = _challengeProgress;
    var firstGrant = true;
    _challengeProgress += amount;
    while (_challengeProgress >= _challengeTarget) {
      // Grant this stage's prize before advancing — the player earned
      // it the moment they crossed the goal. The first prize fills the bar
      // from where it was; any further stages cleared in one go fill from 0.
      final fromFraction = firstGrant && preTarget > 0
          ? (preProgress / preTarget).clamp(0.0, 1.0)
          : 0.0;
      firstGrant = false;
      _grantChallengeStagePrize(
        _ladderPrizeAt(type, _challengeStageIndex),
        fromFraction: fromFraction,
        label: type.displayName,
      );
      if (_challengeStageIndex >= lastIdx) {
        // Final stage cleared — clamp at goal and stop counting.
        _challengeProgress = _challengeTarget;
        _challenge100ClaimedThisCycle = true;
        break;
      }
      final overflow = _challengeProgress - _challengeTarget;
      _challengeStageIndex += 1;
      _challengeTarget = _ladderGoalAt(type, _challengeStageIndex) ?? 0;
      _challengeProgress = overflow;
      if (_challengeTarget <= 0) break;
    }
  }

  /// Applies an RC challenge stage prize string (e.g. "70coin",
  /// "epic_chest", "200coin + epic_chest", "biome_chest_match + 50gem
  /// + 500coin") to the player's wallet. Chest tokens are rolled via
  /// the standard chest resolver so the player receives the chest's
  /// rolled contents rather than a placeholder token; coin/gem tokens
  /// add directly. Unknown tokens are ignored.
  void _grantChallengeStagePrize(
    String raw, {
    double fromFraction = 0,
    String label = '',
  }) {
    if (raw.isEmpty) return;
    final parts = raw.split(RegExp(r'\s*\+\s*'));
    var reward = Reward.empty;
    var hadChest = false;
    for (final partRaw in parts) {
      final part = partRaw.trim();
      if (part.isEmpty) continue;
      final coinMatch = RegExp(r'^(\d+)\s*coin$').firstMatch(part);
      if (coinMatch != null) {
        reward = reward.plus(Reward(coins: int.parse(coinMatch.group(1)!)));
        continue;
      }
      final gemMatch = RegExp(r'^(\d+)\s*gem$').firstMatch(part);
      if (gemMatch != null) {
        reward = reward.plus(Reward(gems: int.parse(gemMatch.group(1)!)));
        continue;
      }
      if (part.endsWith('_chest') || part == 'biome_chest_match') {
        hadChest = true;
        final chestId = part == 'biome_chest_match'
            ? '${_biomeChestKeyForWorld(_currentWorld)}_chest'
            : part;
        try {
          final def = RemoteConfigService.I.chests.byId(chestId);
          if (def != null) {
            final roll = ChestRewardResolver.resolve(
              definition: _chestDefAsLegacyMap(def),
              rng: _rng,
            );
            reward = reward.plus(roll.reward);
          }
        } catch (_) {
          // RC unavailable in test/early-boot — skip the chest roll
          // rather than crash the grant. The coin/gem portion of a
          // compound prize still applies.
        }
      }
    }
    // Credit now, but celebrate on the next safe screen: the challenge bar
    // fills to 100%, then the prize is collected (chest open, or fly).
    if (!reward.isEmpty || hadChest) {
      _grantCelebrated(
        coins: reward.coins,
        gems: reward.gems,
        kind: CelebrationKind.challenge,
        isChest: hadChest,
        fromFraction: fromFraction,
        label: label,
      );
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

  /// Credits [coins]/[gems] and reveals them with the fly-to-holder
  /// celebration (display-lag), so a direct shop pack purchase shows the
  /// same reward animation as the daily reward / chest flows instead of a
  /// silent balance bump. [source] is reserved for analytics.
  void grantCurrencyCelebration({
    int coins = 0,
    int gems = 0,
    String source = 'unspecified',
  }) {
    _grantCelebrated(coins: coins, gems: gems);
  }

  // ---------------------------------------------------------------------------
  // Reward celebrations (display-lag): credit the real balance now, but hold
  // the displayed holder value back until the flying coins land.
  // ---------------------------------------------------------------------------

  /// Credits [coins]/[gems] to the real balance and queues a celebration
  /// whose displayed value is withheld until the fly animation lands. Credit
  /// and withhold happen together so the holder never flickers. [kind]
  /// chooses the presentation (plain fly, challenge-bar+prize, chest-open).
  void _grantCelebrated({
    int coins = 0,
    int gems = 0,
    CelebrationKind kind = CelebrationKind.currency,
    bool isChest = false,
    double fromFraction = 0,
    String label = '',
  }) {
    final c = coins > 0 ? coins : 0;
    final g = gems > 0 ? gems : 0;
    final chest = isChest || kind == CelebrationKind.chest;
    if (c == 0 && g == 0 && !chest) return;
    _coins += c;
    _gems += g;
    _withheldCoins += c;
    _withheldGems += g;
    final celebration = PendingCelebration(
      kind: kind,
      coins: c,
      gems: g,
      isChest: chest,
      fromFraction: fromFraction,
      label: label,
    );
    // Challenge prizes animate on the home challenge card; everything else
    // plays through the route-level host overlay.
    if (kind == CelebrationKind.challenge) {
      _pendingChallengeCelebrations.add(celebration);
    } else {
      _pendingCelebrations.add(celebration);
    }
    if (c > 0 || g > 0) _scheduleSync();
    notifyListeners();
  }

  /// Debug-only: force an active challenge cycle (reveals + starts one) and
  /// seeds ~50% progress so the home card shows an unlocked, partly-filled
  /// bar to celebrate onto.
  void debugActivateChallengeCycle() {
    assert(kDebugMode, 'debugActivateChallengeCycle is debug-only');
    _challengeRevealed = true;
    startNewChallengeCycle();
    if (_challengeTarget > 0) {
      _challengeProgress = (_challengeTarget * 0.5).round();
    }
    _scheduleSync();
    notifyListeners();
  }

  /// Debug-only: queue a challenge-prize celebration (credits + withholds)
  /// so the home challenge-card animation can be previewed. Ensures a cycle
  /// is active first so the card is unlocked and can fly the prize.
  void debugWinChallengePrize({
    int coins = 200,
    int gems = 50,
    double fromFraction = 0.55,
    String label = 'Treasure Hunter',
    bool isChest = false,
  }) {
    assert(kDebugMode, 'debugWinChallengePrize is debug-only');
    if (challengeView == null) debugActivateChallengeCycle();
    _grantCelebrated(
      coins: coins,
      gems: gems,
      kind: CelebrationKind.challenge,
      isChest: isChest,
      fromFraction: fromFraction,
      label: label,
    );
  }

  /// Public entry for currency won/bought outside the economy layer (e.g.
  /// shop bundles): credits now, celebrates on the next safe screen.
  void beginCurrencyCelebration({int coins = 0, int gems = 0}) =>
      _grantCelebrated(coins: coins, gems: gems);

  /// First queued celebration without removing it (lets the host decide
  /// whether to play a chest individually or aggregate a run of currency).
  PendingCelebration? peekCelebration() =>
      _pendingCelebrations.isEmpty ? null : _pendingCelebrations.first;

  /// Removes and returns the next queued celebration. Does not notify — the
  /// queue doesn't affect the displayed balance (that follows the withheld
  /// amount, released as the coins land via [releaseCelebration]).
  PendingCelebration? takeCelebration() =>
      _pendingCelebrations.isEmpty ? null : _pendingCelebrations.removeAt(0);

  /// Challenge-prize celebrations, drained by the home challenge card.
  bool get hasPendingChallengeCelebration =>
      _pendingChallengeCelebrations.isNotEmpty;

  PendingCelebration? peekChallengeCelebration() =>
      _pendingChallengeCelebrations.isEmpty
          ? null
          : _pendingChallengeCelebrations.first;

  PendingCelebration? takeChallengeCelebration() =>
      _pendingChallengeCelebrations.isEmpty
          ? null
          : _pendingChallengeCelebrations.removeAt(0);

  /// Lets the previously-withheld [coins]/[gems] show in the holder — called
  /// as the flying coins land so the counter ticks up.
  void releaseCelebration({int coins = 0, int gems = 0}) {
    final c = coins > 0 ? coins : 0;
    final g = gems > 0 ? gems : 0;
    if (c == 0 && g == 0) return;
    _withheldCoins -= c;
    if (_withheldCoins < 0) _withheldCoins = 0;
    _withheldGems -= g;
    if (_withheldGems < 0) _withheldGems = 0;
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

  /// Buys [jetId] for [priceGems]. Returns true if the jet is owned after
  /// the call (either newly bought or already owned). Returns false only
  /// when the player has insufficient gems.
  ///
  /// Honours any `_pendingNextJetDiscountPct` left over from a discount-
  /// bearing IAP pack (Pilot/Squadron Bundle). The discount is consumed
  /// on a successful purchase regardless of price (so a player who
  /// receives a free jet from a chest still spends the discount slot —
  /// flag for design review if that changes).
  bool buyJet(String jetId, int priceGems) {
    if (_ownedJets.contains(jetId)) return true;
    if (priceGems < 0) return false;
    final discounted = _applyJetDiscount(priceGems);
    if (discounted > 0 && _gems < discounted) return false;
    _gems -= discounted;
    _ownedJets.add(jetId);
    if (_pendingNextJetDiscountPct > 0) {
      _pendingNextJetDiscountPct = 0;
    }
    _scheduleSync();
    notifyListeners();
    return true;
  }

  /// Returns [priceGems] with any pending next-jet discount applied.
  /// Discount is a percentage in 0..100; rounded so the player never
  /// pays a fractional gem.
  int _applyJetDiscount(int priceGems) {
    if (_pendingNextJetDiscountPct <= 0 || priceGems <= 0) return priceGems;
    final pct = _pendingNextJetDiscountPct.clamp(0, 100);
    final discounted = (priceGems * (100 - pct) / 100).round();
    return discounted < 0 ? 0 : discounted;
  }

  /// Read-only computed view of the jet price after any pending discount.
  /// UI surfaces this so the player sees the discounted price up-front.
  int discountedJetPrice(int priceGems) => _applyJetDiscount(priceGems);

  /// Adds XP and cascades level-ups. Each level raises [xpMax] by 10%
  /// (capped — see [_xpMaxCap]). Players never lose XP (GDD §2.3). Fires
  /// milestone triggers on Lv 10 / 25 / 50 transitions even if multiple
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
      // NOTE: challenge unlock is intentionally NOT fired here. Per the
      // current design the new_players timer only starts when the player
      // clears stage 3 (see [setCurrentStage]). XP-only growth (e.g.
      // FTUE coin grants pushing XP across the threshold) must not
      // trigger the cycle and burn its 72h window.
    }
    notifyListeners();
  }

  /// Fires every milestone trigger crossed by a level transition. A big
  /// XP grant that jumps level 9 → level 50 must fire 10/25/50 in turn,
  /// not just the highest.
  void _maybeFireLevelMilestonesCrossed(int from, int to) {
    for (final trigger in FtueRules.milestonesCrossed(from, to)) {
      _firedFtueTriggers.add(trigger);
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
    notifyListeners();
  }

  /// Banks coins collected during a run (enemy drops, HP-at-max
  /// conversions) into the run accumulator instead of crediting them live.
  /// They are realized — and fly to the holder — on stage clear (full) or
  /// death (40% salvage). No-op for non-positive amounts.
  void recordRunCoins(int amount) {
    if (amount <= 0) return;
    _accumulatedRunCoins += amount;
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
    // Credit now; the salvage coins fly into the holder on the next menu
    // screen (aggregated with any stage-clear coins from the same session).
    _grantCelebrated(coins: salvage.coins);
    _accumulatedRunCoins = 0;
    _stageRevivesUsed = 0;
    _playerDiedThisStage = true;
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

    // Credit now, but fly ONLY the coins into the holder on the next menu
    // screen (Home). The stage-clear overlay advertises coins only (see
    // [_RewardRow] in game_screen) — the first-time milestone gems are not
    // shown there, so they are credited silently rather than revealed by a
    // fly animation the player was never promised. (The animation must show
    // only what the preview promised.)
    if (gems > 0) _gems += gems;
    _grantCelebrated(coins: coins);

    // Drive Treasure Hunter challenge counter (gameplay coins only).
    if (_activeChallengeType == ChallengeType.treasure && coins > 0) {
      _addChallengeProgress(coins);
    }

    // Drive Survivor + Conqueror challenge counters.
    _updateChallengeOnStageClear(
      stars: effectiveStars,
      diedThisStage: _playerDiedThisStage,
    );

    if (isFirstClear) _completedStages.add(stageId);
    if (isFirstThreeStar) _threeStarStages.add(stageId);
    if (isFirstBoss) _defeatedBosses.add('w$_currentWorld');

    // FTUE: mark Stage 1 completion → unblocks home-screen coin chip.
    if (_currentWorld == 1 &&
        _currentStage == 1 &&
        !_firedFtueTriggers.contains(FtueTriggers.stage1Completed)) {
      _firedFtueTriggers.add(FtueTriggers.stage1Completed);
    }

    // Reset per-stage session state.
    _accumulatedRunCoins = 0;
    _stageRevivesUsed = 0;
    _playerDiedThisStage = false;

    _scheduleSync();
    notifyListeners();
    return StageClearOutcome(
      reward: Reward(coins: coins, gems: gems),
      newlyUnlockedPowerUps: const <String>[],
    );
  }

  /// Test/debug-only helper: drives the same code path as a real
  /// gameplay-loop stage clear. Use from the long-press LAUNCH debug
  /// hook to simulate a Stage 3 clear.
  StageClearOutcome debugSimulateStageClear({
    required int world,
    required int stage,
    required int stars,
    required bool isBossDefeat,
    required bool diedDuringRun,
    int simulatedRunCoins = 0,
  }) {
    assert(kDebugMode, 'debugSimulateStageClear is debug-only');
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

  /// Records an in-mission power-up pickup. POWERUP-v2.1 unified the
  /// pickup flow: every type just bumps the inventory counter. The
  /// dynamic tray rebuilds off [powerUpInventory], so there is no slot
  /// assignment or overflow queue to track.
  void onPowerUpPickup(String powerUpId) {
    _powerUpInventory[powerUpId] =
        (_powerUpInventory[powerUpId] ?? 0) + 1;
    _scheduleSync();
    notifyListeners();
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

  /// Adds [count] copies of [powerUpId] to the inventory without charging
  /// coins. Used by call sites (e.g. the v2 shop tab) that source pricing
  /// from Remote Config and have already handled the spend themselves.
  void grantPowerUp(String powerUpId, {int count = 1}) {
    if (count <= 0) return;
    _powerUpInventory[powerUpId] =
        (_powerUpInventory[powerUpId] ?? 0) + count;
    _scheduleSync();
    notifyListeners();
  }

  /// Records ownership of a cosmetic jet skin. Idempotent — re-granting an
  /// owned skin is a no-op. Call only after a purchase is confirmed.
  void grantJetSkin(String skinId) {
    if (skinId.isEmpty) return;
    if (_ownedJetSkins.add(skinId)) {
      _scheduleSync();
      notifyListeners();
    }
  }

  /// Applies a chest payout that the caller has already resolved (coins /
  /// gems / an optional jet) from Remote Config. Kept here so chest grants
  /// from offers and bundles run through the same wallet path as every
  /// other reward; resolution itself stays in the UI/config layer.
  void grantChest({int coins = 0, int gems = 0, String? jetId}) {
    // Jets are granted outright (they don't fly to a currency holder); the
    // coins/gems are credited now but celebrated via the chest-open
    // sequence, ticking up the holder as they land.
    if (jetId != null && jetId.isNotEmpty) buyJet(jetId, 0);
    _grantCelebrated(coins: coins, gems: gems, kind: CelebrationKind.chest);
  }

  /// Removes [count] copies of [powerUpId] from the inventory. Returns
  /// true if the inventory had enough to deduct; false (no mutation) if
  /// not. Used when the player consumes a stockpiled power-up.
  bool consumePowerUp(String powerUpId, {int count = 1}) {
    if (count <= 0) return false;
    final have = _powerUpInventory[powerUpId] ?? 0;
    if (have < count) return false;
    final remaining = have - count;
    if (remaining == 0) {
      _powerUpInventory.remove(powerUpId);
    } else {
      _powerUpInventory[powerUpId] = remaining;
    }
    _scheduleSync();
    notifyListeners();
    return true;
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

  /// Builds the base D1–D6 streak reward from the Remote-Config
  /// `daily_reward` entry the calendar UI renders, so the grant always
  /// matches the displayed amount. Returns the constants-based ladder
  /// when RC has no entry for the (week, day) pair (test environments,
  /// missing RC payload). A `chest` entry on the day is rolled here via
  /// [ChestRewardResolver] so the player receives the chest contents at
  /// claim time.
  ({Reward reward, bool fromChest}) _ladderRewardFromRc(
      {required int week, required int day}) {
    // RC accessors throw when Firebase isn't initialized (test envs, very
    // early boot). Fall back to the constants ladder in that case so a
    // claim never crashes the app — the displayed amount may differ from
    // the granted one in that degraded path, but the claim still succeeds.
    DailyRewardDay? rc;
    Map<String, dynamic>? chestDefinition;
    String? chestId;
    try {
      final rcs = RemoteConfigService.I;
      final cap = rcs.dailyReward.weekCap;
      final cappedWeek = week > cap ? cap : week;
      rc = rcs.dailyReward.dayFor(week: cappedWeek, dayOfWeek: day);
      chestId = rc?.chestType;
      if (chestId != null && chestId.isNotEmpty) {
        final def = rcs.chests.byId(chestId);
        if (def != null) chestDefinition = _chestDefAsLegacyMap(def);
      }
    } catch (_) {
      return (reward: StreakClock.baseLadderReward(day), fromChest: false);
    }
    if (rc == null) {
      return (reward: StreakClock.baseLadderReward(day), fromChest: false);
    }
    final coin = rc.coinPrize;
    final gem = rc.gemPrize;
    var reward = Reward(coins: coin, gems: gem);
    final fromChest = chestDefinition != null;
    if (chestDefinition != null) {
      final roll = ChestRewardResolver.resolve(
        definition: chestDefinition,
        rng: _rng,
      );
      reward = reward.plus(roll.reward);
    }
    return (reward: reward, fromChest: fromChest);
  }

  /// Resolves the Day-7 reward from the same `dailyReward(week, 7)` RC
  /// entry the calendar tile renders. Falls back to [Day7ChestFormula]
  /// when RC isn't available (test envs, very early boot) so the claim
  /// path never crashes.
  ({Reward reward, bool fromChest}) _resolveDay7Reward() {
    try {
      final rcs = RemoteConfigService.I;
      final requestedWeek = _streakWeeksCompleted + 1;
      final cap = rcs.dailyReward.weekCap;
      final cappedWeek = requestedWeek > cap ? cap : requestedWeek;
      final rcEntry = rcs.dailyReward.dayFor(week: cappedWeek, dayOfWeek: 7);
      if (rcEntry == null) {
        return (
          reward: Day7ChestFormula.compute(
            playerLevel: _level,
            maxWorldReached: _maxWorldReached,
            rng: _rng,
          ),
          fromChest: true,
        );
      }
      final chestsConfig = rcs.chests;
      final resolved = Day7RewardResolver.resolve(
        rcEntry: <String, dynamic>{
          'coin': rcEntry.coinPrize,
          'gem': rcEntry.gemPrize,
          'chest': rcEntry.chestType,
          'jet': rcEntry.jetType,
          'jet_fallback': rcEntry.jetFallback,
        },
        currentWorld: _currentWorld,
        ownsJet: (codeId) => _ownedJets.contains(codeId),
        chestDefinitionLookup: (chestId) {
          final def = chestsConfig.byId(chestId);
          return def == null ? null : _chestDefAsLegacyMap(def);
        },
        rng: _rng,
      );
      // Day 7 is the weekly chest tile — reveal coins/gems through the
      // chest-open sequence whenever the entry actually carries a chest.
      final chestType = rcEntry.chestType;
      final hadChest = chestType != null && chestType.isNotEmpty;
      return (reward: resolved.reward, fromChest: hadChest);
    } catch (_) {
      // RC accessors throw when Firebase isn't initialized — fall back
      // to the constants-based formula so the claim still succeeds.
      return (
        reward: Day7ChestFormula.compute(
          playerLevel: _level,
          maxWorldReached: _maxWorldReached,
          rng: _rng,
        ),
        fromChest: true,
      );
    }
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
      bool fromChest;
      if (_streakDay == 7) {
        // Drive Day 7 from the same RC entry the calendar tile renders
        // so the grant matches what the player sees — jet on unowned
        // biome jet, parsed fallback bundle (e.g. epic_chest + 50gem)
        // when already owned. Falls back to [Day7ChestFormula] when RC
        // has no entry (test env / degraded RC).
        final r = _resolveDay7Reward();
        reward = r.reward;
        fromChest = r.fromChest;
      } else {
        // Source the base coin/gem grant from Remote Config so the player
        // gets exactly the amounts shown on the reward calendar tile (the
        // screen reads from the same `dailyReward(week, day)` entry).
        // Falls back to constants when RC has no entry — keeps tests that
        // run without an RC payload working.
        final r = _ladderRewardFromRc(
          week: _streakWeeksCompleted + 1,
          day: _streakDay,
        );
        var base = r.reward;
        fromChest = r.fromChest;
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

      _applyReward(reward, fromChest: fromChest);

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
  /// Called by the gameplay loop on every confirmed enemy kill. Drives
  /// kill-metric challenge cycles — Hunter (the standard rotation) and
  /// the newPlayers intro (which also uses the `kills` metric per the
  /// v2 RC `challenges__cycle_plan__v1.cycles.new_players.metric`).
  void onEnemyKilled() {
    if (_activeChallengeType == ChallengeType.hunter ||
        _activeChallengeType == ChallengeType.newPlayers) {
      _addChallengeProgress(1);
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
    final priorGlobalLevel = (_currentWorld - 1) * 10 + _currentStage;
    _currentStage = stage;
    final newGlobalLevel = (_currentWorld - 1) * 10 + _currentStage;
    // Challenge unlock gate — the *only* path that starts the 72h
    // new_players timer. Fires when the player crosses *into*
    // [challengeUnlockLevel] (stage 4), i.e. immediately after clearing
    // stage 3. The XP-level path intentionally does not unlock so the
    // timer can only burn after the player engages with stage gameplay.
    // markChallengeRevealed is a no-op if already revealed, so this is
    // safe to call unconditionally; the flag persists across app
    // sessions and only resets on reinstall.
    if (priorGlobalLevel < challengeUnlockLevel &&
        newGlobalLevel >= challengeUnlockLevel) {
      markChallengeRevealed();
    }
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

  /// Runs an IAP purchase for [productId] and applies the caller-supplied
  /// [onConfirmed] grant **only** when the store reports a successful,
  /// completed transaction.
  ///
  /// Use this for products whose reward is data-driven and therefore NOT
  /// derivable from [IapCatalog] — shop currency packs, data-driven shop
  /// bundles, and live-ops offers, where the same store SKU can back many
  /// different in-game rewards. (Catalog-mapped packs still go through
  /// [purchaseIap].) Returns the raw store outcome so the CTA can render
  /// success or shake on cancel/failure.
  Future<IapPurchaseOutcome> purchaseProduct(
    String productId, {
    required void Function() onConfirmed,
  }) async {
    final outcome = await _iap.requestPurchase(productId);
    if (outcome.result == IapPurchaseResult.success) {
      // The grant helpers (addCoins/addGems/grantPowerUp/buyJet) each
      // schedule a sync and notify, so no extra bookkeeping is needed here.
      onConfirmed();
    }
    return outcome;
  }

  /// Asks the platform store to re-deliver previously purchased
  /// non-consumables (Remove Ads). Re-delivered purchases flow through
  /// the same purchase stream as fresh ones, so any matching reward is
  /// applied by the existing handler without extra work here.
  Future<void> restorePurchases() => _iap.restorePurchases();

  /// Shows a rewarded ad for [placement] via [AdsService]. On success
  /// applies the placement's reward and updates daily counters.
  Future<AdShowOutcome> showRewardedAd(AdPlacement placement) async {
    // Roll the daily window before the cap check — otherwise a player
    // who hit the cap yesterday stays capped forever, since the reset
    // used to live inside [_applyAdReward] (which we never reach when
    // we early-return as `capReached`).
    if (placement == AdPlacement.extraGemsDaily) {
      _resetDailyAdWatchIfNewDay();
    }
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

  /// Applies a parsed list of monetization-offer reward [items] to the
  /// wallet/inventory. Call only after the backing purchase is confirmed
  /// (see [purchaseProduct]).
  ///
  /// Handles `coin`, `gem`, and `powerupPack` (random pick via
  /// [PowerUpPicker], matching the coin-pack grant path). `chest` and
  /// `unknown` items are NOT granted here — chest payouts need Remote
  /// Config definitions + biome context that live in the UI layer — and
  /// are returned to the caller so it can resolve them or surface a gap.
  /// Returns the raw tokens of any items left ungranted.
  List<String> applyOfferRewards(List<OfferRewardItem> items) {
    final ungranted = <String>[];
    var offerCoins = 0;
    var offerGems = 0;
    for (final item in items) {
      switch (item.kind) {
        case OfferRewardKind.coin:
          offerCoins += item.amount;
          break;
        case OfferRewardKind.gem:
          offerGems += item.amount;
          break;
        case OfferRewardKind.powerupPack:
          final picks = PowerUpPicker.pickMany(
            count: item.amount,
            maxWorldReached: _maxWorldReached,
            rng: _rng,
          );
          for (final id in picks) {
            _powerUpInventory[id] = (_powerUpInventory[id] ?? 0) + 1;
          }
          if (picks.isNotEmpty) {
            _scheduleSync();
            notifyListeners();
          }
          break;
        case OfferRewardKind.chest:
        case OfferRewardKind.unknown:
          ungranted.add(item.raw);
          break;
      }
    }
    // Coins/gems are credited now and flown into the holder via a single
    // celebration; chest tokens are resolved + celebrated by the caller.
    if (offerCoins > 0 || offerGems > 0) {
      _grantCelebrated(coins: offerCoins, gems: offerGems);
    }
    return ungranted;
  }

  void _applyIapReward(String productId) {
    // Only the currency the purchase UI actually advertised flies into the
    // holder via the celebration; unadvertised bonuses are credited silently.
    // Main-shop packs headline their gems, so those fly. Coin packs (the
    // out-of-coins offer) advertise COINS only — their bundled bonus gems and
    // power-ups must not appear in the reward animation, which is wired to
    // show only what the player was shown.
    var celebratedCoins = 0;
    var celebratedGems = 0;
    var silentGems = 0;
    final mainGems = IapCatalog.mainPackGems[productId];
    if (mainGems != null) {
      celebratedGems += mainGems;
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
      celebratedCoins += coinPack;
      // Bonus gems bundled with a coin pack aren't advertised → credit silently.
      silentGems += IapCatalog.coinPackGems[productId] ?? 0;
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
    // Silent bonus gems are credited straight to the balance (no fly), then
    // the advertised coins/gems fly via the celebration. Both notify + sync.
    if (silentGems > 0) _gems += silentGems;
    _grantCelebrated(coins: celebratedCoins, gems: celebratedGems);
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
        // Credit + queue a currency fly so the gems collect the same way as
        // every other reward (plays on the next celebration host screen).
        _grantCelebrated(gems: (gems * mult).floor());
        _dailyAdWatchCount += 1;
        // Monotonic stamp — never let the watch date move backward.
        // Combined with [_resetDailyAdWatchIfNewDay] below, this defeats
        // the "roll the clock back to today" cap-reset exploit: once
        // the stamp is in the future relative to the device clock, the
        // cap holds until real time catches up.
        final now = _now();
        final last = _dailyAdWatchDate;
        _dailyAdWatchDate =
            (last == null || now.isAfter(last)) ? now : last;
        break;
      case AdPlacement.chestBoost:
        // The +25% bonus is applied at chest-claim time via the
        // adBoosted flag; nothing to do here besides notifying.
        break;
    }
    _scheduleSync();
    notifyListeners();
  }

  /// Resets the daily-ad watch counter when the wall-clock day has
  /// advanced past the last recorded watch.
  ///
  /// Clock-rollback defense: when `_now()` is earlier than the last
  /// stored watch date, the device clock was moved backward — we do
  /// NOT reset. The cap stays in force until real time catches up to
  /// the stored timestamp. The watch-date itself is stamped
  /// monotonically by [_applyAdReward], so a single rollback cannot
  /// re-claim today's slots.
  ///
  /// Note: this is best-effort client mitigation. A determined cheater
  /// can still roll the clock *forward* across separate app sessions
  /// (one cap reset per real-time interval needed for the stamp to
  /// catch up). Full defense requires server-side reconciliation —
  /// flagged for the backend pass that will replace
  /// [EconomyApi._flushToBackend].
  void _resetDailyAdWatchIfNewDay() {
    final last = _dailyAdWatchDate;
    if (last == null) return;
    final now = _now();
    if (now.isBefore(last)) return;
    if (StreakClock.dayDelta(last, now) >= 1) {
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
      currentStage: _currentStage,
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
      ownedJets: Set<String>.from(_ownedJets),
      ownedJetSkins: Set<String>.from(_ownedJetSkins),
      installDate: _installDate,
      pendingNextJetDiscountPct: _pendingNextJetDiscountPct,
      activeChallengeType: _activeChallengeType,
      challengeStartedAt: _challengeStartedAt,
      challengeProgress: _challengeProgress,
      challengeTarget: _challengeTarget,
      challengeStageIndex: _challengeStageIndex,
      challenge100Claimed: _challenge100ClaimedThisCycle,
      challengeRevealed: _challengeRevealed,
      firedFtueTriggers: Set<String>.from(_firedFtueTriggers),
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

  void _applyReward(Reward reward, {bool fromChest = false}) {
    // Power-ups / jet / XP apply immediately; coins & gems are credited now
    // but flown into the holder via a celebration (daily reward, challenge
    // 100% milestone, etc.). When the reward was won from a chest, the
    // coins/gems are revealed through the chest-open sequence instead of the
    // plain currency fly.
    for (final id in reward.powerUps) {
      _powerUpInventory[id] = (_powerUpInventory[id] ?? 0) + 1;
    }
    final jet = reward.jet;
    if (jet != null && jet.isNotEmpty) {
      _ownedJets.add(jet);
    }
    if (reward.xp > 0) addXP(reward.xp);
    if (reward.coins > 0 || reward.gems > 0) {
      _grantCelebrated(
        coins: reward.coins,
        gems: reward.gems,
        kind: fromChest ? CelebrationKind.chest : CelebrationKind.currency,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // FTUE triggers (GDD v1.3 §10)
  // ---------------------------------------------------------------------------

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

  /// Clears all FTUE-track flags so the coin chip hides until Stage 1
  /// first clear and the Stage 3 reveal can replay. Does NOT touch
  /// wallets or progression.
  void debugReplayFtue() {
    assert(kDebugMode, 'debugReplayFtue is debug-only');
    _firedFtueTriggers.clear();
    _challengeRevealed = false;
    _activeChallengeType = null;
    _challengeStartedAt = null;
    _challengeProgress = 0;
    _challengeTarget = 0;
    _challengeStageIndex = 0;
    _challenge100ClaimedThisCycle = false;
    _pendingMilestoneToast = null;
    _scheduleSync();
    notifyListeners();
  }

  /// Debug-only: simulates a Stage 1 clear so the player gets the
  /// Stage 1 reward + the FTUE "Hell yes!" Ace line + home-screen
  /// coin chip visibility flip without having to play through.
  StageClearOutcome debugSimulateStage1Clear() {
    assert(kDebugMode, 'debugSimulateStage1Clear is debug-only');
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
    assert(kDebugMode, 'debugSetCoins is debug-only');
    final clamped = value < 0 ? 0 : value;
    if (_coins == clamped) return;
    _coins = clamped;
    _scheduleSync();
    notifyListeners();
  }

  /// Debug-only: overwrites the gem balance to an absolute value.
  void debugSetGems(int value) {
    assert(kDebugMode, 'debugSetGems is debug-only');
    final clamped = value < 0 ? 0 : value;
    if (_gems == clamped) return;
    _gems = clamped;
    _scheduleSync();
    notifyListeners();
  }

  /// Resets the daily-reward calendar so the next claim starts at Day 1
  /// regardless of when the player last claimed. Used to re-test the
  /// streak ladder (especially Day 7) without waiting a full week.
  void debugResetDailyStreak() {
    assert(kDebugMode, 'debugResetDailyStreak is debug-only');
    _streakDay = 1;
    _streakWeeksCompleted = 0;
    _longestStreak = 0;
    _lastClaimDate = null;
    _scheduleSync();
    notifyListeners();
  }

  /// Wipes the active challenge cycle only (keeps `challengeRevealed`
  /// true). Long-press LAUNCH still re-fires the reveal because that
  /// path early-returns on `challengeRevealed`, so this resets that flag
  /// too.
  void debugResetChallengeCycle() {
    assert(kDebugMode, 'debugResetChallengeCycle is debug-only');
    _challengeRevealed = false;
    _activeChallengeType = null;
    _challengeStartedAt = null;
    _challengeProgress = 0;
    _challengeTarget = 0;
    _challengeStageIndex = 0;
    _challenge100ClaimedThisCycle = false;
    _scheduleSync();
    notifyListeners();
  }

  /// Wipes the entire economy back to first-launch defaults (coins,
  /// gems, level, streak, loadouts, FTUE flags, challenge, IAP records,
  /// install date). Equivalent to deleting + reinstalling the app
  /// without actually reinstalling.
  Future<void> debugHardReset() async {
    assert(kDebugMode, 'debugHardReset is debug-only');
    final defaults = EconomySnapshot.defaults();
    _coins = defaults.coins;
    _gems = defaults.gems;
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
    _adsRemoved = false;
    _packsPurchased.clear();
    _ownedJets
      ..clear()
      ..add('jet_player');
    _ownedJetSkins.clear();
    _pendingNextJetDiscountPct = 0;
    _installDate = _now();
    _activeChallengeType = null;
    _challengeStartedAt = null;
    _challengeProgress = 0;
    _challengeTarget = 0;
    _challengeStageIndex = 0;
    _challenge100ClaimedThisCycle = false;
    _challengeRevealed = false;
    _firedFtueTriggers.clear();
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
}

/// Adapter: typed [ChestDefinition] → legacy-shaped map for
/// [ChestRewardResolver] / [Day7RewardResolver] which still read raw
/// `coin_min` / `gem_max` / `jet_id` keys.
Map<String, dynamic> _chestDefAsLegacyMap(ChestDefinition def) => {
      'coin_min': def.coinMin,
      'coin_max': def.coinMax,
      'gem_min': def.gemMin,
      'gem_max': def.gemMax,
      'jet_drop_chance': def.jetDropChance,
      'jet_id': def.jetId,
    };

/// Resolves the chest-id prefix for the player's current world when a
/// challenge stage prize is `biome_chest_match`. Worlds 1–6 map to
/// jungle / desert / sea / ice / volcano / city, matching the chest
/// ids in `economy__chests__v1` (e.g. `jungle_chest`).
String _biomeChestKeyForWorld(int world) {
  const keys = ['jungle', 'desert', 'sea', 'ice', 'volcano', 'city'];
  final clamped = world.clamp(1, 6) - 1;
  return keys[clamped];
}
