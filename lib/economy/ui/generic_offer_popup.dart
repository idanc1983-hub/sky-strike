import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/remote_config_service.dart';
import '../../shared/theme/app_colors.dart';
import '../services/offer_reward_parser.dart';
import 'popup_bg_view.dart';
import 'reward_chips.dart';

/// "Generic" 4-slot offer popup — one bundle, four rewards, single price.
///
/// Data-driven from `monetization__offers_generic__v1.offers.<assetId>`
/// + `monetization__popup_config__v1.offers.<assetId>`.
class GenericOfferPopup extends StatefulWidget {
  final String assetId;
  const GenericOfferPopup({super.key, required this.assetId});

  static Future<void> show(BuildContext context, {required String assetId}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => GenericOfferPopup(assetId: assetId),
    );
  }

  @override
  State<GenericOfferPopup> createState() => _GenericOfferPopupState();
}

class _GenericOfferPopupState extends State<GenericOfferPopup> {
  static const double _aspect = 862 / 1824;

  Timer? _ticker;
  Duration _remaining = const Duration(hours: 47, minutes: 59, seconds: 59);

  @override
  void initState() {
    super.initState();
    final config =
        RemoteConfigService.I.monetization.configByAssetName(widget.assetId);
    final hours = config?.duration.hours;
    if (hours != null) {
      _remaining = Duration(seconds: hours * 3600);
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining = _remaining - const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rcs = RemoteConfigService.I;
    final config = rcs.monetization.configByAssetName(widget.assetId);
    final GenericOffer? offer = rcs.monetization.templates.generic
        .cast<GenericOffer?>()
        .firstWhere((o) => o?.assetId == widget.assetId, orElse: () => null);

    final displayName = config?.displayName ?? widget.assetId;
    final popupBg = config?.popupBg;
    final cycle = config?.triggerChallengeId;

    final rewards = _readRewards(offer);
    final priceUsd = offer?.price;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: AspectRatio(
        aspectRatio: _aspect,
        child: Stack(
          children: [
            Positioned.fill(
              child: PopupBgView(
                popupBgKey: popupBg,
                displayName: displayName,
                cycle: cycle,
              ),
            ),
            LayoutBuilder(builder: (ctx, constraints) {
              return Positioned(
                top: constraints.maxHeight * 0.15,
                bottom: constraints.maxHeight * 0.04,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Header(displayName: displayName),
                    Expanded(child: _RewardGrid(rewards: rewards)),
                    _BuyButton(priceUsd: priceUsd),
                    const SizedBox(height: 8),
                    _CountdownLabel(remaining: _remaining),
                  ],
                ),
              );
            }),
            Positioned(
              top: 8,
              right: 8,
              child: _CloseButton(onTap: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }

  static List<OfferRewardItem> _readRewards(GenericOffer? offer) {
    if (offer == null) return const [];
    final out = <OfferRewardItem>[];
    for (final r in offer.rewards) {
      out.addAll(OfferRewardParser.parse(r));
    }
    return out;
  }
}

class _Header extends StatelessWidget {
  final String displayName;
  const _Header({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          displayName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.amberLight,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            height: 1.1,
            shadows: [
              Shadow(
                  color: Color(0xCC000000),
                  offset: Offset(0, 2),
                  blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'BUNDLE OFFER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            shadows: [
              Shadow(
                  color: Color(0xCC000000),
                  offset: Offset(0, 1),
                  blurRadius: 3),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardGrid extends StatelessWidget {
  final List<OfferRewardItem> rewards;
  const _RewardGrid({required this.rewards});

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return const Center(
        child: Text(
          'No rewards configured',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          for (final r in rewards)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amber, width: 0.8),
              ),
              child: Center(child: RewardChip(item: r, iconSize: 40)),
            ),
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  final double? priceUsd;
  const _BuyButton({required this.priceUsd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6FAD1F), AppColors.green],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.greenLight, width: 0.8),
      ),
      alignment: Alignment.center,
      child: Text(
        priceUsd != null ? '\$${priceUsd!.toStringAsFixed(2)}' : 'BUY',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CountdownLabel extends StatelessWidget {
  final Duration remaining;
  const _CountdownLabel({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      'Ends in $h:$m:$s',
      style: const TextStyle(
        color: AppColors.greenPale,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceDark,
          border: Border.all(color: AppColors.amber, width: 0.8),
        ),
        child: const Icon(Icons.close,
            color: AppColors.amberLight, size: 16),
      ),
    );
  }
}
