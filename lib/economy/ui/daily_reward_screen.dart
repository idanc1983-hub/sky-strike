import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/remote_config_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../services/day7_reward_resolver.dart';
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
                        _DayGrid(
                          week: week,
                          today: today,
                          currentWorld: economy.currentWorld,
                          ownedJets: economy.ownedJets,
                        ),
                        const SizedBox(height: 12),
                        _Day7Tile(
                          week: week,
                          today: today,
                          currentWorld: economy.currentWorld,
                          ownedJets: economy.ownedJets,
                        ),
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
  final int currentWorld;
  final Set<String> ownedJets;
  const _DayGrid({
    required this.week,
    required this.today,
    required this.currentWorld,
    required this.ownedJets,
  });

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
          rewardConfig: _dailyRewardLegacyMap(week, day),
          currentWorld: currentWorld,
          ownedJets: ownedJets,
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
  final int currentWorld;
  final Set<String> ownedJets;
  const _Day7Tile({
    required this.week,
    required this.today,
    required this.currentWorld,
    required this.ownedJets,
  });

  @override
  Widget build(BuildContext context) {
    return _DayTile(
      day: 7,
      state: _stateForDay(7, today),
      rewardConfig: _dailyRewardLegacyMap(week, 7),
      currentWorld: currentWorld,
      ownedJets: ownedJets,
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
  final int currentWorld;
  final Set<String> ownedJets;
  final bool fullWidth;

  const _DayTile({
    required this.day,
    required this.state,
    required this.rewardConfig,
    required this.currentWorld,
    required this.ownedJets,
    this.fullWidth = false,
  });

  Color get _borderColor {
    switch (state) {
      case _TileState.claimed:
        return AppColors.green.withValues(alpha: 0.5);
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
      // Claimed = noticeably darker than future so the row reads as
      // "already done" at a glance.
      case _TileState.claimed:
        return const Color(0xFF020602);
      case _TileState.future:
        return AppColors.surfaceBlack;
    }
  }

  Color get _headerColor => Colors.white;

  @override
  Widget build(BuildContext context) {
    final isClaimed = state == _TileState.claimed;
    final container = Container(
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
                _RewardRow(
                  reward: rewardConfig,
                  currentWorld: currentWorld,
                  ownedJets: ownedJets,
                  large: true,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                _RewardRow(
                  reward: rewardConfig,
                  currentWorld: currentWorld,
                  ownedJets: ownedJets,
                  large: false,
                ),
              ],
            ),
    );
    if (!isClaimed) return container;
    // Claimed: dim the tile contents and overlay the CLAIMED stamp.
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.45, child: container),
        IgnorePointer(
          child: _ClaimedStamp(small: !fullWidth),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CLAIMED stamp overlay — renders an asset PNG when one ships at
// `assets/ui/stamp_claimed.png`; falls back to a stylised rotated text
// stamp until the artwork lands.
// ---------------------------------------------------------------------------
class _ClaimedStamp extends StatelessWidget {
  final bool small;
  const _ClaimedStamp({required this.small});

  static const _asset = 'assets/ui/stamp_claimed.png';

  @override
  Widget build(BuildContext context) {
    final size = small ? 80.0 : 120.0;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        _asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _StampPlaceholder(small: small),
      ),
    );
  }
}

