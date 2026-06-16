import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/iap_catalog.dart';
import '../services/iap_service.dart';
import '../state/economy_state.dart';

/// Contextual 3-pack IAP upsell triggered by an insufficient-coins event
/// during the pre-mission flow (GDD §2.10 "Coins Offer").
class CoinsOfferPopup extends StatelessWidget {
  const CoinsOfferPopup({super.key});

  /// Shows the popup as a modal bottom sheet. Returns the productId of
  /// the purchased pack on success, `null` on dismissal.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      builder: (_) => const CoinsOfferPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/ui/popup_coins_offer_banner.png',
              fit: BoxFit.cover,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amber,
                label: 'coins_offer_banner',
                borderRadius: 8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final id in IapCatalog.contextualCoinPackIds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CoinPackCard(productId: id),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'NO THANKS, LAUNCH AS IS',
              style: TextStyle(color: AppColors.greenLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPackCard extends StatefulWidget {
  final String productId;
  const _CoinPackCard({required this.productId});

  @override
  State<_CoinPackCard> createState() => _CoinPackCardState();
}

class _CoinPackCardState extends State<_CoinPackCard> {
  bool _busy = false;

  Future<void> _buy() async {
    if (_busy) return;
    setState(() => _busy = true);
    final economy = context.read<EconomyState>();
    final outcome = await economy.purchaseIap(widget.productId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome.result == IapPurchaseResult.success) {
      Navigator.of(context).pop(widget.productId);
    } else if (outcome.result == IapPurchaseResult.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase failed${outcome.errorMessage != null ? ': ${outcome.errorMessage}' : ''}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coins = IapCatalog.coinPackCoins[widget.productId] ?? 0;
    final price = IapCatalog.usdPrice[widget.productId] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/ui/icon_coin.png',
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amber,
                label: 'coins',
                borderRadius: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  IapCatalog.displayName[widget.productId] ?? widget.productId,
                  style: AppTypography.bodyPale.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$coins coins',
                  style: AppTypography.bodyPale,
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: _busy ? null : _buy,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('\$${price.toStringAsFixed(2)}'),
          ),
        ],
      ),
    );
  }
}
