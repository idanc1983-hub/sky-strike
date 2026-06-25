import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/remote_config_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../services/challenge_prize_parser.dart';
import '../state/challenge_state.dart';
import '../state/economy_state.dart';
import 'chest_contents_popup.dart';
import 'chest_info_badge.dart';

/// Popup launched by tapping the home-screen challenge card.
///
/// Renders the active cycle's reward ladder over a full-bleed cycle
/// background. The player sees the current stage (progress bar + prize +
/// countdown) at the bottom and 4 locked stages stacked above: the next 3
/// sequential stages, with the cycle's final stage (the grand prize)
/// always pinned at the top. This guarantees the grand prize is visible
/// from stage 1 so players grasp what they're climbing toward.
///
/// Title + popup background are resolved from the cycle's entry in
/// `challenges_config` RC (`display_name`, `popup_bg`). `popup_bg` accepts
/// either a bundled asset path (default) or an absolute http(s) URL —
/// LiveOps can swap title/art without a client release.
class ChallengePrizesPopup extends StatefulWidget {
  const ChallengePrizesPopup({super.key});

  /// Entry tuned to the Figma spec (smart-animate, ease-out, 300ms).
  /// Exit is intentionally shorter (220ms ease-in) so dismissal feels
  /// snappy — matches iOS/Material modal conventions.
  /// Total entry timeline. Split into two beats:
  ///   • 0.0 – 0.4 : chrome (bg + title + X + active card) fades in
  ///   • 0.4 – 1.0 : locked-stage rows emerge upward from behind the
  ///                 active card, staggered nearest-first
  /// See [_ChromeReveal] and [_StaggeredRowReveal] for the per-element
  /// intervals + curves.
  static const Duration _entryDuration = Duration(milliseconds: 800);
  static const Duration _exitDuration = Duration(milliseconds: 260);

  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        barrierDismissible: false,
        barrierLabel: 'ChallengePrizes',
        transitionDuration: _entryDuration,
        reverseTransitionDuration: _exitDuration,
        pageBuilder: (_, __, ___) => const ChallengePrizesPopup(),
        transitionsBuilder: (ctx, anim, secondary, child) {
          return _AnimatedSheet(animation: anim, child: child);
        },
      ),
    );
  }

  @override
  State<ChallengePrizesPopup> createState() => _ChallengePrizesPopupState();
}

class _ChallengePrizesPopupState extends State<ChallengePrizesPopup> {
  Timer? _ticker;

  /// Number of *locked* (future) stage rows rendered above the active
  /// card: 3 sequential next stages + 1 grand-prize row pinned on top
  /// (4 total). Keeps the early-game prizes close to the player while
  /// always showing the cycle's final reward as the visible end-goal.
  static const int _sequentialNextRows = 3;

  static const String _placeholderCycleName = 'Iron Skies';

