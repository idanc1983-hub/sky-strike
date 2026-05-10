import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/asset_placeholder.dart';
import '../../models/shop_bundle.dart';
import 'bundle_badge.dart';
import 'bundle_contents_grid.dart';
import 'bundle_countdown.dart';
import 'bundle_price_button.dart';

/// Half-width grid card. Roughly 110 px tall.
class BundleCompactCard extends StatelessWidget {
  final ShopBundle bundle;
  final Future<bool> Function(String bundleId) onPurchase;
  final VoidCallback? onTap;

  const BundleCompactCard({
    super.key,
    required this.bundle,
    required this.onPurchase,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.fromHex(
      bundle.theme.accentColorHex,
      fallback: AppColors.green,
    );
    final bg = AppColors.fromHex(
      bundle.theme.backgroundColorHex,
      fallback: AppColors.cardBg,
    );
    final endsSoon =
        bundle.endsAt.difference(DateTime.now()).inHours < 24;
    final percent = bundle.price.percentOff;
    final badgeText =
        bundle.badgeText ?? (percent != null ? '$percent% OFF' : null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Banner background dimmed
            Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: Image.asset(
                  bundle.theme.bannerAsset,
                  fit: BoxFit.cover,
                  errorBuilder: AssetPlaceholder.image(
                    color: accent,
                    label: bundle.theme.themeId,
                    borderRadius: 10,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (badgeText != null)
                        BundleBadge(text: badgeText, accent: accent)
                      else
                        const SizedBox.shrink(),
                      if (endsSoon)
                        BundleCountdown(endsAt: bundle.endsAt),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bundle.localizationKey,
                    style: AppTypography.bodyPale
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  BundleContentsGrid(
                    contents: bundle.contents.take(3).toList(),
                    iconSize: 22,
                    accent: accent,
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: BundlePriceButton(
                      price: bundle.price,
                      accent: accent,
                      onTap: () => onPurchase(bundle.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
