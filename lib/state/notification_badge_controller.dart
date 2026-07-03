import 'package:flutter/widgets.dart';

import '../config/remote_config_service.dart';
import '../economy/state/economy_state.dart';
import '../social/invite_state.dart';

/// Observes the two existing reward sources and exposes derived, read-only
/// badge visibility. Owns NO persistence of its own — each getter reads the
/// single source of truth that already persists and resets on its own
/// schedule, so "persist until claimed", "clear on claim", and "reappear next
/// cycle" all come for free.
///
///   MENU badge visible   == daily-gift reward available AND not claimed today
///   SOCIAL badge visible == invite reward available AND not claimed this cycle
///
/// A Remote Config kill-switch gates each badge so it can be disabled live
/// without a client update.
class NotificationBadgeController extends ChangeNotifier
    with WidgetsBindingObserver {
  final EconomyState _economy;
  final InviteState _invite;
  final RemoteConfigService _remote;

  NotificationBadgeController({
    required EconomyState economy,
    required InviteState invite,
    RemoteConfigService? remote,
  })  : _economy = economy,
        _invite = invite,
        _remote = remote ?? RemoteConfigService.I {
    _economy.addListener(_onSourceChanged);
    _invite.addListener(_onSourceChanged);
    // A new calendar day can make the daily gift available again while the app
    // was backgrounded. EconomyState.onAppForeground already notifies on
    // resume, but re-evaluating here too keeps the badge correct even if that
    // path is ever changed.
    WidgetsBinding.instance.addObserver(this);
  }

  /// True when the home MENU badge should show: the daily-gift reward is
  /// available and unclaimed today, and the RC kill-switch is on.
  bool get showMenuBadge =>
      _remote.dailyRewardBadgeEnabled && _economy.canClaimStreakToday;

  /// True when the Social nav badge should show: the invite reward is
  /// available this cycle, and the RC kill-switch is on.
  bool get showSocialBadge =>
      _remote.inviteRewardBadgeEnabled && _invite.canShare;

  void _onSourceChanged() => notifyListeners();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) notifyListeners();
  }

  @override
  void dispose() {
    _economy.removeListener(_onSourceChanged);
    _invite.removeListener(_onSourceChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
