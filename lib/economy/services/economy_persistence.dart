import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/economy_constants.dart';
import '../state/challenge_state.dart';
import '../state/loadout.dart';

/// Snapshot of all persisted economy fields. Returned by [load] and
/// consumed by [EconomyState.restore]. Per-session-only fields
/// (`pickupQueue`, `stageRevivesUsed`) are not part of this record.
class EconomySnapshot {
  final int coins;
  final int gems;
  final int xp;
  final int xpMax;
  final int level;
  final int currentWorld;
  final int maxWorldReached;
  final Map<String, int> powerUpInventory;
  final int unlockedLoadoutSlots;
  final List<Loadout> loadouts;
  final int activeLoadoutIndex;
  final int streakDay;
  final int streakWeeksCompleted;
  final int longestStreak;
  final DateTime? lastClaimDate;
  final int dailyAdWatchCount;
  final DateTime? dailyAdWatchDate;
  final Set<String> completedStages;
  final Set<String> threeStarStages;
  final Set<String> defeatedBosses;
  final bool adsRemoved;
  final Set<String> packsPurchased;
  final DateTime? installDate;
  final int pendingNextJetDiscountPct;

  // v1.3 additions — Challenge System + Ace + FTUE
  final ChallengeType? activeChallengeType;
  final DateTime? challengeStartedAt;
  final int challengeProgress;
  final int challengeTarget;
  final bool challenge50Claimed;
  final bool challenge100Claimed;
  final bool challengeRevealed;
  final bool aceDialogueEnabled;
  final Set<String> firedFtueTriggers;
  final Set<String> shownAceLines;

  const EconomySnapshot({
    required this.coins,
    required this.gems,
    required this.xp,
    required this.xpMax,
    required this.level,
    required this.currentWorld,
    required this.maxWorldReached,
    required this.powerUpInventory,
    required this.unlockedLoadoutSlots,
    required this.loadouts,
    required this.activeLoadoutIndex,
    required this.streakDay,
    required this.streakWeeksCompleted,
    required this.longestStreak,
    required this.lastClaimDate,
    required this.dailyAdWatchCount,
    required this.dailyAdWatchDate,
    required this.completedStages,
    required this.threeStarStages,
    required this.defeatedBosses,
    required this.adsRemoved,
    required this.packsPurchased,
    required this.installDate,
    required this.pendingNextJetDiscountPct,
    required this.activeChallengeType,
    required this.challengeStartedAt,
    required this.challengeProgress,
    required this.challengeTarget,
    required this.challenge50Claimed,
    required this.challenge100Claimed,
    required this.challengeRevealed,
    required this.aceDialogueEnabled,
    required this.firedFtueTriggers,
    required this.shownAceLines,
  });

  /// Brand-new player defaults — used when SharedPreferences has no
  /// existing economy keys.
  factory EconomySnapshot.defaults() {
    return EconomySnapshot(
      coins: 0,
      gems: 0,
      xp: 0,
      xpMax: 1000,
      level: 1,
      currentWorld: 1,
      maxWorldReached: 1,
      powerUpInventory: const <String, int>{},
      unlockedLoadoutSlots: EconomyConstants.defaultUnlockedLoadoutSlots,
      loadouts: List<Loadout>.generate(
        EconomyConstants.maxLoadoutSlots,
        Loadout.defaultFor,
      ),
      activeLoadoutIndex: 0,
      streakDay: 1,
      streakWeeksCompleted: 0,
      longestStreak: 0,
      lastClaimDate: null,
      dailyAdWatchCount: 0,
      dailyAdWatchDate: null,
      completedStages: <String>{},
      threeStarStages: <String>{},
      defeatedBosses: <String>{},
      adsRemoved: false,
      packsPurchased: <String>{},
      installDate: null,
      pendingNextJetDiscountPct: 0,
      activeChallengeType: null,
      challengeStartedAt: null,
      challengeProgress: 0,
      challengeTarget: 0,
      challenge50Claimed: false,
      challenge100Claimed: false,
      challengeRevealed: false,
      aceDialogueEnabled: true,
      firedFtueTriggers: <String>{},
      shownAceLines: <String>{},
    );
  }
}

