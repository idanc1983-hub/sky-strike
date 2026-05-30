import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../state/challenge_state.dart';
import '../state/economy_state.dart';

/// Drill-down screen for the active challenge cycle. Shows the type,
/// description, progress bar, time remaining, and 50% / 100% milestone
/// claim buttons.
class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  Timer? _ticker;

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
    return Scaffold(
      backgroundColor: AppColors.greenDeep,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        title: const Text('Operation', style: AppTypography.title),
      ),
      body: SafeArea(
        child: view == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No active operation. Clear Stage 3 to start.',
                    style: AppTypography.bodyPale,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _Body(view: view),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ChallengeView view;
  const _Body({required this.view});

  @override
  Widget build(BuildContext context) {
    final remaining = view.remainingFrom(DateTime.now());
    final daysLeft = remaining.inDays;
    final hoursLeft = remaining.inHours % 24;
    final minutesLeft = remaining.inMinutes % 60;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.amber, width: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(view.type.displayName,
                  style: AppTypography.title.copyWith(fontSize: 22)),
              const SizedBox(height: 4),
              Text(view.type.description, style: AppTypography.bodyPale),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: view.fraction,
                        minHeight: 12,
                        backgroundColor: AppColors.greenTrack,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${view.progress} / ${view.target}',
                    style: AppTypography.bodyPale.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Time remaining', style: AppTypography.label),
                  Text(
                    remaining == Duration.zero
                        ? 'Ended'
                        : '${daysLeft}d ${hoursLeft}h ${minutesLeft}m',
                    style: AppTypography.countdown,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // v2: single completion reward at 100%. The mid-cycle 50%
        // milestone was removed.
        _MilestoneCard(
          title: 'Completion Reward',
          reached: view.reached100,
          claimed: view.milestone100Claimed,
          onClaim: () {
            context.read<EconomyState>().claimChallengeMilestone100();
          },
        ),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final String title;
  final bool reached;
  final bool claimed;
  final VoidCallback onClaim;

  const _MilestoneCard({
    required this.title,
    required this.reached,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final canClaim = reached && !claimed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canClaim
              ? AppColors.amberLight
              : claimed
                  ? AppColors.green
                  : AppColors.greenTrack,
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/ui/icon_chest_basic.png',
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: claimed ? AppColors.green : AppColors.amber,
                label: 'chest',
                borderRadius: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AppTypography.bodyPale.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                const SizedBox(height: 2),
                Text(
                  claimed
                      ? 'Claimed'
                      : reached
                          ? 'Ready to claim!'
                          : 'Not yet reached',
                  style: AppTypography.label,
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canClaim ? AppColors.amber : AppColors.greenTrack,
              foregroundColor: canClaim ? Colors.black : AppColors.greenLabel,
            ),
            onPressed: canClaim ? onClaim : null,
            child: Text(claimed ? 'CLAIMED' : 'CLAIM'),
          ),
        ],
      ),
    );
  }
}
