import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/economy_constants.dart';
import '../constants/power_up_catalog.dart';

/// Tap-to-replace tray slot picker. Used by the pickup overflow popup
/// when the player chooses ADD TO TRAY.
class SlotPickerOverlay extends StatelessWidget {
  /// The active loadout's tray cells (length =
  /// [EconomyConstants.trayPowerUpCount]).
  final List<String?> trayPowerUps;

  /// How many of those cells the player owns.
  final int unlockedSlotCount;

  const SlotPickerOverlay({
    super.key,
    required this.trayPowerUps,
    required this.unlockedSlotCount,
  });

  /// Shows the picker as a modal dialog. Returns the selected slot index,
  /// or `null` on cancel.
  static Future<int?> show(
    BuildContext context, {
    required List<String?> trayPowerUps,
    required int unlockedSlotCount,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => SlotPickerOverlay(
        trayPowerUps: trayPowerUps,
        unlockedSlotCount: unlockedSlotCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Replace which slot?', style: AppTypography.title),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List<Widget>.generate(
                EconomyConstants.trayPowerUpCount,
                (i) => _SlotCell(
                  index: i,
                  occupant: trayPowerUps[i],
                  owned: i < unlockedSlotCount,
                  onTap: i < unlockedSlotCount
                      ? () => Navigator.of(context).pop(i)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.greenLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  final int index;
  final String? occupant;
  final bool owned;
  final VoidCallback? onTap;

  const _SlotCell({
    required this.index,
    required this.occupant,
    required this.owned,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: owned ? 1.0 : 0.35,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: owned ? AppColors.green : AppColors.greenTrack,
              width: 1,
            ),
          ),
          child: occupant == null
              ? Center(
                  child: Text(
                    '${index + 1}',
                    style: AppTypography.bodyPale,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    PowerUpCatalog.slotIcon(occupant!),
                    fit: BoxFit.contain,
                    errorBuilder: AssetPlaceholder.image(
                      color: AppColors.green,
                      label: occupant!,
                      borderRadius: 4,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
