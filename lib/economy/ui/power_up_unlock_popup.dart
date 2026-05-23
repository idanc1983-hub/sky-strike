import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/power_up_catalog.dart';

/// Full-screen modal that celebrates a newly unlocked power-up.
/// Triggered by [EconomyState.advanceToWorld] when the return list is
/// non-empty.
class PowerUpUnlockPopup extends StatefulWidget {
  final String powerUpId;

  const PowerUpUnlockPopup({super.key, required this.powerUpId});

  /// Shows the popup as a `showDialog` overlay. Returns when the player
  /// taps EQUIP NOW or CONTINUE.
  static Future<String?> show(BuildContext context, String powerUpId) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => PowerUpUnlockPopup(powerUpId: powerUpId),
    );
  }

  @override
  State<PowerUpUnlockPopup> createState() => _PowerUpUnlockPopupState();
}

class _PowerUpUnlockPopupState extends State<PowerUpUnlockPopup> {
  void _dismiss(String result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final name = PowerUpCatalog.displayName[widget.powerUpId] ?? widget.powerUpId;
    final description =
        PowerUpCatalog.shortDescription[widget.powerUpId] ?? '';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Banner art with placeholder fallback.
          AspectRatio(
            aspectRatio: 6,
            child: Image.asset(
              'assets/ui/popup_new_unlock_banner.png',
              fit: BoxFit.cover,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amber,
                label: 'unlock_banner',
                borderRadius: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NEW POWER-UP UNLOCKED!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.amberLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 128,
                  height: 128,
                  child: Image.asset(
                    PowerUpCatalog.slotIcon(widget.powerUpId),
                    fit: BoxFit.contain,
                    errorBuilder: AssetPlaceholder.image(
                      color: AppColors.amber,
                      label: widget.powerUpId,
                      borderRadius: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: AppTypography.title),
                const SizedBox(height: 4),
                Text(description, style: AppTypography.bodyPale),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _dismiss('continue'),
                      child: const Text('CONTINUE',
                          style: TextStyle(color: AppColors.greenLabel)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _dismiss('equip'),
                      child: const Text('EQUIP NOW'),
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
}
