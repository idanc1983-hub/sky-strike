import 'package:flutter/widgets.dart';

/// Latest on-screen centres of the top-bar currency chips, in global
/// coordinates.
///
/// The [AppTopBar] on the *current* route reports its coin/gem chip
/// positions here on every layout; reward-fly overlays read them to target
/// the real holders. Null until a top bar has been laid out at least once —
/// callers should fall back to a geometric estimate in that case.
///
/// Only the bar on the current route publishes (others — covered routes,
/// off-screen [IndexedStack] tabs, in-game result overlays — would otherwise
/// race to overwrite these with stale positions). Before a reward fly plays,
/// the host calls [requestRefresh] so the visible bar re-publishes its
/// settled position, keeping the fly target accurate across screen
/// transitions.
class CurrencyAnchors {
  CurrencyAnchors._();

  static Offset? coin;
  static Offset? gem;

  /// Bumped to ask the currently-visible top bar to re-publish its anchors
  /// (e.g. when a screen becomes current again after a pop, or just before a
  /// queued reward fly is shown). Top-bar chips listen and re-report.
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  /// Asks the visible top bar to re-publish its chip anchors on the next
  /// frame. Safe to call any time; a no-op if no bar is mounted.
  static void requestRefresh() => refresh.value++;
}