  /// Used when RC has no stage ladder for the active cycle. Each entry's
  /// `goal` is the cumulative point threshold for that stage; `prize` uses
  /// the same syntax accepted by [parseChallengePrize].
  static const List<Map<String, dynamic>> _placeholderStages = [
    {'stage': 1, 'goal': 350, 'prize': '300coin'},
    {'stage': 2, 'goal': 700, 'prize': '20gem'},
    {'stage': 3, 'goal': 1400, 'prize': '500coin'},
    {'stage': 4, 'goal': 2000, 'prize': 'rare_chest'},
    {'stage': 5, 'goal': 3000, 'prize': '800coin'},
    {'stage': 6, 'goal': 7000, 'prize': 'operation_chest'},
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final view = economy.challengeView;
    final type = view?.type ?? ChallengeType.hunter;
    final remaining =
        view?.remainingFrom(DateTime.now()) ?? const Duration(hours: 72);
    final progress = view?.progress ?? 0;
    // Unit label swaps "pts" for the active cycle's RC metric so each
    // type reads in its own currency (kills / survives / score / stars).
    final metricLabel = view?.metricLabel ?? 'pts';

    final stages = _stagesFor(economy);
    // Trust EconomyState's persisted stage index — it advances exactly
    // when the gameplay loop grants a stage prize, so the popup never
    // has to derive it from `progress` alone (which the non-monotonic
    // RC goals make impossible). Clamped here only to defend against a
    // shorter ladder loaded after a save was written for a longer one.
    final currentIdx =
        (view?.stageIndex ?? 0).clamp(0, stages.length - 1).toInt();
    final activeStage = stages[currentIdx];
    final lockedToShow = _lockedRowsToShow(stages, currentIdx);

    final rcConfig = RemoteConfigService.I.challengeById(type.jsonValue);
    final titleFromRc = rcConfig?.displayName ?? '';
    final title = titleFromRc.isEmpty ? type.displayName : titleFromRc;
    final bgPath = rcConfig?.popupBg ?? _fallbackBgFor(type);

    // The route's forward/reverse animation drives the staggered row
    // reveal. Falls back to a no-op completed animation if the popup is
    // ever shown outside a route (e.g. embedded in a preview/test).
    final routeAnim =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Stack(
        children: [
          Positioned.fill(child: _CycleBackground(path: bgPath)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderRow(
                    title: title,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(flex: 1),
                  // Locked future stages + active card render as a single
                  // visually-grouped block centered vertically below the
                  // title. The reference design relies on plenty of bg
                  // breathing room above and below — pinning the block to
                  // top/bottom would lose the cycle art.
                  //
                  // Each row is wrapped in _StaggeredRowReveal so they
                  // emerge upward from behind the active card on entry
                  // (nearest-first). Painted before the active card in
                  // the Column so the card visually masks them during
                  // their slide-up. See _StaggeredRowReveal for timing.
                  for (int i = 0; i < lockedToShow.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StaggeredRowReveal(
                        animation: routeAnim,
                        fromBottom: lockedToShow.length - 1 - i,
                        total: lockedToShow.length,
                        child: _LockedStageRow(
                          stage: lockedToShow[i],
                          unitLabel: metricLabel,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  // Reserve 18pt at the bottom inside the Stack so the
                  // info button's overhang sits within the Stack's hit-test
                  // rect. Without this, taps in the overhanging area fall
                  // through to whatever is painted below.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _ActiveStageCard(
                          title: title,
                          stage: activeStage,
                          progress: progress,
                          fallbackTitle: _placeholderCycleName,
                          remaining: remaining,
                          unitLabel: metricLabel,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: 0,
                        child: _GoalInfoButton(
                          challengeType: type,
                          title: title,
                        ),
                      ),
                    ],
                  ),
                  // Fixed bottom dock so the active card lands at exactly
                  // the same screen-Y as the home-screen challenge card,
                  // which lets the player read the popup as "the card
                  // stayed put while the ladder appeared above it" (the
                  // Figma smart-animate intent).
                  //
                  // Offset budget mirrors main_shell + home screen chrome:
                  //   bottom nav (78) + SizedBox(8) + CTA (60) + gap (48)
                  //   = 194pt above safe-area bottom
                  //   − the popup's own bottom padding (14)
                  //   = 180pt SizedBox here.
                  // Recompute if any of those constants change.
                  const SizedBox(height: 180),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Data resolution
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _stagesFor(EconomyState economy) {
    final rc = economy.activeChallengeStages;
    return rc.isEmpty ? _placeholderStages : rc;
  }

  /// Builds the locked-row list shown above the active card, ordered
  /// top→bottom (grand prize first, nearest-next last):
  ///
  ///   • Up to `_sequentialNextRows` (3) of the next sequential stages
  ///     immediately after `currentIdx` — the close-range goals.
  ///   • The cycle's final stage as the grand prize, pinned on top.
  ///     If the grand prize is already inside the sequential window
  ///     (i.e. the player is near the end of the ladder), it isn't
  ///     duplicated.
  ///
  /// When the player IS on the final stage, no locked rows render
  /// (the active card already shows the grand prize).
  List<Map<String, dynamic>> _lockedRowsToShow(
    List<Map<String, dynamic>> stages,
    int currentIdx,
  ) {
    if (stages.isEmpty || currentIdx >= stages.length - 1) {
      return const [];
    }
    final lastIdx = stages.length - 1;
    final sequentialEnd =
        (currentIdx + _sequentialNextRows).clamp(currentIdx, lastIdx - 1);
    final sequentialAsc = stages.sublist(currentIdx + 1, sequentialEnd + 1);
    final grandPrize = stages[lastIdx];
    final grandInSequential = sequentialAsc.any(
      (s) => (s['stage'] as num?)?.toInt() ==
          (grandPrize['stage'] as num?)?.toInt(),
    );
    // Top → bottom: grand prize first, then sequential rows in reverse
    // (so the row nearest to the active card is the next stage).
    return [
      if (!grandInSequential) grandPrize,
      ...sequentialAsc.reversed,
    ];
  }

  /// Used when RC has no `popup_bg` entry for the cycle — keeps the popup
  /// renderable in dev / offline before LiveOps populates the field.
  String _fallbackBgFor(ChallengeType type) {
    return 'assets/ui/challenges/bg_${type.jsonValue}.png';
  }
}

// ---------------------------------------------------------------------------
// Outer transition — fades the whole popup in/out. The internal
// `_StaggeredRowReveal` handles the locked-row choreography on top of
// this, so the chrome (background, header, active card) lands first and
// the ladder rises out from behind the active card as a second beat.
// ---------------------------------------------------------------------------
class _AnimatedSheet extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedSheet({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    // Chrome fade-in occupies the first 40% of the 800ms entry timeline
    // (≈320ms). The remaining 60% is reserved for the staggered row
    // reveal further down the tree. On reverse (260ms total close), the
    // full range fades — see Interval bounds.
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeInCubic),
    );
    return FadeTransition(opacity: fade, child: child);
  }
}

// ---------------------------------------------------------------------------
// Staggered locked-row reveal — each row slides up from behind the
// active card and fades in, nearest-first ("dealing cards from a deck").
// Tied to the route animation so the reverse plays cleanly on dismiss.
// ---------------------------------------------------------------------------
class _StaggeredRowReveal extends StatelessWidget {
  final Animation<double> animation;

  /// 0 = bottom row (nearest the active card); reveals first.
  /// `total - 1` = top row (furthest goal); reveals last.
  final int fromBottom;
  final int total;
  final Widget child;

  const _StaggeredRowReveal({
    required this.animation,
    required this.fromBottom,
    required this.total,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Reveal window on the route timeline: chrome finishes at 0.40; rows
    // animate between 0.40 and 1.00. Each row's own travel takes ~0.35
    // of the timeline (≈280ms of 800ms) so motion reads as deliberate
    // rather than a flicker.
    const chromeEnd = 0.40;
    const revealEnd = 1.00;
    const rowDuration = 0.35;
    final stagger = total > 1
        ? (revealEnd - chromeEnd - rowDuration) / (total - 1)
        : 0.0;
    final start = chromeEnd + fromBottom * stagger;
    final end = (start + rowDuration).clamp(0.0, 1.0);

    final curve = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
      reverseCurve: Interval(start, end, curve: Curves.easeInCubic),
    );

    // Begin offset is expressed in row-height units. 1.18 accounts for
    // the 10px inter-row gap on top of the 56px row height — picks the
    // travel distance that lands each row's start position exactly at
    // the active card's top edge so they emerge from behind it rather
    // than from a position the player can already see.
    const rowHeightUnits = 1.18;
    final slideY = (fromBottom + 1) * rowHeightUnits;

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, slideY),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background — handles both bundled assets and remote URLs so LiveOps can
// swap art without shipping a client build.
// ---------------------------------------------------------------------------
class _CycleBackground extends StatelessWidget {
  final String path;
  const _CycleBackground({required this.path});

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    final errorBuilder = AssetPlaceholder.image(
      color: AppColors.cardBg,
      label: 'cycle_bg',
      borderRadius: 0,
    );
    return isNetwork
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: errorBuilder,
          )
        : Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: errorBuilder,
          );
  }
}

// ---------------------------------------------------------------------------
// Header — X (top-left) + uppercase cycle title centered behind it.
// ---------------------------------------------------------------------------
class _HeaderRow extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _HeaderRow({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 4.0,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _CloseButton(onTap: onClose),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceBlack.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.amber, width: 1.2),
        ),
        child: const Icon(
          Icons.close,
          color: AppColors.amber,
          size: 20,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked future stage — lock chip on the left, "<N> pts" centered, prize
// icon + amount on the right.
// ---------------------------------------------------------------------------
class _LockedStageRow extends StatelessWidget {
  final Map<String, dynamic> stage;
  final String unitLabel;
  const _LockedStageRow({required this.stage, required this.unitLabel});

  @override
  Widget build(BuildContext context) {
    final goal = (stage['goal'] as num?)?.toInt() ?? 0;
    final prize = parseChallengePrize((stage['prize'] ?? '').toString());
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.75),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock,
            color: AppColors.amber,
            size: 22,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$goal $unitLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          _PrizeChip(prize: prize),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active (in-progress) stage card — title, progress bar with overlapping
// prize icon, countdown. Styling deliberately mirrors the home-screen
// `_ChallengeCard` (border radius / weight, title font, bar height,
// prize-icon overlap, countdown row) so the popup's active card lands
// at exactly the same on-screen size as the home card — required by
// the smart-animate continuity: "the card stayed put while the ladder
// rose behind it."
//
// If the home card's visual spec changes, mirror the change here.
// ---------------------------------------------------------------------------
class _ActiveStageCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> stage;
  final int progress;
  final String fallbackTitle;
  final Duration remaining;
  final String unitLabel;

  const _ActiveStageCard({
    required this.title,
    required this.stage,
    required this.progress,
    required this.fallbackTitle,
    required this.remaining,
    required this.unitLabel,
  });

  @override
  Widget build(BuildContext context) {
    final goal = (stage['goal'] as num?)?.toInt() ?? 0;
    final prize = parseChallengePrize((stage['prize'] ?? '').toString());
    final shown = progress > goal ? goal : progress;
    final fraction = goal == 0 ? 0.0 : shown / goal;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.94),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 0.7,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.isEmpty ? fallbackTitle : title,
              style: const TextStyle(
                color: AppColors.amber,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            _ProgressBarWithPrize(
              fraction: fraction,
              label: '$shown/$goal $unitLabel',
              prize: prize,
            ),
            const SizedBox(height: 8),
            _CountdownRowCentered(remaining: remaining),
          ],
        ),
      ),
    );
  }
}

