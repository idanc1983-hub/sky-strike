import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../services/challenge_prize_parser.dart';
import '../state/challenge_state.dart';
import '../state/economy_state.dart';
import 'chest_contents_popup.dart';

/// Popup launched by tapping the home-screen challenge card.
///
/// Shows the cycle's grand prize plus a window of upcoming milestone
/// rewards (current stage + next 4 locked). The player never sees the
/// full ladder — only the next few stages are revealed at any time.
/// A small `(!)` button at the bottom expands the active challenge
/// type's goal description (Hunter / Survivor / Treasure / Conqueror).
///
/// Placeholder stage ladder is hardcoded for now; when the cycle plan
/// gains a `stages` array in remote config (alongside `display_name`),
/// swap [_placeholderStages] / [_placeholderGrandPrize] for the parsed
/// list from `EconomyState`.
class ChallengePrizesPopup extends StatefulWidget {
  const ChallengePrizesPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const ChallengePrizesPopup(),
    );
  }

  @override
  State<ChallengePrizesPopup> createState() => _ChallengePrizesPopupState();
}

class _ChallengePrizesPopupState extends State<ChallengePrizesPopup> {
  Timer? _ticker;

  // ---------------------------------------------------------------------------
  // Placeholder data. Real values come from challenges__cycle_plan__v1
  // when wired through `EconomyState`.
  // ---------------------------------------------------------------------------
  static const String _placeholderCycleName = 'Iron Skies';

  static const _PrizeEntry _placeholderGrandPrize = _PrizeEntry(
    asset: 'assets/ui/icon_chest_operation.png',
    amount: 2500,
  );

  /// Index 0 = current (just-reached / claimable). 1..N = locked.
  /// The list size matches the design: "current + next 4".
  static const List<_PrizeEntry> _placeholderStages = <_PrizeEntry>[
    _PrizeEntry(asset: 'assets/ui/icon_coin.png', amount: 300),
    _PrizeEntry(asset: 'assets/ui/icon_gem.png', amount: 20),
    _PrizeEntry(asset: 'assets/ui/icon_coin.png', amount: 500),
    _PrizeEntry(asset: 'assets/ui/icon_chest_rare.png', amount: 1),
    _PrizeEntry(asset: 'assets/ui/icon_coin.png', amount: 800),
  ];
  static const int _currentStageIndex = 0;

