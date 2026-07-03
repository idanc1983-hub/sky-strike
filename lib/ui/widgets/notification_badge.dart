import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Visual constants — the single source of truth for badge dimensions and
// colours. Do not scatter these numbers through the widgets below; reference
// the consts so a future palette/size tweak lands in exactly one place.
// ─────────────────────────────────────────────────────────────────────────────

const double kBadgeDotSize = 10.0; // dot diameter (logical px)
const double kBadgeBorderWidth = 1.5;
const double kBadgeCountFontSize = 9.0;
const int kBadgePulseMs = 1200; // one pulse cycle
const Color kBadgeColor = Color(0xFFE24B4A); // alert red (project palette)
const Color kBadgeBorderColor = Color(0xFF0a1a0a); // deep-green bg, for separation

/// Wraps any child icon and overlays a red alert dot at the top-right.
///
/// Generic and reusable for every notification surface (home MENU button,
/// Social nav tab, and future ones). Both current callers use PLAIN DOTS
/// ([count] == null); the numbered-pill path is implemented but unused, kept
/// for future surfaces that need a count.
///
/// When [show] is false the child is returned unchanged — no [Stack], no dot,
/// and the pulse [AnimationController] is released so a hidden badge costs
/// nothing.
class NotificationBadge extends StatefulWidget {
  /// The icon (or any widget) the dot is overlaid on.
  final Widget child;

  /// When false, renders [child] only — no dot, no animation.
  final bool show;

  /// null => plain dot; > 0 => numbered pill showing the count ("9+" above 9).
  final int? count;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.show,
    this.count,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

// TickerProviderStateMixin (not Single…) so the controller can be genuinely
// disposed when hidden and re-created when shown again — a SingleTicker mixin
// asserts one ticker for the State's whole life and would trip on re-create.
class _NotificationBadgeState extends State<NotificationBadge>
    with TickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.show) _startPulse();
  }

  @override
  void didUpdateWidget(NotificationBadge old) {
    super.didUpdateWidget(old);
    if (widget.show && _pulse == null) {
      _startPulse();
    } else if (!widget.show && _pulse != null) {
      _stopPulse();
    }
  }

  void _startPulse() {
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kBadgePulseMs),
    )..repeat(reverse: true); // 1.0 -> 1.12 -> 1.0, forever
  }

  // Releases the controller entirely while the badge is hidden — nothing
  // tickers in the background once `show` flips to false.
  void _stopPulse() {
    _pulse?.dispose();
    _pulse = null;
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No Stack overhead when hidden — the child renders exactly as it would
    // without the badge wrapper.
    if (!widget.show) return widget.child;

    final pulse = _pulse;
    Widget dot = _buildDot();
    if (pulse != null) {
      dot = ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.12).animate(
          CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
        ),
        child: dot,
      );
    }

    return Stack(
      clipBehavior: Clip.none, // let the dot bleed past the icon's box
      children: [
        widget.child,
        Positioned(top: -3, right: -3, child: dot),
      ],
    );
  }

  Widget _buildDot() {
    final count = widget.count;
    // Plain dot: a filled circle with a contrasting border so it reads
    // clearly against any icon or biome background.
    if (count == null || count <= 0) {
      return Container(
        width: kBadgeDotSize,
        height: kBadgeDotSize,
        decoration: BoxDecoration(
          color: kBadgeColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: kBadgeBorderColor,
            width: kBadgeBorderWidth,
          ),
        ),
      );
    }

    // Numbered pill (future surfaces): rounded, white bold count, "9+" above 9.
    const double minSize = kBadgeDotSize + 6;
    return Container(
      constraints: const BoxConstraints(minWidth: minSize, minHeight: minSize),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kBadgeColor,
        borderRadius: BorderRadius.circular(minSize / 2),
        border: Border.all(color: kBadgeBorderColor, width: kBadgeBorderWidth),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: kBadgeCountFontSize,
          height: 1.0,
        ),
      ),
    );
  }
}
