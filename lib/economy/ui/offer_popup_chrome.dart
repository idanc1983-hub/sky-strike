import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../services/biome_chest_resolver.dart';
import '../services/day7_reward_resolver.dart';
import '../services/offer_reward_parser.dart';
import '../state/economy_state.dart';
import 'chest_contents_popup.dart';
import 'reward_chips.dart';

/// Shared chrome shared by every monetization popup (Generic / Snake / 1+2).
///
/// Keeps the close button, countdown row, and small text styles aligned
/// across the three templates so player muscle memory carries over.

/// Reward chip that auto-wires the chest-preview tap so monetization
/// popups stay in parity with the daily-reward / challenge screens.
///
/// When [item] is a chest, the icon is tappable and opens
/// [ChestContentsPopup]; for `biome_chest_match` the runtime chest is
/// resolved via [BiomeChestResolver] using the player's current world.
/// All other reward kinds render as a plain [RewardChip].
class OfferRewardChip extends StatelessWidget {
  final OfferRewardItem item;
  final double iconSize;
  const OfferRewardChip({
    super.key,
    required this.item,
    this.iconSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    final isChest = item.kind == OfferRewardKind.chest;
    VoidCallback? onChestTap;
    if (isChest) {
      onChestTap = () {
        final world = context.read<EconomyState>().currentWorld;
        final biome = (world >= 1 && world < kDay7WorldToBiome.length)
            ? kDay7WorldToBiome[world]
            : 'jungle';
        final chestId = BiomeChestResolver.resolve(
          chestId: item.id ?? '',
          currentBiome: biome,
        );
        final dummy = RewardChip(item: item, iconSize: iconSize);
        ChestContentsPopup.show(
          context,
          chestId: chestId,
          chestAsset: dummy.assetPath,
          chestLabel: dummy.label,
        );
      };
    }
    return RewardChip(
      item: item,
      iconSize: iconSize,
      onChestTap: onChestTap,
    );
  }
}

/// Small "X" close button — top-left of every popup per the mocks.
class OfferCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const OfferCloseButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.amber, width: 0.8),
        ),
        child: const Icon(
          Icons.close,
          color: AppColors.amber,
          size: 22,
        ),
      ),
    );
  }
}

/// "Ends in HH:MM:SS" countdown row shown at the bottom of every popup.
class OfferCountdown extends StatelessWidget {
  final Duration remaining;
  const OfferCountdown({super.key, required this.remaining});

  static String format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ends in ${format(remaining)}',
      style: const TextStyle(
        color: AppColors.greenPale,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Solid-green CTA button used for both paid ($price) and free claims.
///
/// State variants per the June 2026 spec ("all boxes always on; only the
/// CTA tells you the sequential state"):
///   - default: bright green tappable button with [label].
///   - [locked]=true: bright green button with a padlock icon replacing
///     the label; non-tappable.
///   - [claimed]=true: dimmed green button with [label] (e.g. "CLAIMED");
///     non-tappable. Stays distinct from [locked] so a player can see
///     where they are in the sequence at a glance.
class OfferCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool locked;
  final bool claimed;
  final double height;

  const OfferCta({
    super.key,
    required this.label,
    required this.onTap,
    this.locked = false,
    this.claimed = false,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = locked || claimed;
    return Opacity(
      opacity: claimed ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.greenLight, width: 0.8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock, color: Colors.white, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