/// Hard caps applied to numeric fields on load + save. Modded save files
/// or platform-specific corruption can produce values that overflow when
/// arithmetic runs against them; clamping at the boundary keeps the
/// runtime predictable. Caps are intentionally generous so legitimate
/// long-term play is never affected.
class _Caps {
  static const int coinMax = 1 << 31; // ~2.1B coins — well past whales
  static const int gemMax = 1 << 24; // ~16.7M gems
  static const int xpMax = 1 << 30;
  static const int xpMaxCap = 1 << 30;
  static const int levelMax = 999;
  static const int worldMin = 1;
  static const int worldMax = 6;
  static const int streakDayMin = 1;
  static const int streakDayMax = 7;
  static const int streakWeeksMax = 1 << 16; // 65k weeks ≈ 1250 years
  static const int longestStreakMax = streakWeeksMax * 7 + streakDayMax;
  static const int dailyAdMax = 1 << 16;
  static const int discountPctMax = 100;
  static const int challengeMax = 1 << 30;
  static const int powerUpInventoryMax = 1 << 16; // 65k of any one type
}

int _clampInt(int? raw, int min, int max, int fallback) {
  if (raw == null) return fallback;
  if (raw < min) return min;
  if (raw > max) return max;
  return raw;
}

/// SharedPreferences load/save layer.
///
/// Persists the entire economy snapshot as a single JSON blob under one
/// key. Single-key writes are atomic at the SharedPreferences layer
/// (one platform-side write call), avoiding the torn-write problem that
/// per-field writes had — an app-kill mid-save cannot leave a state
/// where coins reflect the new value but the challenge flags are stale.
///
/// Legacy per-field keys are read transparently as a fallback the first
/// time a v1.2-era client upgrades, then removed after the JSON blob is
/// written successfully.
class EconomyPersistence {
  // Single-blob key (current).
  static const _kBlob = 'ss_state_v1';

  // Legacy per-field keys (read-only — left in place so an upgrade from
  // a pre-blob install reads the old fields once, after which the blob
  // is written and these keys removed).
  static const _kCoins = 'ss_coins';
  static const _kGems = 'ss_gems';
  static const _kXp = 'ss_xp';
  static const _kXpMax = 'ss_xpMax';
  static const _kLevel = 'ss_level';
  static const _kCurrentWorld = 'ss_currentWorld';
  static const _kMaxWorldReached = 'ss_maxWorldReached';
  static const _kPowerUpInventory = 'ss_powerUpInventory';
  static const _kUnlockedLoadoutSlots = 'ss_unlockedLoadoutSlots';
  static const _kLoadouts = 'ss_loadouts';
  static const _kActiveLoadoutIndex = 'ss_activeLoadoutIndex';
  static const _kStreakDay = 'ss_streakDay';
  static const _kStreakWeeksCompleted = 'ss_streakWeeksCompleted';
  static const _kLongestStreak = 'ss_longestStreak';
  static const _kLastClaimDate = 'ss_lastClaimDate';
  static const _kDailyAdWatchCount = 'ss_dailyAdWatchCount';
  static const _kDailyAdWatchDate = 'ss_dailyAdWatchDate';
  static const _kCompletedStages = 'ss_completedStages';
  static const _k3StarStages = 'ss_3starStages';
  static const _kDefeatedBosses = 'ss_defeatedBosses';
  static const _kAdsRemoved = 'ss_adsRemoved';
  static const _kPacksPurchased = 'ss_packsPurchased';
  static const _kInstallDate = 'ss_installDate';
  static const _kActiveChallengeType = 'ss_activeChallengeType';
  static const _kChallengeStartedAt = 'ss_challengeStartedAt';
  static const _kChallengeProgress = 'ss_challengeProgress';
  static const _kChallengeTarget = 'ss_challengeTarget';
  static const _kChallenge50Claimed = 'ss_challenge50Claimed';
  static const _kChallenge100Claimed = 'ss_challenge100Claimed';
  static const _kChallengeRevealed = 'ss_challengeRevealed';
  static const _kAceDialogueEnabled = 'ss_aceDialogueEnabled';
  static const _kFiredFtueTriggers = 'ss_firedFtueTriggers';
  static const _kShownAceLines = 'ss_shownAceLines';

