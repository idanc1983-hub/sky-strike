import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Sky Strike's shared button system.
///
/// Each variant maps to one slot in the redesign's colour-as-language
/// system:
///
/// | Variant                | Visual                                   | Used for                                                |
/// |------------------------|------------------------------------------|---------------------------------------------------------|
/// | [AppButton.primary]    | solid green                              | Launch Mission, Resume, Restart, Next Stage/Biome, Claim |
/// | [AppButton.rewardedAd] | solid amber                              | Watch Ad - Free Revive, Watch Ad - 2x Reward            |
/// | [AppButton.secondary]  | dark fill + amber border + amber text    | Home, Abort Mission, neutral secondary                  |
/// | [AppButton.gem]        | dark fill + purple border + purple text  | Revive - 10x💎 (gem-priced)                             |
class AppButton extends StatelessWidget {
  static const Color _gemPurple = Color(0xFFB59BFF);
  static const Color _gemPurpleBorder = Color(0xFF7E63E6);
  static const Color _rewardedAdText = Color(0xFF1A0F00);

  final _Variant _variant;
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final double height;
  final bool expand;

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.height = 56,
    this.expand = true,
  }) : _variant = _Variant.primary;

  const AppButton.rewardedAd({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.height = 56,
    this.expand = true,
  }) : _variant = _Variant.rewardedAd;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.height = 56,
    this.expand = true,
  }) : _variant = _Variant.secondary;

  const AppButton.gem({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.height = 56,
    this.expand = true,
  }) : _variant = _Variant.gem;

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(_variant);
    final disabled = onPressed == null;
    final decoration = BoxDecoration(
      color: s.fill,
      border: s.borderColor == null
          ? null
          : Border.all(color: s.borderColor!, width: 1),
      borderRadius: BorderRadius.circular(12),
      boxShadow: s.glow == null
          ? null
          : [
              BoxShadow(
                color: s.glow!.withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
    );

    final body = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, color: s.textColor, size: 22),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            color: s.textColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    final button = Container(
      height: height,
      alignment: Alignment.center,
      decoration: decoration,
      child: body,
    );

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : onPressed,
        child: button,
      ),
    );
  }

  _ButtonStyle _styleFor(_Variant v) {
    switch (v) {
      case _Variant.primary:
        return const _ButtonStyle(
          fill: AppColors.green,
          borderColor: AppColors.greenLight,
          textColor: Colors.white,
          glow: AppColors.green,
        );
      case _Variant.rewardedAd:
        return const _ButtonStyle(
          fill: AppColors.amber,
          borderColor: null,
          textColor: _rewardedAdText,
          glow: null,
        );
      case _Variant.secondary:
        return _ButtonStyle(
          fill: AppColors.surfaceBlack,
          borderColor: AppColors.amber.withValues(alpha: 0.7),
          textColor: AppColors.amber,
          glow: null,
        );
      case _Variant.gem:
        return const _ButtonStyle(
          fill: AppColors.surfaceBlack,
          borderColor: _gemPurpleBorder,
          textColor: _gemPurple,
          glow: null,
        );
    }
  }
}

enum _Variant { primary, rewardedAd, secondary, gem }

class _ButtonStyle {
  final Color fill;
  final Color? borderColor;
  final Color textColor;
  final Color? glow;

  const _ButtonStyle({
    required this.fill,
    required this.borderColor,
    required this.textColor,
    required this.glow,
  });
}
