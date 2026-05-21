import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../services/offer_reward_parser.dart';

/// Renders a single parsed [OfferRewardItem] as a 44x44 icon + amount
/// label. Used across all monetization popups so rewards display the
/// same regardless of offer format.
///
/// Icons are bundled assets at conventional paths. Missing assets fall
/// back to [AssetPlaceholder] so dev builds stay scannable.
class RewardChip extends StatelessWidget {
  final OfferRewardItem item;
  final double iconSize;

  const RewardChip({super.key, required this.item, this.iconSize = 44});

  String get _assetPath {
    switch (item.kind) {
      case OfferRewardKind.coin:
        return 'assets/ui/icon_coin.png';
      case OfferRewardKind.gem:
        return 'assets/ui/icon_gem.png';
      case OfferRewardKind.chest:
        final id = item.id ?? '';
        if (id == OfferRewardParser.biomeChestMatchToken) {
          return 'assets/ui/icon_chest_biome.png';
        }
        return 'assets/ui/icon_${id.isNotEmpty ? id : 'chest_basic'}.png';
      case OfferRewardKind.powerupPack:
        return 'assets/ui/icon_powerup_pack.png';
      case OfferRewardKind.unknown:
        return 'assets/ui/icon_unknown_reward.png';
    }
  }

  String get _label {
    switch (item.kind) {
      case OfferRewardKind.coin:
        return _formatNumber(item.amount);
      case OfferRewardKind.gem:
        return _formatNumber(item.amount);
      case OfferRewardKind.chest:
        return _chestLabel(item.id);
      case OfferRewardKind.powerupPack:
        return '${item.amount}× P-UP';
      case OfferRewardKind.unknown:
        return item.raw;
    }
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return n.toString();
  }

  static String _chestLabel(String? id) {
    if (id == null || id.isEmpty) return 'CHEST';
    if (id == OfferRewardParser.biomeChestMatchToken) return 'BIOME CHEST';
    final stripped = id.replaceAll('_chest', '');
    return stripped.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: Image.asset(
            _assetPath,
            errorBuilder: AssetPlaceholder.image(
              color: AppColors.amber,
              label: item.raw,
              borderRadius: 4,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Color(0xCC000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