  /// Loads the persisted snapshot from disk. Returns
  /// [EconomySnapshot.defaults] when no economy keys are present.
  Future<EconomySnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final blob = prefs.getString(_kBlob);
    if (blob != null) {
      final parsed = _parseBlob(blob);
      if (parsed != null) return parsed;
      // Corrupted blob — fall through to defaults rather than crash.
      return EconomySnapshot.defaults();
    }
    if (!prefs.containsKey(_kCoins) && !prefs.containsKey(_kInstallDate)) {
      return EconomySnapshot.defaults();
    }
    return _loadLegacy(prefs);
  }

  EconomySnapshot? _parseBlob(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return _validate(EconomySnapshot(
        coins: _readInt(decoded['coins']) ?? 0,
        gems: _readInt(decoded['gems']) ?? 0,
        xp: _readInt(decoded['xp']) ?? 0,
        xpMax: _readInt(decoded['xpMax']) ?? 1000,
        level: _readInt(decoded['level']) ?? 1,
        currentWorld: _readInt(decoded['currentWorld']) ?? 1,
        maxWorldReached: _readInt(decoded['maxWorldReached']) ?? 1,
        powerUpInventory: _decodeIntMapDynamic(decoded['powerUpInventory']),
        unlockedLoadoutSlots: _readInt(decoded['unlockedLoadoutSlots']) ??
            EconomyConstants.defaultUnlockedLoadoutSlots,
        loadouts:
            _decodeLoadoutsDynamic(decoded['loadouts']) ?? _defaultLoadouts(),
        activeLoadoutIndex: _readInt(decoded['activeLoadoutIndex']) ?? 0,
        streakDay: _readInt(decoded['streakDay']) ?? 1,
        streakWeeksCompleted:
            _readInt(decoded['streakWeeksCompleted']) ?? 0,
        longestStreak: _readInt(decoded['longestStreak']) ?? 0,
        lastClaimDate: _readDate(decoded['lastClaimDate']),
        dailyAdWatchCount: _readInt(decoded['dailyAdWatchCount']) ?? 0,
        dailyAdWatchDate: _readDate(decoded['dailyAdWatchDate']),
        completedStages: _decodeStringSetDynamic(decoded['completedStages']),
        threeStarStages: _decodeStringSetDynamic(decoded['threeStarStages']),
        defeatedBosses: _decodeStringSetDynamic(decoded['defeatedBosses']),
        adsRemoved: decoded['adsRemoved'] == true,
        packsPurchased: _decodeStringSetDynamic(decoded['packsPurchased']),
        installDate: _readDate(decoded['installDate']),
        pendingNextJetDiscountPct:
            _readInt(decoded['pendingNextJetDiscountPct']) ?? 0,
        activeChallengeType: ChallengeTypeJson.fromJsonValue(
          decoded['activeChallengeType'] as String?,
        ),
        challengeStartedAt: _readDate(decoded['challengeStartedAt']),
        challengeProgress: _readInt(decoded['challengeProgress']) ?? 0,
        challengeTarget: _readInt(decoded['challengeTarget']) ?? 0,
        challenge50Claimed: decoded['challenge50Claimed'] == true,
        challenge100Claimed: decoded['challenge100Claimed'] == true,
        challengeRevealed: decoded['challengeRevealed'] == true,
        aceDialogueEnabled: decoded['aceDialogueEnabled'] != false,
        firedFtueTriggers:
            _decodeStringSetDynamic(decoded['firedFtueTriggers']),
        shownAceLines: _decodeStringSetDynamic(decoded['shownAceLines']),
      ));
    } catch (_) {
      return null;
    }
  }

  EconomySnapshot _loadLegacy(SharedPreferences prefs) {
    return _validate(EconomySnapshot(
      coins: prefs.getInt(_kCoins) ?? 0,
      gems: prefs.getInt(_kGems) ?? 0,
      xp: prefs.getInt(_kXp) ?? 0,
      xpMax: prefs.getInt(_kXpMax) ?? 1000,
      level: prefs.getInt(_kLevel) ?? 1,
      currentWorld: prefs.getInt(_kCurrentWorld) ?? 1,
      maxWorldReached: prefs.getInt(_kMaxWorldReached) ?? 1,
      powerUpInventory: _decodeIntMap(prefs.getString(_kPowerUpInventory)),
      unlockedLoadoutSlots: prefs.getInt(_kUnlockedLoadoutSlots) ??
          EconomyConstants.defaultUnlockedLoadoutSlots,
      loadouts:
          _decodeLoadouts(prefs.getString(_kLoadouts)) ?? _defaultLoadouts(),
      activeLoadoutIndex: prefs.getInt(_kActiveLoadoutIndex) ?? 0,
      streakDay: prefs.getInt(_kStreakDay) ?? 1,
      streakWeeksCompleted: prefs.getInt(_kStreakWeeksCompleted) ?? 0,
      longestStreak: prefs.getInt(_kLongestStreak) ?? 0,
      lastClaimDate: _decodeDate(prefs.getString(_kLastClaimDate)),
      dailyAdWatchCount: prefs.getInt(_kDailyAdWatchCount) ?? 0,
      dailyAdWatchDate: _decodeDate(prefs.getString(_kDailyAdWatchDate)),
      completedStages: _decodeStringSet(prefs.getString(_kCompletedStages)),
      threeStarStages: _decodeStringSet(prefs.getString(_k3StarStages)),
      defeatedBosses: _decodeStringSet(prefs.getString(_kDefeatedBosses)),
      adsRemoved: prefs.getBool(_kAdsRemoved) ?? false,
      packsPurchased: _decodeStringSet(prefs.getString(_kPacksPurchased)),
      installDate: _decodeDate(prefs.getString(_kInstallDate)),
      pendingNextJetDiscountPct: 0,
      activeChallengeType: ChallengeTypeJson.fromJsonValue(
        prefs.getString(_kActiveChallengeType),
      ),
      challengeStartedAt: _decodeDate(prefs.getString(_kChallengeStartedAt)),
      challengeProgress: prefs.getInt(_kChallengeProgress) ?? 0,
      challengeTarget: prefs.getInt(_kChallengeTarget) ?? 0,
      challenge50Claimed: prefs.getBool(_kChallenge50Claimed) ?? false,
      challenge100Claimed: prefs.getBool(_kChallenge100Claimed) ?? false,
      challengeRevealed: prefs.getBool(_kChallengeRevealed) ?? false,
      aceDialogueEnabled: prefs.getBool(_kAceDialogueEnabled) ?? true,
      firedFtueTriggers: _decodeStringSet(prefs.getString(_kFiredFtueTriggers)),
      shownAceLines: _decodeStringSet(prefs.getString(_kShownAceLines)),
    ));
  }

  /// Atomically writes [snapshot] to disk as a single JSON blob.
  Future<void> save(EconomySnapshot snapshot) async {
    final clamped = _validate(snapshot);
    final prefs = await SharedPreferences.getInstance();
    final payload = json.encode(_encode(clamped));
    await prefs.setString(_kBlob, payload);

    // Best-effort cleanup of legacy keys (only on the first save after
    // upgrade — once removed they stay removed).
    if (prefs.containsKey(_kCoins)) {
      for (final k in _legacyKeys) {
        await prefs.remove(k);
      }
    }
  }

  Map<String, dynamic> _encode(EconomySnapshot s) {
    return <String, dynamic>{
      'version': 1,
      'coins': s.coins,
      'gems': s.gems,
      'xp': s.xp,
      'xpMax': s.xpMax,
      'level': s.level,
      'currentWorld': s.currentWorld,
      'maxWorldReached': s.maxWorldReached,
      'powerUpInventory': s.powerUpInventory,
      'unlockedLoadoutSlots': s.unlockedLoadoutSlots,
      'loadouts': s.loadouts.map((l) => l.toJson()).toList(),
      'activeLoadoutIndex': s.activeLoadoutIndex,
      'streakDay': s.streakDay,
      'streakWeeksCompleted': s.streakWeeksCompleted,
      'longestStreak': s.longestStreak,
      'lastClaimDate': s.lastClaimDate?.toIso8601String(),
      'dailyAdWatchCount': s.dailyAdWatchCount,
      'dailyAdWatchDate': s.dailyAdWatchDate?.toIso8601String(),
      'completedStages': s.completedStages.toList(),
      'threeStarStages': s.threeStarStages.toList(),
      'defeatedBosses': s.defeatedBosses.toList(),
      'adsRemoved': s.adsRemoved,
      'packsPurchased': s.packsPurchased.toList(),
      'installDate': s.installDate?.toIso8601String(),
      'pendingNextJetDiscountPct': s.pendingNextJetDiscountPct,
      'activeChallengeType': s.activeChallengeType?.jsonValue,
      'challengeStartedAt': s.challengeStartedAt?.toIso8601String(),
      'challengeProgress': s.challengeProgress,
      'challengeTarget': s.challengeTarget,
      'challenge50Claimed': s.challenge50Claimed,
      'challenge100Claimed': s.challenge100Claimed,
      'challengeRevealed': s.challengeRevealed,
      'aceDialogueEnabled': s.aceDialogueEnabled,
      'firedFtueTriggers': s.firedFtueTriggers.toList(),
      'shownAceLines': s.shownAceLines.toList(),
    };
  }

  EconomySnapshot _validate(EconomySnapshot s) {
    final unlocked = _clampInt(
      s.unlockedLoadoutSlots,
      EconomyConstants.defaultUnlockedLoadoutSlots,
      EconomyConstants.maxLoadoutSlots,
      EconomyConstants.defaultUnlockedLoadoutSlots,
    );
    final activeLoadout = _clampInt(s.activeLoadoutIndex, 0, unlocked - 1, 0);

    final cleanedInv = <String, int>{};
    s.powerUpInventory.forEach((k, v) {
      if (k.isEmpty) return;
      cleanedInv[k] = _clampInt(v, 0, _Caps.powerUpInventoryMax, 0);
    });

    return EconomySnapshot(
      coins: _clampInt(s.coins, 0, _Caps.coinMax, 0),
      gems: _clampInt(s.gems, 0, _Caps.gemMax, 0),
      xp: _clampInt(s.xp, 0, _Caps.xpMax, 0),
      xpMax: max(
        1,
        _clampInt(s.xpMax, 1, _Caps.xpMaxCap, 1000),
      ),
      level: _clampInt(s.level, 1, _Caps.levelMax, 1),
      currentWorld: _clampInt(s.currentWorld, _Caps.worldMin, _Caps.worldMax, 1),
      maxWorldReached:
          _clampInt(s.maxWorldReached, _Caps.worldMin, _Caps.worldMax, 1),
      powerUpInventory: cleanedInv,
      unlockedLoadoutSlots: unlocked,
      loadouts: s.loadouts,
      activeLoadoutIndex: activeLoadout,
      streakDay: _clampInt(
        s.streakDay,
        _Caps.streakDayMin,
        _Caps.streakDayMax,
        1,
      ),
      streakWeeksCompleted:
          _clampInt(s.streakWeeksCompleted, 0, _Caps.streakWeeksMax, 0),
      longestStreak:
          _clampInt(s.longestStreak, 0, _Caps.longestStreakMax, 0),
      lastClaimDate: s.lastClaimDate,
      dailyAdWatchCount: _clampInt(s.dailyAdWatchCount, 0, _Caps.dailyAdMax, 0),
      dailyAdWatchDate: s.dailyAdWatchDate,
      completedStages: s.completedStages,
      threeStarStages: s.threeStarStages,
      defeatedBosses: s.defeatedBosses,
      adsRemoved: s.adsRemoved,
      packsPurchased: s.packsPurchased,
      installDate: s.installDate,
      pendingNextJetDiscountPct: _clampInt(
        s.pendingNextJetDiscountPct,
        0,
        _Caps.discountPctMax,
        0,
      ),
      activeChallengeType: s.activeChallengeType,
      challengeStartedAt: s.challengeStartedAt,
      challengeProgress:
          _clampInt(s.challengeProgress, 0, _Caps.challengeMax, 0),
      challengeTarget: _clampInt(s.challengeTarget, 0, _Caps.challengeMax, 0),
      challenge50Claimed: s.challenge50Claimed,
      challenge100Claimed: s.challenge100Claimed,
      challengeRevealed: s.challengeRevealed,
      aceDialogueEnabled: s.aceDialogueEnabled,
      firedFtueTriggers: s.firedFtueTriggers,
      shownAceLines: s.shownAceLines,
    );
  }

  // ---------------------------------------------------------------------------
  // Decoders — each tolerates `Map<dynamic, dynamic>` etc. that some
  // platforms produce after a JSON round-trip across native bridges.
  // ---------------------------------------------------------------------------

  int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  DateTime? _readDate(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Map<String, int> _decodeIntMap(String? raw) {
    if (raw == null) return <String, int>{};
    try {
      return _decodeIntMapDynamic(json.decode(raw));
    } catch (_) {
      return <String, int>{};
    }
  }

  Map<String, int> _decodeIntMapDynamic(dynamic decoded) {
    if (decoded is! Map) return <String, int>{};
    final out = <String, int>{};
    decoded.forEach((k, v) {
      if (k is! String) return;
      final n = _readInt(v);
      if (n != null) out[k] = n;
    });
    return out;
  }

  List<Loadout>? _decodeLoadouts(String? raw) {
    if (raw == null) return null;
    try {
      return _decodeLoadoutsDynamic(json.decode(raw));
    } catch (_) {
      return null;
    }
  }

  List<Loadout>? _decodeLoadoutsDynamic(dynamic decoded) {
    if (decoded is! List) return null;
    final out = <Loadout>[];
    for (final item in decoded) {
      if (item is Map) {
        out.add(Loadout.fromJson(_normalizeMap(item)));
      }
    }
    return out;
  }

  Set<String> _decodeStringSet(String? raw) {
    if (raw == null) return <String>{};
    try {
      return _decodeStringSetDynamic(json.decode(raw));
    } catch (_) {
      return <String>{};
    }
  }

  Set<String> _decodeStringSetDynamic(dynamic decoded) {
    if (decoded is! List) return <String>{};
    return decoded.whereType<String>().toSet();
  }

  DateTime? _decodeDate(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Some native bridges produce `Map<dynamic, dynamic>` instead of
  /// `Map<String, dynamic>`. Renormalize so downstream `as String?` casts
  /// don't fail.
  Map<String, dynamic> _normalizeMap(Map raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (k is String) out[k] = v;
    });
    return out;
  }

  List<Loadout> _defaultLoadouts() => List<Loadout>.generate(
        EconomyConstants.maxLoadoutSlots,
        Loadout.defaultFor,
      );

  static const List<String> _legacyKeys = <String>[
    _kCoins, _kGems, _kXp, _kXpMax, _kLevel,
    _kCurrentWorld, _kMaxWorldReached, _kPowerUpInventory,
    _kUnlockedLoadoutSlots, _kLoadouts, _kActiveLoadoutIndex,
    _kStreakDay, _kStreakWeeksCompleted, _kLongestStreak,
    _kLastClaimDate, _kDailyAdWatchCount, _kDailyAdWatchDate,
    _kCompletedStages, _k3StarStages, _kDefeatedBosses,
    _kAdsRemoved, _kPacksPurchased, _kInstallDate,
    _kActiveChallengeType, _kChallengeStartedAt, _kChallengeProgress,
    _kChallengeTarget, _kChallenge50Claimed, _kChallenge100Claimed,
    _kChallengeRevealed, _kAceDialogueEnabled,
    _kFiredFtueTriggers, _kShownAceLines,
  ];

  /// Wipes every economy key. Used in tests; not exposed to players.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBlob);
    for (final k in _legacyKeys) {
      await prefs.remove(k);
    }
  }
}
