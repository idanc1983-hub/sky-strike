import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Canonical [TextStyle] presets used by shop and other shells.
class AppTypography {
  AppTypography._();

  static const TextStyle title = TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  static const TextStyle heroTitle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle heroSubtitle = TextStyle(
    color: Color(0xFFD8E6C0),
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyPale = TextStyle(
    color: AppColors.greenPale,
    fontSize: 12,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.greenLabel,
    fontSize: 10,
    letterSpacing: 1.2,
  );

  static const TextStyle priceText = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle compareText = TextStyle(
    color: Color(0xFFAAAAAA),
    fontSize: 11,
    decoration: TextDecoration.lineThrough,
  );

  static const TextStyle countdown = TextStyle(
    color: AppColors.amberLight,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle badge = TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  static const TextStyle errorBanner = TextStyle(
    color: AppColors.amberLight,
    fontSize: 11,
  );
}
