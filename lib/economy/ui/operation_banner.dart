import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../state/challenge_state.dart';
import '../state/economy_state.dart';
import 'challenge_detail_screen.dart';

const _cAmber = AppColors.amber;
const _cAmberDark = AppColors.amberDark;
const _cAmberLight = AppColors.amberLight;
const _cGreen = AppColors.green;
const _cGreenLight = AppColors.greenLight;
const _cGreenPale = AppColors.greenPale;
const _cOpBannerBg = AppColors.surfaceBlack;
const _cOpTrack = Color(0xFF0d1a0d);

/// Home-screen operation banner — shows the active challenge's progress
/// bar, time remaining, and a chest icon. Tapping opens
/// [ChallengeDetailScreen]. The banner is hidden until the player has
/// cleared Stage 3 for the first time.
class OperationBanner extends StatefulWidget {
  const OperationBanner({super.key});

  @override
  State<OperationBanner> createState() => _OperationBannerState();
}

class _OperationBannerState extends State<OperationBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh once per second so the countdown stays current.
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
    if (!economy.challengeRevealed || view == null) {
      // Pre-Stage-3: banner is hidden entirely.
      return const SizedBox.shrink();
    }

    final remaining = view.remainingFrom(DateTime.now());
    final daysLeft = remaining.inDays;
    final hoursLeft = remaining.inHours % 24;
    final canClaim = view.canClaim100;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChallengeDetailScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: _cOpBannerBg.withValues(alpha: 0.92),
            border: Border.all(
              color: canClaim ? _cAmberLight : _cAmber,
              width: canClaim ? 1.0 : 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: canClaim
                ? [
                    BoxShadow(
                      color: _cAmber.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: type label + claim hint
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '⚡ ${view.type.displayName}',
                    style: const TextStyle(
                      color: _cAmberLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (canClaim)
                    const Text(
                      'TAP TO CLAIM',
                      style: TextStyle(
                        color: _cAmberLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 2: progress bar + chest icon
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 14,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: _cOpTrack,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          LayoutBuilder(builder: (ctx, constraints) {
                            final fillW =
                                constraints.maxWidth * view.fraction;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: fillW,
                              decoration: BoxDecoration(
                                color: _cGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          }),
                          Center(
                            child: Text(
                              '${view.progress} / ${view.target}',
                              style: const TextStyle(
                                color: _cGreenPale,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 20,
                    height: 18,
                    child: Image.asset(
                      'assets/ui/icon_chest.png',
                      errorBuilder: AssetPlaceholder.image(
                        color: _cAmberDark,
                        label: 'chest',
                        borderRadius: 3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 3: timer + milestone progress chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // v2: single completion milestone chip only.
                  _MilestoneChip(
                    label: '100%',
                    active: view.reached100,
                    claimed: view.milestone100Claimed,
                  ),
                  Text(
                    remaining == Duration.zero
                        ? '⏱ ended'
                        : '⏱ ${daysLeft}d ${hoursLeft}h',
                    style:
                        const TextStyle(color: _cAmber, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool claimed;
  const _MilestoneChip({
    required this.label,
    required this.active,
    required this.claimed,
  });

  @override
  Widget build(BuildContext context) {
    final color = claimed
        ? _cGreenLight
        : active
            ? _cAmberLight
            : Colors.white24;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        claimed ? '$label ✓' : label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
