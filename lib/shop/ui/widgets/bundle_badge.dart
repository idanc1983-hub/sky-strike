import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';

/// Small pill rendered on hero/compact cards: "LIMITED", "NEW",
/// "67% OFF". Border tints to the bundle's theme accent so it reads as
/// a styled element on otherwise dark art.
class BundleBadge extends StatelessWidget {
  final String text;
  final Color accent;

  const BundleBadge({
    super.key,
    required this.text,
    this.accent = AppColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: accent, width: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: AppTypography.badge),
    );
  }
}
