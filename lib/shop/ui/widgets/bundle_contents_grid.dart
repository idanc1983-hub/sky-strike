import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/asset_placeholder.dart';
import '../../models/bundle_content.dart';

/// Renders a list of [BundleContent] as a horizontal row of icon stacks.
/// Wraps to a second line when more than [maxPerRow] items are present.
class BundleContentsGrid extends StatelessWidget {
  final List<BundleContent> contents;
  final int maxPerRow;
  final double iconSize;
  final Color accent;

  const BundleContentsGrid({
    super.key,
    required this.contents,
    this.maxPerRow = 4,
    this.iconSize = 40,
    this.accent = AppColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in contents)
          _ContentTile(content: c, size: iconSize, accent: accent),
      ],
    );
  }
}

class _ContentTile extends StatelessWidget {
  final BundleContent content;
  final double size;
  final Color accent;

  const _ContentTile({
    required this.content,
    required this.size,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Image.asset(
              content.iconAsset,
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: accent,
                label: _labelFor(content),
                borderRadius: 4,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '×${content.count}',
            style: AppTypography.bodyPale.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _labelFor(BundleContent c) {
    final id = c.itemId;
    if (id != null && id.isNotEmpty) return id;
    return c.type.jsonValue;
  }
}
