import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../../shared/widgets/dev_popup_bg_placeholder.dart';
import '../services/popup_bg_registry.dart';

/// Drop-in background view for any monetization popup. Resolves the
/// `popup_bg` key from monetization config via [PopupBgRegistry]; falls
/// back to [DevPopupBgPlaceholder] when art has not been uploaded yet.
///
/// Caller is responsible for sizing this with a parent (typically a
/// `Positioned.fill` inside a `Stack`).
class PopupBgView extends StatelessWidget {
  /// `popup_bg` value from `monetization__popup_config__v1.offers.<id>`.
  final String? popupBgKey;

  /// `display_name` from the same config row. Surfaces in the dev
  /// placeholder so testers know which offer they're looking at.
  final String? displayName;

  /// `trigger_challenge_id` from the same row (e.g. `iron_skies`).
  /// Tints the dev placeholder per cycle.
  final String? cycle;

  /// Corner radius — match the surrounding popup chrome.
  final double borderRadius;

  const PopupBgView({
    super.key,
    required this.popupBgKey,
    this.displayName,
    this.cycle,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = PopupBgRegistry.lookup(popupBgKey);
    if (assetPath != null) {
      // Real art is registered. Use Image.asset with a generic
      // AssetPlaceholder fallback in case the file is missing on disk.
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: AssetPlaceholder.image(
            color: AppColors.cardBg,
            label: popupBgKey ?? 'popup_bg',
            borderRadius: borderRadius,
          ),
        ),
      );
    }
    // No art registered yet: rich dev placeholder.
    return DevPopupBgPlaceholder(
      popupBgKey: popupBgKey ?? 'unknown_bg',
      displayName: displayName,
      cycle: cycle,
      borderRadius: borderRadius,
    );
  }
}
