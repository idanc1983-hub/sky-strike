import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/asset_placeholder.dart';
import '../../models/shop_bundle.dart';
import 'bundle_badge.dart';
import 'bundle_contents_grid.dart';
import 'bundle_countdown.dart';
import 'bundle_price_button.dart';

/// Featured bundle card for the carousel. Roughly full-width × 180 px.
class BundleHeroCard extends StatelessWidget {
  final ShopBundle bundle;
  final Future<bool> Function(String bundleId) onPurchase;
  final VoidCallback? onTap;

  const BundleHeroCard({
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
    final percent = bundle.price.percentOff;
    final badgeText = bundle.badgeText ??
        (percent != null ? '$percent% OFF' : null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Banner art (or placeholder)
            Positioned.fill(
              child: Image.asset(
                bundle.theme.bannerAsset,
                fit: BoxFit.cover,
                errorBuilder: AssetPlaceholder.image(
                  color: accent,
                  label: bundle.theme.themeId,
                  borderRadius: 12,
                ),
              ),
            ),
            // Bottom dark overlay for text legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
            // Badge top-left
            if (badgeText != null)
              Positioned(
                top: 10,
                left: 10,
                child: BundleBadge(text: badgeText, accent: accent),
              ),
            // Countdown top-right
            Positioned(
              top: 10,
              right: 10,
              child: BundleCountdown(endsAt: bundle.endsAt),
            ),
            // Title + subtitle bottom-left
            Positioned(
              left: 12,
              right: 140,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bundle.localizationKey,
                    style: AppTypography.heroTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bundle.contentSummary(),
                    style: AppTypography.heroSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  BundleContentsGrid(
                    contents: bundle.contents.take(3).toList(),
                    iconSize: 28,
                    accent: accent,
                  ),
                ],
              ),
            ),
            // Price button bottom-right
            Positioned(
              right: 12,
              bottom: 12,
              child: BundlePriceButton(
                price: bundle.price,
                accent: accent,
                onTap: () => onPurchase(bundle.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
