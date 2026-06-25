import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../economy/state/economy_state.dart';
import '../../economy/state/pending_celebration.dart';
import '../../widgets/chest_open_overlay.dart';
import 'currency_anchors.dart';

/// Observes route pushes/pops so the host can re-check for queued reward
/// celebrations when it becomes the top-most route again (e.g. after a
/// stage pops back to Home). Registered on the [MaterialApp].
final RouteObserver<PageRoute<dynamic>> rewardRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Wraps a menu screen and plays any queued [PendingCelebration]s — the
/// chest-open or fly-to-holder animation — as soon as this screen is the
/// current route. Rewards are credited at grant time; the celebration just
/// reveals the gain (see [EconomyState] display-lag).
class RewardCelebrationHost extends StatefulWidget {
  final Widget child;
  const RewardCelebrationHost({super.key, required this.child});

  @override
  State<RewardCelebrationHost> createState() => _RewardCelebrationHostState();
}

class _RewardCelebrationHostState extends State<RewardCelebrationHost>
    with RouteAware {
  EconomyState? _economy;
  bool _draining = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      rewardRouteObserver.subscribe(this, route);
    }
    final economy = context.read<EconomyState>();
    if (!identical(economy, _economy)) {
      _economy?.removeListener(_onEconomyChanged);
      _economy = economy..addListener(_onEconomyChanged);
    }
    _scheduleDrain();
  }

  @override
  void dispose() {
    rewardRouteObserver.unsubscribe(this);
    _economy?.removeListener(_onEconomyChanged);
    super.dispose();
  }

  // A reward was just queued — try to play it if we're on top.
  void _onEconomyChanged() => _scheduleDrain();

  // Returned to this route (a route above us popped).
  @override
  void didPopNext() => _scheduleDrain();

  @override
  void didPush() => _scheduleDrain();

  void _scheduleDrain() {
    if (_draining || !mounted) return;
    final economy = _economy;
    if (economy == null || !economy.hasPendingCelebration) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return; // not the top screen
    _draining = true;
    // Ask the now-visible top bar to re-publish its holder positions before
    // the fly plays, so the target reflects *this* screen's holders (not a
    // stale anchor left by the in-game result overlay or a covered route).
    CurrencyAnchors.requestRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  Future<void> _drain() async {
    final economy = _economy;
    if (economy == null) {
      _draining = false;
      return;
    }
    while (economy.hasPendingCelebration) {
      if (!mounted) break;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) break;

      final head = economy.peekCelebration();
      if (head == null) break;

      switch (head.kind) {
        case CelebrationKind.chest:
          // Won/bought chests reveal one at a time.
          final chest = economy.takeCelebration()!;
          await ChestOpenOverlay.show(
            context,
            coins: chest.coins,
            gems: chest.gems,
          );
          break;

        case CelebrationKind.challenge:
          // Handled in place on the home challenge card — never queued here.
          final stray = economy.takeCelebration();
          if (stray == null) break;
          break;

        case CelebrationKind.currency:
          // Aggregate the whole run of currency rewards into one "total" fly
          // (e.g. several cleared stages + a salvage on the trip home). The
          // take loop is synchronous, so the summed amount is always
          // released by the overlay (on land or dispose) — never stranded.
          var coins = 0;
          var gems = 0;
          while (economy.peekCelebration()?.kind == CelebrationKind.currency) {
            final c = economy.takeCelebration()!;
            coins += c.coins;
            gems += c.gems;
          }
          if (coins > 0 || gems > 0) {
            await RewardFlyOverlay.show(context, coins: coins, gems: gems);
          }
          break;
      }
    }
    _draining = false;
    // Anything queued while we were playing? Re-check.
    if (mounted) _scheduleDrain();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