class _StampPlaceholder extends StatelessWidget {
  final bool small;
  const _StampPlaceholder({required this.small});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.25,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 10,
          vertical: small ? 3 : 5,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFD23B3B),
            width: small ? 2 : 3,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'CLAIMED',
          style: TextStyle(
            color: const Color(0xFFD23B3B),
            fontSize: small ? 14 : 22,
            fontWeight: FontWeight.w900,
            letterSpacing: small ? 1.5 : 2.5,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reward row — renders the per-day reward icon(s) + amount text, parsed
// from the remote-config entry's `coin / gem / chest / jet / jet_fallback`
// fields. Day 7 resolves a `biome_match` jet against the player's current
// biome; if the player already owns it (proxy: biome 1 / starter jet) the
// row renders the `jet_fallback` bundle instead.
// ---------------------------------------------------------------------------
class _RewardRow extends StatelessWidget {
  final Map<String, dynamic>? reward;
  final int currentWorld;
  final Set<String> ownedJets;
  final bool large;
  const _RewardRow({
    required this.reward,
    required this.currentWorld,
    required this.ownedJets,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    final items = _parseRewards(reward, currentWorld, ownedJets);
    // Center the row when there's exactly one icon with no amount text
    // (chest-only and jet-only tiles). Currency tiles stay left-aligned.
    final hasOnlyIcon = items.length == 1 && items[0].amountLabel == null;
    // Match Day-7 icon size for solo chest/jet tiles so they don't appear
    // shrunken relative to the climax reward.
    final iconSize = (large || hasOnlyIcon) ? 64.0 : 44.0;
    final textStyle = TextStyle(
      color: AppColors.amber,
      fontSize: large ? 20 : 15,
      fontWeight: FontWeight.w700,
    );
    return Row(
      mainAxisAlignment: (large || hasOnlyIcon)
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: 8),
            Text(
              '|',
              style: TextStyle(
                color: AppColors.amber.withValues(alpha: 0.5),
                fontSize: large ? 22 : 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
          ],
          _RewardIcon(item: items[i], size: iconSize),
          if (items[i].amountLabel != null) ...[
            const SizedBox(width: 5),
            Text(items[i].amountLabel!, style: textStyle),
          ],
        ],
      ],
    );
  }
}

/// Reward icon. When the item carries a chest id, tapping it opens the
/// `_ChestProbabilityDialog` showing the chest's contents from RC.
class _RewardIcon extends StatelessWidget {
  final _RewardItem item;
  final double size;
  const _RewardIcon({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        item.iconAsset,
        fit: BoxFit.contain,
        errorBuilder: AssetPlaceholder.image(
          color: item.iconColor,
          label: item.label,
          borderRadius: 4,
        ),
      ),
    );
    if (item.chestId == null) return image;
    return GestureDetector(
      onTap: () => _ChestProbabilityDialog.show(context, item.chestId!),
      child: image,
    );
  }
}

// Biome → jet code-id mapping is owned by Day7RewardResolver
// (kDay7BiomeToJetCodeId / kDay7WorldToBiome) so the calendar tile and
// the actual grant can't drift apart.

const Map<String, String> _jetAssets = {
  'jet_player': 'assets/jets/jet_player.png',
  'wraith_x': 'assets/jets/jet_wraith_x.png',
  'specter': 'assets/jets/jet_specter.png',
  'viper': 'assets/jets/jet_viper.png',
  'inferno': 'assets/jets/jet_inferno.png',
  'phantom': 'assets/jets/jet_phantom.png',
};

/// Translates an RC daily-reward entry into renderable items.
List<_RewardItem> _parseRewards(
    Map<String, dynamic>? reward, int currentWorld, Set<String> ownedJets) {
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
  final jetFallback = reward['jet_fallback'] as String?;
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
      iconAsset: 'assets/ui/icon_$chest.png',
      iconColor: AppColors.amber,
      label: chest,
      amountLabel: null,
      chestId: chest,
    ));
  }
  if (jet != null) {
    items.addAll(_resolveJetReward(jet, jetFallback, currentWorld, ownedJets));
  }
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

/// Resolves the Day-7 jet reward. For `biome_match`: look up the
/// player's current-biome jet via [Day7RewardResolver.resolveJetCodeId];
/// if the player already owns it, fall back to parsing the [jetFallback]
/// bundle string. For an explicit jet id, render that jet (or the
/// fallback if already owned).
///
/// Uses the same biome-match logic as the grant path
/// ([Day7RewardResolver]) so the calendar tile and the actual reward
/// can't disagree.
List<_RewardItem> _resolveJetReward(
    String jet, String? jetFallback, int currentWorld,
    Set<String> ownedJets) {
  final jetCodeId =
      Day7RewardResolver.resolveJetCodeId(jet, currentWorld) ?? 'jet_player';
  final owned = ownedJets.contains(jetCodeId);
  if (owned && jetFallback != null && jetFallback.isNotEmpty) {
    return _parseFallbackBundle(jetFallback);
  }
  return [_jetItem(jetCodeId)];
}

