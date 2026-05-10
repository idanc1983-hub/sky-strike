import 'package:flutter/material.dart';

/// Unified placeholder used wherever a real art asset is missing.
///
/// Renders a solid [color] rounded rect filling the parent box, with a tiny
/// "P:label" pill anchored to the top-left corner so missing-asset locations
/// are visually scannable in dev builds.
///
/// Use via [AssetPlaceholder.image]: drops in as the `errorBuilder` of any
/// [Image.asset] / [Image.network] call.
class AssetPlaceholder extends StatelessWidget {
  /// Theme-accent fill color of the placeholder box.
  final Color color;

  /// Short identifier shown in the dev badge (e.g. "halloween_banner").
  final String label;

  /// Corner radius — match the consumer surface to avoid visual jank.
  final double borderRadius;

  /// When true, shows the "P:label" dev badge in the top-left corner. Default true.
  /// Set false in screenshot/golden tests if needed.
  final bool showDevBadge;

  const AssetPlaceholder({
    super.key,
    required this.color,
    required this.label,
    this.borderRadius = 6,
    this.showDevBadge = true,
  });

  /// Returns an [ImageErrorWidgetBuilder] suitable for `Image.asset(...)`'s
  /// `errorBuilder` argument. The placeholder fills whatever box the [Image]
  /// occupies and shows the asset path tail as its label.
  static ImageErrorWidgetBuilder image({
    required Color color,
    required String label,
    double borderRadius = 6,
  }) {
    return (context, error, stackTrace) => AssetPlaceholder(
          color: color,
          label: label,
          borderRadius: borderRadius,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        if (showDevBadge)
          Positioned(
            top: 2,
            left: 2,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'P:$label',
                  style: const TextStyle(
                    color: Color(0xFFFFE082),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
