import 'package:flutter/material.dart';

import '../../config/remote_config_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';

/// Lightweight "what's inside this chest" popup. Reads the chest's RC
/// definition (coin range, gem range, jet drop) and renders it as a
/// read-only summary so the player can see the potential rewards
/// without opening the chest.
///
/// Project rule: every chest icon shown anywhere in the game should be
/// tappable and open this popup — keep parity across screens.
class ChestContentsPopup extends StatelessWidget {
  final String chestId;
  final String chestAsset;
  final String chestLabel;

  const ChestContentsPopup({
    super.key,
    required this.chestId,
    required this.chestAsset,
    required this.chestLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required String chestId,
    required String chestAsset,
    required String chestLabel,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => ChestContentsPopup(
        chestId: chestId,
        chestAsset: chestAsset,
        chestLabel: chestLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final def = RemoteConfigService.instance.chests[chestId];
    final coinMin = _intFrom(def, 'coin_min');
    final coinMax = _intFrom(def, 'coin_max');
    final gemMin = _intFrom(def, 'gem_min');
    final gemMax = _intFrom(def, 'gem_max');
    final jetChance = _doubleFrom(def, 'jet_drop_chance');
    final jetId = (def is Map && def['jet_id'] is String)
        ? def['jet_id'] as String
        : null;
    final hasJet = jetId != null && jetId.isNotEmpty && jetChance > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.amber, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderRow(
              title: '$chestLabel Chest',
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 96,
              height: 96,
              child: Image.asset(
                chestAsset,
                errorBuilder: AssetPlaceholder.image(
                  color: AppColors.amber,
                  label: 'chest',
                  borderRadius: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'POSSIBLE REWARDS',
              style: TextStyle(
                color: AppColors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            if (coinMax > 0)
              _RewardLine(
                asset: 'assets/ui/icon_coin.png',
                label: _rangeLabel(coinMin, coinMax),
              ),
            if (gemMax > 0) ...[
              const SizedBox(height: 8),
              _RewardLine(
                asset: 'assets/ui/icon_gem.png',
                label: _rangeLabel(gemMin, gemMax),
              ),
            ],
            if (hasJet) ...[
              const SizedBox(height: 8),
              _RewardLine(
                asset: 'assets/ui/jets/icon_jet_generic.png',
                label:
                    '$jetId · ${(jetChance * 100).toStringAsFixed(0)}% chance',
              ),
            ],
            if (coinMax == 0 && gemMax == 0 && !hasJet)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No rewards configured.',
                  style: TextStyle(color: AppColors.amberLight, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _rangeLabel(int min, int max) {
    if (min == max) return '$min';
    return '$min – $max';
  }

  int _intFrom(dynamic def, String key) {
    if (def is! Map) return 0;
    final v = def[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  double _doubleFrom(dynamic def, String key) {
    if (def is! Map) return 0.0;
    final v = def[key];
    if (v is num) return v.toDouble();
    return 0.0;
  }
}

class _HeaderRow extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  const _HeaderRow({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceDark,
              border: Border.all(color: AppColors.amber, width: 0.8),
            ),
            child: const Icon(
              Icons.close,
              color: AppColors.amberLight,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _RewardLine extends StatelessWidget {
  final String asset;
  final String label;
  const _RewardLine({required this.asset, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Image.asset(
            asset,
            errorBuilder: AssetPlaceholder.image(
              color: AppColors.amber,
              label: 'rwd',
              borderRadius: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