// Mirrors home_screen.dart `_ChallengeBar`: 28pt bar, 36pt prize icon
// overlapping the bar's right end by 10%, 18pt amount badge below the
// icon (also overlapping). Dimensions kept verbatim so the popup card
// matches the home card pixel-for-pixel.
class _ProgressBarWithPrize extends StatelessWidget {
  static const double _barHeight = 28;
  static const double _prizeIconSize = 36;
  static const double _amountBadgeHeight = 18;
  static const double _badgeBoxWidth = 56;
  static const double _barOverlapFraction = 0.10;
  static const double _badgeOverlapFraction = 0.10;

  final double fraction;
  final String label;
  final ChallengePrize prize;

  const _ProgressBarWithPrize({
    required this.fraction,
    required this.label,
    required this.prize,
  });

  @override
  Widget build(BuildContext context) {
    const barRightInset = _prizeIconSize * (1 - _barOverlapFraction);
    const barTop = (_prizeIconSize - _barHeight) / 2;
    const badgeTop = _prizeIconSize - _amountBadgeHeight * _badgeOverlapFraction;
    const totalHeight =
        _prizeIconSize + _amountBadgeHeight * (1 - _badgeOverlapFraction);
    final clamped = fraction.isNaN
        ? 0.0
        : fraction < 0
            ? 0.0
            : (fraction > 1 ? 1.0 : fraction);
    final iconWidget = SizedBox(
      width: _prizeIconSize,
      height: _prizeIconSize,
      child: Image.asset(
        prize.asset,
        errorBuilder: AssetPlaceholder.image(
          color: AppColors.amber,
          label: 'prize',
          borderRadius: 4,
        ),
      ),
    );
    final tappableIcon = prize.chestId == null
        ? iconWidget
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ChestContentsPopup.show(
              context,
              chestId: prize.chestId!,
              chestAsset: prize.asset,
              chestLabel: prize.label,
            ),
            child: ChestInfoBadge.wrap(iconWidget),
          );

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: barRightInset,
            top: barTop,
            height: _barHeight,
            child: _BarTrack(fraction: clamped, label: label),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: _prizeIconSize,
            height: _prizeIconSize,
            child: tappableIcon,
          ),
          Positioned(
            right: 16 - _badgeBoxWidth / 2,
            top: badgeTop,
            width: _badgeBoxWidth,
            height: _amountBadgeHeight,
            child: Center(
              child: Container(
                height: _amountBadgeHeight,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1606),
                  border: Border.all(color: AppColors.amber, width: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${prize.amount}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.greenPale,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarTrack extends StatelessWidget {
  static const Color _trackColor = Color(0xFF0d1a0d);
  final double fraction;
  final String label;
  const _BarTrack({required this.fraction, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: _trackColor)),
          LayoutBuilder(builder: (ctx, c) {
            // Animates 0 → fraction on popup open and tweens between
            // values when progress updates while the popup is visible.
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Container(
                width: c.maxWidth * value,
                decoration: const BoxDecoration(color: AppColors.green),
              ),
            );
          }),
          Align(
            alignment: const Alignment(0, 0),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: Color(0xCC000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownRowCentered extends StatelessWidget {
  final Duration remaining;
  const _CountdownRowCentered({required this.remaining});

  String _format(Duration d) {
    if (d.inDays >= 1) {
      final h = d.inHours - d.inDays * 24;
      return '${d.inDays}d ${h}h';
    }
    if (d.inHours >= 1) {
      final m = d.inMinutes - d.inHours * 60;
      return '${d.inHours}h ${m}m';
    }
    final m = d.inMinutes;
    return '${m < 1 ? 1 : m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.access_time, color: AppColors.greenPale, size: 13),
        const SizedBox(width: 5),
        Text(
          '${_format(remaining)} remaining',
          style: const TextStyle(
            color: AppColors.greenPale,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Prize chip — icon + amount. Tapping a chest prize opens its contents.
// ---------------------------------------------------------------------------
class _PrizeChip extends StatelessWidget {
  final ChallengePrize prize;
  const _PrizeChip({required this.prize});

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox(
      width: 28,
      height: 28,
      child: Image.asset(
        prize.asset,
        errorBuilder: AssetPlaceholder.image(
          color: AppColors.amber,
          label: 'prize',
          borderRadius: 4,
        ),
      ),
    );
    final id = prize.chestId;
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${prize.amount}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        id == null ? icon : ChestInfoBadge.wrap(icon, diameter: 13),
      ],
    );
    if (id == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ChestContentsPopup.show(
        context,
        chestId: id,
        chestAsset: prize.asset,
        chestLabel: prize.label,
      ),
      child: body,
    );
  }
}

// ---------------------------------------------------------------------------
// Info (!) — opens the cycle's goal description.
// ---------------------------------------------------------------------------
class _GoalInfoButton extends StatelessWidget {
  final ChallengeType challengeType;
  final String title;
  const _GoalInfoButton({required this.challengeType, required this.title});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGoal(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceBlack,
          border: Border.all(color: AppColors.amber, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '!',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  void _showGoal(BuildContext context) {
    final rc = RemoteConfigService.I.challengeById(challengeType.jsonValue);
    final goalText = _goalDescription(rc?.metric, challengeType);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.amber, width: 0.8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.amberLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                goalText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.greenPale,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: AppColors.amberLight,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolves the player-facing target line from the RC `metric` field.
  /// Falls back to the enum's description if RC is unavailable or has an
  /// unknown metric, so the dialog always renders something readable.
  String _goalDescription(String? metric, ChallengeType type) {
    switch (metric) {
      case 'kills':
        return 'Destroy enemies in your current biome to advance each stage.';
      case 'survival':
        return 'Clear stages without losing your jet.';
      case 'score':
        return 'Earn score across stages.';
      case 'stars':
        return 'Clear stages with 2★ or higher.';
      default:
        return type.description;
    }
  }
}
