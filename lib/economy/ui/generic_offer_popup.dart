import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/remote_config_service.dart';
import '../../shared/theme/app_colors.dart';
import '../services/iap_service.dart';
import '../services/offer_reward_parser.dart';
import '../services/offer_state_store.dart';
import '../state/economy_state.dart';
import 'offer_grant.dart';
import 'offer_popup_chrome.dart';
import 'popup_bg_view.dart';

/// "Generic" bundle popup — single price, 4 fixed rewards in a row,
/// cosmetic discount badge picked once per sale instance.
///
/// All copy / numbers driven from Remote Config:
///   - `monetization.configs.<asset>` → display_name, popup_bg,
///     duration_hours
///   - `monetization.templates.generic.<asset>` → rewards[], price
///
/// The 70/75/80% discount badge is purely visual — the displayed price
/// is the RC price unchanged. See [OfferStateStore.discountFor] for the
/// roll-once-per-instance contract.
class GenericOfferPopup extends StatefulWidget {
  final String assetId;
  const GenericOfferPopup({super.key, required this.assetId});

  static Future<void> show(BuildContext context, {required String assetId}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (_) => GenericOfferPopup(assetId: assetId),
    );
  }

  @override
  State<GenericOfferPopup> createState() => _GenericOfferPopupState();
}

class _GenericOfferPopupState extends State<GenericOfferPopup> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  int _discountPct = 70;
  bool _purchased = false;

  @override
  void initState() {
    super.initState();
    final cfg = RemoteConfigService.I.monetization
        .configByAssetName(widget.assetId);
    final hours = cfg?.duration.hours;
    if (hours != null && hours > 0) {
      _remaining = Duration(hours: hours);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_remaining.inSeconds <= 0) {
          _ticker?.cancel();
          _ticker = null;
          return;
        }
        setState(() => _remaining -= const Duration(seconds: 1));
      });
    }
    _loadDiscount();
  }

  Future<void> _loadDiscount() async {
    final pct = await OfferStateStore.instance.discountFor(widget.assetId);
    if (!mounted) return;
    setState(() => _discountPct = pct);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = RemoteConfigService.I.monetization;
    final cfg = mc.configByAssetName(widget.assetId);
    final displayName =
        (cfg?.displayName.isNotEmpty ?? false) ? cfg!.displayName : widget.assetId;
    final popupBg = cfg?.popupBg;
    final cycle = cfg?.triggerChallengeId;

    final offer = mc.templates.generic
        .cast<GenericOffer?>()
        .firstWhere((o) => o?.assetId == widget.assetId, orElse: () => null);
    final rewards = _parseRewards(offer?.rewards);
    final priceUsd = offer?.price ?? 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.fromLTRB(14, 56, 14, 90),
      child: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: PopupBgView(
                popupBgKey: popupBg,
                displayName: displayName,
                cycle: cycle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Title(displayName: displayName),
                  const SizedBox(height: 20),
                  _DiscountBadge(percent: _discountPct),
                  const SizedBox(height: 14),
                  _RewardsBox(rewards: rewards),
                  const Spacer(),
                  OfferCta(
                    label: _purchased
                        ? 'CLAIMED'
                        : (priceUsd > 0
                            ? '\$${priceUsd.toStringAsFixed(2)}'
                            : '\$\$\$'),
                    claimed: _purchased,
                    height: 54,
                    onTap: (priceUsd <= 0 || _purchased)
                        ? null
                        : () => _handlePurchase(context, cfg?.productId, rewards),
                  ),
                  const SizedBox(height: 16),
                  if (_remaining > Duration.zero)
                    Center(child: OfferCountdown(remaining: _remaining)),
                ],
              ),
            ),
            Positioned(
              top: -44,
              left: -2,
              child: OfferCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Starts the platform purchase for this offer. The rewards are applied
  /// only inside [EconomyState.purchaseProduct]'s success callback, after
  /// StoreKit/Play confirms a completed transaction — never on tap.
  Future<void> _handlePurchase(
    BuildContext context,
    String? productId,
    List<OfferRewardItem> rewards,
  ) async {
    if (_purchased) return;
    final messenger = ScaffoldMessenger.of(context);
    if (productId == null || productId.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No store product configured for ${widget.assetId}'),
        ),
      );
      return;
    }
    final economy = context.read<EconomyState?>();
    if (economy == null) return;
    final outcome = await economy.purchaseProduct(
      productId,
      onConfirmed: () {
        final ungranted = OfferGrant.apply(economy, rewards);
        if (ungranted.isNotEmpty) {
          // Unresolved tokens (unknown / biome_chest_match) — surface the
          // gap rather than silently dropping them.
          debugPrint(
            '[offer] ${widget.assetId}: ungranted reward tokens $ungranted',
          );
        }
      },
    );
    if (!mounted) return;
    switch (outcome.result) {
      case IapPurchaseResult.success:
        setState(() => _purchased = true);
        break;
      case IapPurchaseResult.cancelled:
        break;
      case IapPurchaseResult.failed:
      case IapPurchaseResult.productUnknown:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Purchase failed: ${outcome.errorMessage ?? outcome.result.name}',
            ),
          ),
        );
        break;
    }
  }

  static List<OfferRewardItem> _parseRewards(List<String>? raw) {
    if (raw == null) return const [];
    final out = <OfferRewardItem>[];
    for (final r in raw) {
      out.addAll(OfferRewardParser.parse(r));
    }
    return out;
  }
}

class _Title extends StatelessWidget {
  final String displayName;
  const _Title({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          displayName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            height: 1.05,
            shadows: [
              Shadow(
                color: Color(0xCC000000),
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'LIMITED',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  final int percent;
  const _DiscountBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F0CD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.greenLight, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium,
                color: AppColors.amber, size: 18),
            const SizedBox(width: 6),
            Text(
              '$percent% OFF',
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardsBox extends StatelessWidget {
  final List<OfferRewardItem> rewards;
  const _RewardsBox({required this.rewards});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber, width: 0.8),
      ),
      child: rewards.isEmpty
          ? const SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  'No rewards configured',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final r in rewards)
                  Expanded(child: Center(child: OfferRewardChip(item: r, iconSize: 44))),
              ],
            ),
    );
  }
}
