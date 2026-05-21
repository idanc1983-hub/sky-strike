import 'package:flutter/material.dart';

/// Richer dev placeholder shown while a `popup_bg` art asset is missing.
/// Renders a biome-tinted box with diagonal stripes + a labelled card
/// showing exactly which monetization configuration the popup is reading,
/// so non-art testing of the v2 economy stays unambiguous.
///
/// See /Remote Config/CLIENT_RUNTIME_SPEC.md Runtime 3.
class DevPopupBgPlaceholder extends StatelessWidget {
  /// The `popup_bg` key from monetization configurations (e.g.
  /// `bg_ironsky_metal`).
  final String popupBgKey;

  /// `display_name` from the monetization asset row (e.g. "Iron Skies
  /// Bundle"). Optional — omitted in unit tests.
  final String? displayName;

  /// `trigger_challenge_id` from the asset row (e.g. `iron_skies`).
  /// Optional. Drives the placeholder tint so cycles are visually
  /// distinct in QA screenshots.
  final String? cycle;

  /// Corner radius — match the surrounding popup chrome.
  final double borderRadius;

  const DevPopupBgPlaceholder({
    super.key,
    required this.popupBgKey,
    this.displayName,
    this.cycle,
    this.borderRadius = 18,
  });

  static const Map<String, Color> _cycleTint = {
    'iron_skies':  Color(0xFF4E5763),
    'last_stand':  Color(0xFF5A3F4A),
    'golden_sky':  Color(0xFF705016),
    'star_ascent': Color(0xFF2E2A55),
    'new_players': Color(0xFF2F5A3A),
    'none':        Color(0xFF3A3A3A),
  };

  Color get _tint => _cycleTint[cycle] ?? const Color(0xFF3A3A3A);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: _tint),
          CustomPaint(painter: _DiagonalStripePainter()),
          // Center: the data the popup is reading from remote config.
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE082), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayName != null && displayName!.isNotEmpty) ...[
                      Text(
                        displayName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _kv('popup_bg', popupBgKey),
                    if (cycle != null && cycle!.isNotEmpty) _kv('cycle', cycle!),
                    const SizedBox(height: 6),
                    const Text(
                      'art pending — see POPUP_BG_ASSETS.md',
                      style: TextStyle(
                        color: Color(0xFFFFE082),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Top-right "DEV" badge.
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'DEV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11),
            children: [
              TextSpan(
                text: '$k: ',
                style: const TextStyle(color: Color(0xFFB0BEC5)),
              ),
              TextSpan(
                text: v,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      );
}

class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 8;
    const step = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
