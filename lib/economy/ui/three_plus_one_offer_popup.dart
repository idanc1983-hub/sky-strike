import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/remote_config_service.dart';
import '../../shared/theme/app_colors.dart';
import '../services/offer_reward_parser.dart';
import 'popup_bg_view.dart';
import 'reward_chips.dart';

/// "1+2" / "1+3" offer popup — single paid slot plus 2 free unlock slots.
///
/// Data-driven: reads `monetization__popup_config__v1.offers.<assetId>`
/// for display_name / popup_bg / cycle, and
/// `monetization__offers_1_3__v1.offers.<assetId>` for the 3 slots.
///
/// Background art is resolved via [PopupBgView] — when the key has no
/// registered asset yet, a rich dev placeholder renders so the popup is
/// fully testable while art is pending.
class ThreePlusOneOfferPopup extends StatefulWidget {
  /// Monetization asset id, e.g. `fto`, `first_purchase`, `1+2_ironsky`.
  final String assetId;

  const ThreePlusOneOfferPopup({super.key, required this.assetId});

  static Future<void> show(BuildContext context, {required String assetId}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => ThreePlusOneOfferPopup(assetId: assetId),
    );
  }

  @override
  State<ThreePlusOneOfferPopup> createState() => _ThreePlusOneOfferPopupState();
}

class _ThreePlusOneOfferPopupState extends State<ThreePlusOneOfferPopup> {
  static const double _aspect = 862 / 1824; // portrait popup aspect

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
    final OnePlusTwoOffer? offer = rcs.monetization.templates.onePlusTwo
        .cast<OnePlusTwoOffer?>()
        .firstWhere((o) => o?.assetId == widget.assetId, orElse: () => null);
    final slots = _readSlots(offer);

    final displayName = config?.displayName ?? widget.assetId;
    final popupBg = config?.popupBg;
    final cycle = config?.triggerChallengeId;
    final isIntro = config?.isIntro ?? false;

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
            // Body content
            LayoutBuilder(builder: (ctx, constraints) {
              return Positioned(
                top: constraints.maxHeight * 0.17,
                bottom: constraints.maxHeight * 0.04,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Header(displayName: displayName, isIntro: isIntro),
                    _SlotGrid(slots: slots),
                    Column(
                      children: [
                        _BuyRow(slots: slots),
                        const SizedBox(height: 10),
                        _CountdownLabel(remaining: _remaining),
                      ],
                    ),
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

  static List<_SlotData> _readSlots(OnePlusTwoOffer? offer) {
    if (offer == null) return const [];
    return offer.slots
        .map<_SlotData>((s) => _SlotData(
              rewards: OfferRewardParser.parse(s.reward),
              priceUsd: s.priceUsd,
              isFree: s.isFree,
              rawReward: s.reward ?? '',
            ))
        .toList(growable: false);
  }
}

class _SlotData {
  final List<OfferRewardItem> rewards;
  final double? priceUsd;
  final bool isFree;
  final String rawReward;
  const _SlotData({
    required this.rewards,
    required this.priceUsd,
    required this.isFree,
    required this.rawReward,
  });
  factory _SlotData.empty() => const _SlotData(
        rewards: [],
        priceUsd: null,
        isFree: false,
        rawReward: '',
      );
  bool get isPaid => priceUsd != null;
}

class _Header extends StatelessWidget {
  final String displayName;
  final bool isIntro;
  const _Header({required this.displayName, required this.isIntro});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          displayName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.amberLight,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            height: 1.1,
            shadows: [
              Shadow(
                color: Color(0xCC000000),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isIntro ? 'WELCOME PILOT' : 'BUY 1 & GET 2 FREE',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            shadows: [
              Shadow(
                color: Color(0xCC000000),
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlotGrid extends StatelessWidget {
  final List<_SlotData> slots;
  const _SlotGrid({required this.slots});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Text(
        'No offer slots configured',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < slots.length; i++) ...[
            Expanded(child: _SlotColumn(slot: slots[i])),
            if (i < slots.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.add, color: AppColors.amber, size: 18),
              ),
          ],
        ],
      ),
    );
  }
}

class _SlotColumn extends StatelessWidget {
  final _SlotData slot;
  const _SlotColumn({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: slot.isPaid
            ? const Color(0xFF173404).withValues(alpha: 0.85)
            : AppColors.surfaceDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: slot.isPaid ? AppColors.greenLight : AppColors.amber,
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slot.rewards.isEmpty)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                slot.rawReward.isEmpty ? '—' : slot.rawReward,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            )
          else
            for (int i = 0; i < slot.rewards.length; i++) ...[
              RewardChip(item: slot.rewards[i]),
              if (i < slot.rewards.length - 1) const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }
}

class _BuyRow extends StatelessWidget {
  final List<_SlotData> slots;
  const _BuyRow({required this.slots});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < slots.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _SlotButton(slot: slots[i])),
        ],
      ],
    );
  }
}

class _SlotButton extends StatelessWidget {
  final _SlotData slot;
  const _SlotButton({required this.slot});

  @override
  Widget build(BuildContext context) {
    if (slot.isPaid) {
      return Container(
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6FAD1F), AppColors.green],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.greenLight, width: 0.8),
        ),
        alignment: Alignment.center,
        child: Text(
          '\$${slot.priceUsd!.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber, width: 0.6),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'FREE',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.lock, color: AppColors.amber, size: 14),
        ],
      ),
    );
  }
}

class _CountdownLabel extends StatelessWidget {
  final Duration remaining;
  const _CountdownLabel({required this.remaining});

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPersistent = remaining.inSeconds <= 0;
    return Text(
      isPersistent ? 'Limited time' : 'Ends in ${_format(remaining)}',
      style: const TextStyle(
        color: AppColors.greenPale,
        fontSize: 13,
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
        child: const Icon(
          Icons.close,
          color: AppColors.amberLight,
          size: 16,
        ),
      ),
    );
  }
}
