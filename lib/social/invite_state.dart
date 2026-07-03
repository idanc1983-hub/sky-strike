import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/invite_config.dart';

/// Signature for crediting the invite reward. Wired by the UI to
/// [EconomyState.grantCurrencyCelebration] so balances stay backend-synced and
/// the reward flies to the top-bar holder like every other grant.
typedef GrantReward = void Function({required int coins, required int gems});

/// Signature for logging an analytics event. Wired by the UI to
/// FirebaseAnalytics. Kept as an injected callback so [InviteState] stays free
/// of Firebase and is unit-testable.
typedef LogEvent = void Function(String name, {Map<String, Object>? params});

/// Signature for presenting the OS share sheet. Defaults to [Share.share];
/// injectable so tests can drive success / failure without a platform channel.
typedef ShareFn = Future<void> Function(String text);

/// Owns the Invite Friends feature state: a daily share allowance that grants a
/// symbolic reward per share and enters a cooldown once exhausted.
///
/// All tunables come from the resolved [InviteConfig] (Remote Config); nothing
/// player-facing is hardcoded. State (`sharesUsed`, `cooldownEndsAt`) is
/// persisted to SharedPreferences and reconciled against the wall clock on
/// load, on app resume, and on every ticker tick — so a cooldown that elapses
/// while the app is backgrounded still resets correctly.
class InviteState extends ChangeNotifier with WidgetsBindingObserver {
  static const _kSharesUsed = 'invite__shares_used__v1';
  static const _kCooldownEndsAt = 'invite__cooldown_ends_at__v1';

  final InviteConfig _cfg;
  final GrantReward _onGrant;
  final LogEvent _logEvent;
  final ShareFn _shareFn;

  int sharesUsed = 0;
  DateTime? cooldownEndsAt;

  bool _isSharing = false; // in-flight guard, not persisted
  bool _loaded = false; // Share stays disabled until persisted state loads
  Timer? _ticker;

  InviteState({
    required InviteConfig config,
    required GrantReward onGrant,
    required LogEvent logEvent,
    ShareFn? shareFn,
  })  : _cfg = config,
        _onGrant = onGrant,
        _logEvent = logEvent,
        _shareFn = shareFn ?? Share.share {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  // ── Config passthroughs (single source of truth = InviteConfig) ────────────
  bool get enabled => _cfg.enabled;
  int get cap => _cfg.dailyCap;
  int get cooldownHours => _cfg.cooldownHours;
  int get rewardGems => _cfg.rewardGems;
  int get rewardCoins => _cfg.rewardCoins;

  // ── Derived ────────────────────────────────────────────────────────────────
  int get remaining {
    final r = cap - sharesUsed;
    return r < 0 ? 0 : r;
  }

  bool get isOnCooldown =>
      cooldownEndsAt != null && DateTime.now().isBefore(cooldownEndsAt!);

  bool get canShare =>
      enabled && _loaded && !_isSharing && !isOnCooldown && remaining > 0;

  Duration get cooldownLeft => isOnCooldown
      ? cooldownEndsAt!.difference(DateTime.now())
      : Duration.zero;

  // ── Persistence ─────────────────────────────────────────────────────────────
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_kSharesUsed) ?? 0;
    sharesUsed = used.clamp(0, cap);
    final ms = prefs.getInt(_kCooldownEndsAt) ?? 0;
    cooldownEndsAt =
        ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    _loaded = true;
    _reconcile(); // reset if already elapsed, else (re)start the ticker
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSharesUsed, sharesUsed);
    await prefs.setInt(
      _kCooldownEndsAt,
      cooldownEndsAt?.millisecondsSinceEpoch ?? 0,
    );
  }

  // ── Cooldown lifecycle ──────────────────────────────────────────────────────

  /// Recomputes cooldown state from the wall clock. Safe to call repeatedly
  /// (load, resume, remount): if the cooldown has already elapsed it resets
  /// immediately; if still active it ensures the ticker is running; otherwise
  /// it stops any stray ticker.
  void _reconcile() {
    if (cooldownEndsAt == null) {
      _stopTicker();
      return;
    }
    if (DateTime.now().isBefore(cooldownEndsAt!)) {
      _startTicker();
    } else {
      _completeReset();
    }
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (cooldownEndsAt == null ||
          !DateTime.now().isBefore(cooldownEndsAt!)) {
        _completeReset();
      } else {
        notifyListeners(); // live countdown
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Cooldown elapsed → refill the allowance and re-enable Share.
  void _completeReset() {
    _stopTicker();
    sharesUsed = 0;
    cooldownEndsAt = null;
    _persist();
    notifyListeners();
  }

  // ── Share flow ──────────────────────────────────────────────────────────────

  /// Presents the OS share sheet and, on successful presentation, grants the
  /// reward and decrements the daily allowance. Exactly one grant + one
  /// decrement per completed share: the [_isSharing] guard plus awaiting the
  /// share future make a double-grant impossible.
  Future<void> onSharePressed() async {
    if (!canShare) return;
    _isSharing = true;
    notifyListeners(); // disable button, block double-tap

    try {
      _logEvent('invite_share_tapped');
      // Grant on successful presentation (future completes without throwing).
      // Android does not reliably report whether the user actually sent, and
      // the reward is symbolic, so gating on completion is the right trade-off.
      await _shareFn(_cfg.shareText);

      _onGrant(coins: rewardCoins, gems: rewardGems);
      sharesUsed += 1;
      await _persist();

      if (sharesUsed >= cap) {
        cooldownEndsAt =
            DateTime.now().add(Duration(hours: cooldownHours));
        await _persist();
        _startTicker();
        _logEvent('invite_cooldown_started',
            params: {'cooldown_hours': cooldownHours});
      }

      _logEvent('invite_share_completed', params: {
        'reward_gems': rewardGems,
        'reward_coins': rewardCoins,
        'shares_used': sharesUsed,
      });
    } catch (e) {
      debugPrint('[invite] share failed: $e');
    } finally {
      _isSharing = false;
      notifyListeners();
    }
  }

  // ── Debug / QA ───────────────────────────────────────────────────────────────

  /// Forces the invite reward to "available": refills the daily allowance and
  /// clears any active cooldown so the Social badge and Share CTA can be
  /// exercised without running a full cycle. Gated by [kDebugMode]; the only
  /// caller is the kDebugMode-only Dev Tools sheet, so this is never reachable
  /// in a release build.
  void debugForceAvailable() {
    assert(kDebugMode, 'debugForceAvailable is debug-only');
    _stopTicker();
    sharesUsed = 0;
    cooldownEndsAt = null;
    _loaded = true;
    _persist();
    notifyListeners();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcile();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTicker();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