_RewardItem _jetItem(String jetCodeId) => _RewardItem(
      iconAsset:
          _jetAssets[jetCodeId] ?? 'assets/jets/jet_player.png',
      iconColor: const Color(0xFF7BB8FF),
      label: jetCodeId,
      amountLabel: null,
    );

/// Parses fallback bundle strings like `"epic_chest + 50gem"` or
/// `"special_chest + 100gem"` into reward items. Tolerates extra spaces
/// and case variation. Unknown tokens are ignored rather than crashing.
List<_RewardItem> _parseFallbackBundle(String raw) {
  final out = <_RewardItem>[];
  for (final part in raw.split('+').map((s) => s.trim())) {
    if (part.isEmpty) continue;
    // <num>gem(s) / <num>coin(s)
    final amount = RegExp(r'^(\d+)\s*(gem|gems|coin|coins)$',
            caseSensitive: false)
        .firstMatch(part);
    if (amount != null) {
      final n = int.parse(amount.group(1)!);
      final unit = amount.group(2)!.toLowerCase();
      if (unit.startsWith('gem')) {
        out.add(_RewardItem(
          iconAsset: 'assets/ui/icon_gem.png',
          iconColor: const Color(0xFF7BB8FF),
          label: 'gem',
          amountLabel: 'x$n',
        ));
      } else {
        out.add(_RewardItem(
          iconAsset: 'assets/ui/icon_coin.png',
          iconColor: AppColors.amber,
          label: 'coin',
          amountLabel: 'x$n',
        ));
      }
      continue;
    }
    // chest id (basic_chest / unique_chest / epic_chest / special_chest)
    if (part.endsWith('_chest')) {
      out.add(_RewardItem(
        iconAsset: 'assets/ui/icon_$part.png',
        iconColor: AppColors.amber,
        label: part,
        amountLabel: null,
        chestId: part,
      ));
    }
  }
  return out;
}

class _RewardItem {
  final String iconAsset;
  final Color iconColor;
  final String label;
  final String? amountLabel;
  /// Non-null when this item is a chest — used to wire the tap-to-preview
  /// probability dialog. Matches the RC `chests.<id>` key.
  final String? chestId;
  const _RewardItem({
    required this.iconAsset,
    required this.iconColor,
    required this.label,
    required this.amountLabel,
    this.chestId,
  });
}

enum _TileState { claimed, today, future }

_TileState _stateForDay(int day, int today) {
  if (day < today) return _TileState.claimed;
  if (day == today) return _TileState.today;
  return _TileState.future;
}

// ---------------------------------------------------------------------------
// Chest probability dialog — shown when tapping a chest icon in the
// reward calendar. Lists possible rewards (coin/gem ranges, jet drop %)
// from the RC `chests.<id>` entry. No buy buttons — the calendar grants
// the chest as a streak reward, not as a purchase.
// ---------------------------------------------------------------------------
class _ChestProbabilityDialog extends StatelessWidget {
  final String chestId;
  const _ChestProbabilityDialog({required this.chestId});

