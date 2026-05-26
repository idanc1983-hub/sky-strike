import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/remote_config_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../state/economy_state.dart';

/// 7-day login ladder — full-screen route launched from the home menu.
/// Layout: 3 columns × 2 rows for D1–D6, then a full-width D7 tile.
///
/// Reward values come from remote config (`challenges__daily_reward__v1`)
/// using the player's current week and 1..7 day. Each tile renders in one
/// of three states:
///
/// - **claimed**  — green border, "Day N" header in green
/// - **today**    — solid green fill (claimable)
/// - **future**   — amber border (locked / upcoming)
class DailyRewardScreen extends StatelessWidget {
  const DailyRewardScreen({super.key});

  static const _bgAsset = 'assets/backgrounds/Home_screen_Airstrip.png';

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final week = economy.streakWeeksCompleted + 1;
    final today = economy.streakDay;
    final canClaimToday = economy.canClaimStreakToday;

    return Scaffold(
      backgroundColor: AppColors.greenDeep,
      body: Stack(
        children: [
          // Hangar bg (same as home) — dimmed for legibility.
          Positioned.fill(
            child: Image.asset(
              _bgAsset,
              fit: BoxFit.cover,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.greenDeep,
                label: 'home_bg',
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0x99000000)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppTopBar.close(
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 8),
                _ChestHero(),
                const SizedBox(height: 12),
                const _Title(),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _DayGrid(week: week, today: today),
                        const SizedBox(height: 12),
                        _Day7Tile(week: week, today: today),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AppButton.primary(
                    label: 'CLAIM',
                    onPressed: canClaimToday
                        ? () => _handleClaim(context)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
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
      return;
    }
    final parts = <String>[
      if (reward.coins > 0) '${reward.coins} coins',
      if (reward.gems > 0) '${reward.gems} gems',
      if (reward.powerUps.isNotEmpty)
        '${reward.powerUps.length} power-up(s)',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Claimed: ${parts.join(', ')}')),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — large treasure chest icon centred at the top.
// ---------------------------------------------------------------------------
class _ChestHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Image.asset(
        'assets/ui/icon_chest_basic.png',
        fit: BoxFit.contain,
        errorBuilder: AssetPlaceholder.image(
          color: AppColors.amber,
          label: 'chest',
          borderRadius: 8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Title — "REWARD / CALENDAR"
// ---------------------------------------------------------------------------
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'REWARD',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w500,
            letterSpacing: 8,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'CALENDAR',
          style: TextStyle(
            color: Color(0xFFD8E6C0),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 6,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day 1–6 grid (3 cols × 2 rows).
// ---------------------------------------------------------------------------
class _DayGrid extends StatelessWidget {
  final int week;
  final int today;
  const _DayGrid({required this.week, required this.today});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: 6,
      itemBuilder: (ctx, i) {
        final day = i + 1;
        return _DayTile(
          day: day,
          state: _stateForDay(day, today),
          rewardConfig: RemoteConfigService.instance.dailyReward(week, day),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Day 7 — full-width tile, visually distinct as the climax reward.
// ---------------------------------------------------------------------------
class _Day7Tile extends StatelessWidget {
  final int week;
  final int today;
  const _Day7Tile({required this.week, required this.today});

  @override
  Widget build(BuildContext context) {
    return _DayTile(
      day: 7,
      state: _stateForDay(7, today),
      rewardConfig: RemoteConfigService.instance.dailyReward(week, 7),
      fullWidth: true,
    );
  }
}

// ---------------------------------------------------------------------------
// Day tile — used for both 3-col grid cells and the full-width D7 row.
// ---------------------------------------------------------------------------
class _DayTile extends StatelessWidget {
  final int day;
  final _TileState state;
  final Map<String, dynamic>? rewardConfig;
  final bool fullWidth;

  const _DayTile({
    required this.day,
    required this.state,
    required this.rewardConfig,
    this.fullWidth = false,
  });

  Color get _borderColor {
    switch (state) {
      case _TileState.claimed:
        return AppColors.greenLight;
      case _TileState.today:
        return AppColors.greenLight;
      case _TileState.future:
        return AppColors.amber.withValues(alpha: 0.7);
    }
  }

  Color get _fillColor {
    switch (state) {
      case _TileState.today:
        return AppColors.green;
      case _TileState.claimed:
      case _TileState.future:
        return AppColors.surfaceBlack;
    }
  }

  Color get _headerColor {
    switch (state) {
      case _TileState.claimed:
        return AppColors.greenLight;
      case _TileState.today:
        return Colors.white;
      case _TileState.future:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fullWidth ? 14 : 8,
        vertical: fullWidth ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: _fillColor,
        border: Border.all(color: _borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: fullWidth
          ? Column(
              children: [
                Text(
                  'Day $day',
                  style: TextStyle(
                    color: _headerColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _RewardRow(reward: rewardConfig, large: true),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $day',
                  style: TextStyle(
                    color: _headerColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _RewardRow(reward: rewardConfig, large: false),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reward row — renders the per-day reward icon(s) + amount text, parsed
// from the remote-config entry's `coin / gem / chest / jet / jet_fallback`
// fields. Day 7 can show a multi-item bundle (jet OR fallback).
// ---------------------------------------------------------------------------
class _RewardRow extends StatelessWidget {
  final Map<String, dynamic>? reward;
  final bool large;
  const _RewardRow({required this.reward, required this.large});

  @override
  Widget build(BuildContext context) {
    final items = _parseRewards(reward);
    final iconSize = large ? 28.0 : 22.0;
    final textStyle = TextStyle(
      color: AppColors.amber,
      fontSize: large ? 16 : 13,
      fontWeight: FontWeight.w700,
    );
    return Row(
      mainAxisAlignment:
          large ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: 6),
            Text(
              '|',
              style: TextStyle(
                color: AppColors.amber.withValues(alpha: 0.5),
                fontSize: large ? 16 : 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: Image.asset(
              items[i].iconAsset,
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: items[i].iconColor,
                label: items[i].label,
                borderRadius: 4,
              ),
            ),
          ),
          if (items[i].amountLabel != null) ...[
            const SizedBox(width: 4),
            Text(items[i].amountLabel!, style: textStyle),
          ],
        ],
      ],
    );
  }
}

/// Translates an RC daily-reward entry into renderable items. Day 7 may
/// produce multiple items (jet + fallback bundle); other days produce 1.
List<_RewardItem> _parseRewards(Map<String, dynamic>? reward) {
  if (reward == null) {
    return const [
      _RewardItem(
        iconAsset: 'assets/ui/icon_coin.png',
        iconColor: AppColors.amber,
        label: 'coin',
        amountLabel: 'x?',
      ),
    ];
  }
  final coin = (reward['coin'] as num?)?.toInt() ?? 0;
  final gem = (reward['gem'] as num?)?.toInt() ?? 0;
  final chest = reward['chest'] as String?;
  final jet = reward['jet'] as String?;
  final items = <_RewardItem>[];
  if (coin > 0) {
    items.add(_RewardItem(
      iconAsset: 'assets/ui/icon_coin.png',
      iconColor: AppColors.amber,
      label: 'coin',
      amountLabel: 'x$coin',
    ));
  }
  if (gem > 0) {
    items.add(_RewardItem(
      iconAsset: 'assets/ui/icon_gem.png',
      iconColor: const Color(0xFF7BB8FF),
      label: 'gem',
      amountLabel: 'x$gem',
    ));
  }
  if (chest != null) {
    items.add(_RewardItem(
      iconAsset: 'assets/ui/icon_chest_${chest.replaceAll('_chest', '')}.png',
      iconColor: AppColors.amber,
      label: chest,
      amountLabel: null,
    ));
  }
  if (jet != null) {
    items.add(const _RewardItem(
      iconAsset: 'assets/ui/icon_jet_reward.png',
      iconColor: Color(0xFF7BB8FF),
      label: 'jet',
      amountLabel: 'x1',
    ));
  }
  // If empty (all zero / null), show a placeholder so the tile isn't blank.
  if (items.isEmpty) {
    items.add(const _RewardItem(
      iconAsset: 'assets/ui/icon_coin.png',
      iconColor: AppColors.amber,
      label: 'reward',
      amountLabel: '?',
    ));
  }
  return items;
}

class _RewardItem {
  final String iconAsset;
  final Color iconColor;
  final String label;
  final String? amountLabel;
  const _RewardItem({
    required this.iconAsset,
    required this.iconColor,
    required this.label,
    required this.amountLabel,
  });
}

enum _TileState { claimed, today, future }

_TileState _stateForDay(int day, int today) {
  if (day < today) return _TileState.claimed;
  if (day == today) return _TileState.today;
  return _TileState.future;
}