  @override
  void initState() {
    super.initState();
    // Refresh every second so the "Time left" countdown stays current.
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
    // Fallback type is Hunter so the goal description is meaningful even
    // before the player has unlocked the challenge system.
    final type = view?.type ?? ChallengeType.hunter;
    final remaining =
        view?.remainingFrom(DateTime.now()) ?? const Duration(hours: 72);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.amber.withValues(alpha: 0.6),
            width: 1.0,
          ),
          // Cycle-specific background. Today only the "Iron Skies"
          // placeholder is shipped; once cycle plumbing lands, this
          // path comes from the active cycle's remote-config entry.
          image: const DecorationImage(
            image: AssetImage(
              'assets/ui/home/challenge_popup_iron_skies.png',
            ),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(
                title: view?.type.displayName ?? _placeholderCycleName,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              _GrandPrizeBanner(prize: _grandPrizeFor(economy)),
              const SizedBox(height: 14),
              ..._buildStageList(economy),
              const SizedBox(height: 12),
              _FooterRow(
                remaining: remaining,
                challengeType: type,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the visible stage rows from the active cycle's RC ladder.
  /// Falls back to the hardcoded placeholders when no cycle is active or
  /// RC has no ladder entry for it.
  ///
  /// Only renders a *window* of the ladder (current + next N) so cycles
  /// with many stages (new_players has 15) don't bury the early prizes
  /// at the bottom of a long scroll list. Furthest-from-current stages
  /// render at the top so the ladder visually rises toward the grand-
  /// prize banner.
  List<Widget> _buildStageList(EconomyState economy) {
    final stages = economy.activeChallengeStages;
    final entries = stages.isEmpty
        ? _placeholderStages
        : stages
            .map((s) => _prizeEntryFrom(
                  parseChallengePrize((s['prize'] ?? '').toString()),
                ))
            .toList();

    // Window: current + next 4. Current is the lowest unclaimed stage,
    // approximated here as stage 1 (index 0) until per-stage claim
    // state is wired through EconomyState.
    const windowSize = 5;
    final windowEnd = entries.length < windowSize
        ? entries.length
        : windowSize;

    return <Widget>[
      for (int i = windowEnd - 1; i >= 0; i--)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _StageRow(
            stage: entries[i],
            isCurrent: i == _currentStageIndex,
            isLocked: i > _currentStageIndex,
          ),
        ),
    ];
  }

  /// Picks the last stage's prize as the "grand" banner so the popup
  /// always shows the cycle's pinnacle reward at the top. Falls back to
  /// the placeholder banner if RC has no ladder.
  _PrizeEntry _grandPrizeFor(EconomyState economy) {
    final stages = economy.activeChallengeStages;
    if (stages.isEmpty) return _placeholderGrandPrize;
    final parsed =
        parseChallengePrize((stages.last['prize'] ?? '').toString());
    return _prizeEntryFrom(parsed);
  }
}

/// Adapter that lets a [ChallengePrize] satisfy the popup's existing
/// `_PrizeEntry` shape without duplicating fields.
_PrizeEntry _prizeEntryFrom(ChallengePrize p) =>
    _PrizeEntry(asset: p.asset, amount: p.amount, chestId: p.chestId, label: p.label);

class _PrizeEntry {
  final String asset;
  final int amount;
  final String? chestId;
  final String label;
  const _PrizeEntry({
    required this.asset,
    required this.amount,
    this.chestId,
    this.label = '',
  });
}

/// Wraps a child in a tappable that opens [ChestContentsPopup] when the
/// prize has a [chestId]. Pass-through (no GestureDetector overhead) for
/// non-chest prizes so coin/gem icons stay non-interactive.
class _ChestTappable extends StatelessWidget {
  final _PrizeEntry prize;
  final Widget child;
  const _ChestTappable({required this.prize, required this.child});

  @override
  Widget build(BuildContext context) {
    final id = prize.chestId;
    if (id == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ChestContentsPopup.show(
        context,
        chestId: id,
        chestAsset: prize.asset,
        chestLabel: prize.label,
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Header — cycle name + close button
// ---------------------------------------------------------------------------
class _HeaderRow extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _HeaderRow({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceDark,
              border: Border.all(color: AppColors.amber, width: 0.8),
            ),
            child: const Icon(
              Icons.close,
              color: AppColors.amberLight,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grand prize banner
// ---------------------------------------------------------------------------
class _GrandPrizeBanner extends StatelessWidget {
  final _PrizeEntry prize;

  const _GrandPrizeBanner({required this.prize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber, width: 1.2),
      ),
      child: Column(
        children: [
          const Text(
            'GRAND PRIZE',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChestTappable(
                prize: prize,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.asset(
                    prize.asset,
                    errorBuilder: AssetPlaceholder.image(
                      color: AppColors.amber,
                      label: 'grand',
                      borderRadius: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${prize.amount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stage row — lock dot + prize card
// ---------------------------------------------------------------------------
class _StageRow extends StatelessWidget {
  final _PrizeEntry stage;
  final bool isCurrent;
  final bool isLocked;

  const _StageRow({
    required this.stage,
    required this.isCurrent,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isCurrent ? AppColors.greenLight : AppColors.amber;
    final bg = isCurrent
        ? const Color(0xFF1A3A0A)
        : AppColors.surfaceDark.withValues(alpha: 0.92);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLocked ? AppColors.surfaceDark : AppColors.greenLight,
            border: Border.all(color: accent, width: 1),
          ),
          child: Icon(
            isLocked ? Icons.lock : Icons.play_arrow_rounded,
            color: isLocked
                ? AppColors.amberLight.withValues(alpha: 0.85)
                : AppColors.greenDeep,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: accent.withValues(alpha: 0.75), width: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ChestTappable(
                  prize: stage,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Image.asset(
                      stage.asset,
                      errorBuilder: AssetPlaceholder.image(
                        color: AppColors.amber,
                        label: 'prize',
                        borderRadius: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${stage.amount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Footer — time left + (!) info button
// ---------------------------------------------------------------------------
class _FooterRow extends StatelessWidget {
  final Duration remaining;
  final ChallengeType challengeType;

  const _FooterRow({
    required this.remaining,
    required this.challengeType,
  });

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Time left: ${_format(remaining)}',
            style: const TextStyle(
              color: AppColors.greenPale,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _GoalInfoButton(challengeType: challengeType),
      ],
    );
  }
}

class _GoalInfoButton extends StatelessWidget {
  final ChallengeType challengeType;

  const _GoalInfoButton({required this.challengeType});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGoal(context),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceDark,
          border: Border.all(color: AppColors.amber, width: 1),
        ),
        child: const Center(
          child: Text(
            '!',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  void _showGoal(BuildContext context) {
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
                challengeType.displayName,
                style: const TextStyle(
                  color: AppColors.amberLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                challengeType.description,
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
}