  static Future<void> show(BuildContext context, String chestId) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _ChestProbabilityDialog(chestId: chestId),
    );
  }

  Map<String, dynamic> get _config {
    final def = RemoteConfigService.I.chests.byId(chestId);
    if (def == null) return const <String, dynamic>{};
    return <String, dynamic>{
      'coin_min': def.coinMin,
      'coin_max': def.coinMax,
      'gem_min': def.gemMin,
      'gem_max': def.gemMax,
      'jet_drop_chance': def.jetDropChance,
      'jet_id': def.jetId,
    };
  }

  int _readInt(String key) {
    final v = _config[key];
    return v is num ? v.toInt() : 0;
  }

  double _readDouble(String key) {
    final v = _config[key];
    return v is num ? v.toDouble() : 0.0;
  }

  String _formatRange(int lo, int hi) {
    if (lo == hi) return '$lo';
    return '$lo – $hi';
  }

  String get _displayName {
    // basic_chest → "Basic Chest"
    return chestId
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final coinLo = _readInt('coin_min');
    final coinHi = _readInt('coin_max');
    final gemLo = _readInt('gem_min');
    final gemHi = _readInt('gem_max');
    final jetChance = _readDouble('jet_drop_chance');
    final jetId =
        _config['jet_id'] is String ? _config['jet_id'] as String : null;
    final bonusCoinsForNoJet = _readInt('bonus_coins_in_place_of_jet');

    return Dialog(
      backgroundColor: AppColors.surfaceBlack,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 0.7,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.asset(
                    'assets/ui/icon_$chestId.png',
                    fit: BoxFit.contain,
                    errorBuilder: AssetPlaceholder.image(
                      color: AppColors.amber,
                      label: chestId,
                      borderRadius: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Possible rewards',
                        style: TextStyle(
                          color: AppColors.amber.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (coinHi > 0)
              _RewardRangeRow(
                icon: 'assets/ui/icon_coin.png',
                fallback: 'c',
                amount: _formatRange(coinLo, coinHi),
                label: 'Coins',
                tint: AppColors.amber,
              ),
            if (gemHi > 0) ...[
              const SizedBox(height: 8),
              _RewardRangeRow(
                icon: 'assets/ui/icon_gem.png',
                fallback: 'g',
                amount: _formatRange(gemLo, gemHi),
                label: 'Gems',
                tint: const Color(0xFF7BB8FF),
              ),
            ],
            if (jetId != null && jetChance > 0) ...[
              const SizedBox(height: 8),
              _RewardRangeRow(
                icon: 'assets/jets/jet_player.png',
                fallback: 'j',
                amount: '${(jetChance * 100).toStringAsFixed(0)}%',
                label: 'Chance: $jetId',
                tint: AppColors.greenLight,
              ),
            ],
            if (bonusCoinsForNoJet > 0) ...[
              const SizedBox(height: 8),
              _RewardRangeRow(
                icon: 'assets/ui/icon_coin.png',
                fallback: 'c',
                amount: '+$bonusCoinsForNoJet',
                label: 'Bonus if no jet',
                tint: AppColors.amber,
              ),
            ],
            const SizedBox(height: 16),
            AppButton.primary(
              label: 'OK',
              height: 44,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRangeRow extends StatelessWidget {
  final String icon;
  final String fallback;
  final String amount;
  final String label;
  final Color tint;
  const _RewardRangeRow({
    required this.icon,
    required this.fallback,
    required this.amount,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0a1a0a),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.6),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: Image.asset(
              icon,
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: tint,
                label: fallback,
                borderRadius: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: TextStyle(
              color: tint,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC0DD97),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adapter: typed [DailyRewardDay] → legacy-shaped map for the
/// `_parseRewards` / `_RewardRow` chain, which still reads raw
/// `coin` / `gem` / `chest` / `jet` / `jet_fallback` keys. Honours the
/// new `week_cap` rule so weeks past the cap repeat the capped week.
Map<String, dynamic>? _dailyRewardLegacyMap(int week, int day) {
  final rcs = RemoteConfigService.I;
  final cap = rcs.dailyReward.weekCap;
  final cappedWeek = week > cap ? cap : week;
  final entry = rcs.dailyReward.dayFor(week: cappedWeek, dayOfWeek: day);
  if (entry == null) return null;
  return <String, dynamic>{
    'coin': entry.coinPrize,
    'gem': entry.gemPrize,
    'chest': entry.chestType,
    'jet': entry.jetType,
    'jet_fallback': entry.jetFallback,
  };
}
