import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/iap_catalog.dart';
import '../services/iap_service.dart';
import '../state/economy_state.dart';

/// Triggered when the player tries to buy something in the shop (or
/// chest preview) and doesn't have enough coins. Pitches the single
/// hardcoded "full experience" coin pack — 10k coins + bonus power-ups
/// + a handful of gems — at the lowest IAP tier so the close button
/// isn't the obvious choice. Returns the productId on a successful
/// purchase, `null` on dismissal.
class NotEnoughCoinsPopup extends StatelessWidget {
  const NotEnoughCoinsPopup({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => const NotEnoughCoinsPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.amber, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'NOT ENOUGH COINS',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close,
                      color: AppColors.greenLabel, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Stock up for the full experience — chests, power-ups, '
              'the works.',
              style: AppTypography.bodyPale,
            ),
            const SizedBox(height: 14),
            const _FullExperiencePack(),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'MAYBE LATER',
                style: TextStyle(color: AppColors.greenLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullExperiencePack extends StatefulWidget {
  const _FullExperiencePack();

  @override
  State<_FullExperiencePack> createState() => _FullExperiencePackState();
}

class _FullExperiencePackState extends State<_FullExperiencePack> {
  static const String _id = IapCatalog.fullExperienceCoinPackId;
  bool _busy = false;

  Future<void> _buy() async {
    if (_busy) return;
    setState(() => _busy = true);
    final economy = context.read<EconomyState>();
    final outcome = await economy.purchaseIap(_id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome.result == IapPurchaseResult.success) {
      Navigator.of(context).pop(_id);
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
    final coins = IapCatalog.coinPackCoins[_id] ?? 0;
    final price = IapCatalog.usdPrice[_id] ?? 0;
    final name = IapCatalog.displayName[_id] ?? _id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber, width: 0.8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
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
                  name,
                  style: AppTypography.bodyPale.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$coins coins',
                  style: AppTypography.bodyPale.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: _busy ? null : _buy,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
