import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/economy_constants.dart';
import '../constants/power_up_catalog.dart';
import '../state/economy_state.dart';
import 'slot_picker_overlay.dart';

/// Between-wave popup that lets the player resolve queued pickups. One
/// card per queued entry — independent ADD/DISCARD/BUY-SLOT-4 actions.
/// See GDD §2.7.1.
class PickupOverflowPopup extends StatelessWidget {
  const PickupOverflowPopup({super.key});

  /// Shows the popup as a modal dialog. Returns when the player resolves
  /// or dismisses (queue persists if dismissed).
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PickupOverflowPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EconomyState>(
      builder: (ctx, economy, _) {
        final queue = economy.pickupQueue;
        if (queue.isEmpty) {
          // Auto-close once queue empties — keeps the dialog from
          // dangling after the last card is resolved.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          });
          return const SizedBox.shrink();
        }
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amber, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${queue.length} new power-up${queue.length == 1 ? '' : 's'} dropped this wave',
                        style: AppTypography.title.copyWith(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.greenLabel),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < queue.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PickupCard(queueIndex: i, powerUpId: queue[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PickupCard extends StatelessWidget {
  final int queueIndex;
  final String powerUpId;

  const _PickupCard({required this.queueIndex, required this.powerUpId});

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final showSlot4Cta = economy.canBuySlot4WithGems();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Image.asset(
              PowerUpCatalog.slotIcon(powerUpId),
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.green,
                label: powerUpId,
                borderRadius: 6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  PowerUpCatalog.displayName[powerUpId] ?? powerUpId,
                  style: AppTypography.bodyPale.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  PowerUpCatalog.isCollectible[powerUpId] == true
                      ? 'Collectible'
                      : 'Instant',
                  style: AppTypography.label,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _CardButton(
                      label: 'ADD',
                      color: AppColors.green,
                      onTap: () => _handleAdd(context, economy),
                    ),
                    _CardButton(
                      label: 'DISCARD',
                      color: AppColors.amberDark,
                      onTap: () =>
                          economy.discardQueuedPickup(queueIndex),
                    ),
                    if (showSlot4Cta)
                      _CardButton(
                        label:
                            'BUY SLOT 4 — ${EconomyConstants.loadoutSlot4GemShortcutCost}💎',
                        color: AppColors.amber,
                        labelColor: Colors.black,
                        onTap: () => _handleBuySlot4(context, economy),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAdd(BuildContext context, EconomyState economy) async {
    final slot = await SlotPickerOverlay.show(
      context,
      trayPowerUps: economy.activeLoadout.trayPowerUps,
      unlockedSlotCount: economy.unlockedLoadoutSlots,
    );
    if (slot != null) {
      economy.resolveQueuedPickupToSlot(
        queueIndex: queueIndex,
        slotIndex: slot,
      );
    }
  }

  Future<void> _handleBuySlot4(
    BuildContext context,
    EconomyState economy,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Unlock Slot 4?', style: AppTypography.title),
        // ignore: prefer_const_constructors
        content: Text(
          'Unlock Slot 4 instantly for ${EconomyConstants.loadoutSlot4GemShortcutCost} gems?',
          style: AppTypography.bodyPale,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      economy.buySlot4WithGemsAndSeat(powerUpId);
    }
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? labelColor;
  final VoidCallback onTap;

  const _CardButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: labelColor ?? Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
