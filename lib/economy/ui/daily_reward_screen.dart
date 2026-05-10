import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/economy_constants.dart';
import '../state/economy_state.dart';
import '../state/reward.dart';

/// 7-day login ladder. The Day 7 card is rendered larger and themed gold
/// per GDD §5.
class DailyRewardScreen extends StatelessWidget {
  const DailyRewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    return Scaffold(
      backgroundColor: AppColors.greenDeep,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        title: const Text('Daily Rewards', style: AppTypography.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Streak: Day ${economy.streakDay}',
              style: AppTypography.bodyPale,
            ),
            Text(
              'Longest streak: ${economy.longestStreak}',
              style: AppTypography.label,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: 6,
              itemBuilder: (ctx, i) {
                final day = i + 1;
                return _DayCard(
                  day: day,
                  state: _stateForDay(day, economy.streakDay),
                  reward: _rewardForDay(day),
                  onClaim: economy.canClaimStreakToday && day == economy.streakDay
                      ? () => _handleClaim(context)
                      : null,
                );
              },
            ),
            const SizedBox(height: 16),
            _Day7Card(
              state: _stateForDay(7, economy.streakDay),
              onClaim: economy.canClaimStreakToday && economy.streakDay == 7
                  ? () => _handleClaim(context)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  _CardState _stateForDay(int day, int streakDay) {
    if (day < streakDay) return _CardState.claimed;
    if (day == streakDay) return _CardState.active;
    return _CardState.locked;
  }

  Reward _rewardForDay(int day) {
    final i = day - 1;
    return Reward(
      coins: i >= 0 && i < EconomyConstants.streakDailyCoins.length
          ? EconomyConstants.streakDailyCoins[i]
          : 0,
      gems: i >= 0 && i < EconomyConstants.streakDailyGems.length
          ? EconomyConstants.streakDailyGems[i]
          : 0,
    );
  }

  Future<void> _handleClaim(BuildContext context) async {
    final economy = context.read<EconomyState>();
    final reward = economy.claimDailyReward();
    if (!context.mounted) return;
    if (reward.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already claimed today.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Got ${reward.coins} coins, ${reward.gems} gems'
            '${reward.powerUps.isEmpty ? '' : ', ${reward.powerUps.length} power-up(s)'}',
          ),
        ),
      );
    }
  }
}

enum _CardState { locked, active, claimed }

class _DayCard extends StatelessWidget {
  final int day;
  final _CardState state;
  final Reward reward;
  final VoidCallback? onClaim;

  const _DayCard({
    required this.day,
    required this.state,
    required this.reward,
    this.onClaim,
  });

  String get _frameAsset {
    switch (state) {
      case _CardState.active:
        return 'assets/ui/card_active.png';
      case _CardState.claimed:
        return 'assets/ui/card_claimed.png';
      case _CardState.locked:
        return 'assets/ui/card_locked.png';
    }
  }

  Color get _frameTint {
    switch (state) {
      case _CardState.active:
        return AppColors.amber;
      case _CardState.claimed:
        return AppColors.greenDeep;
      case _CardState.locked:
        return AppColors.greenTrack;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClaim,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _frameAsset,
            fit: BoxFit.cover,
            errorBuilder: AssetPlaceholder.image(
              color: _frameTint,
              label: 'card_${state.name}',
              borderRadius: 8,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Day $day', style: AppTypography.label),
                if (state == _CardState.claimed)
                  const Icon(Icons.check_circle,
                      color: AppColors.greenLight, size: 22)
                else
                  Column(
                    children: [
                      if (reward.coins > 0)
                        Text('${reward.coins}c',
                            style: AppTypography.bodyPale.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                      if (reward.gems > 0)
                        Text('${reward.gems}💎',
                            style: AppTypography.bodyPale.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                    ],
                  ),
                if (state == _CardState.active)
                  ElevatedButton(
                    onPressed: onClaim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('CLAIM',
                        style: TextStyle(fontSize: 11)),
                  )
                else
                  const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Day7Card extends StatelessWidget {
  final _CardState state;
  final VoidCallback? onClaim;
  const _Day7Card({required this.state, this.onClaim});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClaim,
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/ui/card_day7.png',
              fit: BoxFit.cover,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amber,
                label: 'card_day7',
                borderRadius: 12,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Day 7 — CHEST',
                      style: TextStyle(
                        color: AppColors.amberLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      )),
                  const Text(
                    'Level-scaled coins, gems, power-ups',
                    style: AppTypography.bodyPale,
                  ),
                  if (state == _CardState.active && onClaim != null)
                    ElevatedButton(
                      onPressed: onClaim,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('CLAIM CHEST'),
                    ),
                  if (state == _CardState.claimed)
                    const Icon(Icons.check_circle,
                        color: AppColors.greenLight, size: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
