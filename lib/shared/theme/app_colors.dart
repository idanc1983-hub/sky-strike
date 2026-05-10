import 'package:flutter/material.dart';

/// Sky Strike palette constants.
///
/// These are the canonical values used across home, shop, and game screens.
/// Theme-specific accents (Halloween, Whale, Comeback) live on the bundle's
/// own [BundleTheme] record and are parsed at runtime from JSON.
class AppColors {
  AppColors._();

  // Primary greens (mission/CTA)
  static const Color green = Color(0xFF3B6D11);
  static const Color greenLight = Color(0xFF97C459);
  static const Color greenPale = Color(0xFFC0DD97);
  static const Color greenDeep = Color(0xFF0a1a0a);
  static const Color greenLabel = Color(0xFF639922);
  static const Color greenTrack = Color(0xFF0d1f0d);

  // Amber (operation/event accents)
  static const Color amber = Color(0xFFEF9F27);
  static const Color amberDark = Color(0xFF854F0B);
  static const Color amberLight = Color(0xFFFAC775);

  // Surfaces
  static const Color surfaceDark = Color(0xFF050F05);
  static const Color surfaceBlack = Color(0xFF040C04);
  static const Color cardBg = Color(0xFF0a1a0a);

  // Status
  static const Color warning = Color(0xFFEF9F27);
  static const Color danger = Color(0xFFD23B3B);

  /// Parses `#RRGGBB` or `#AARRGGBB` into a [Color]. Returns [fallback] on
  /// parse failure — never throws, since hex strings come from server JSON.
  static Color fromHex(String hex, {Color fallback = greenDeep}) {
    var s = hex.replaceFirst('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return fallback;
    final v = int.tryParse(s, radix: 16);
    return v == null ? fallback : Color(v);
  }
}
