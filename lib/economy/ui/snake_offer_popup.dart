import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/remote_config_service.dart';
import '../../shared/theme/app_colors.dart';
import '../services/offer_reward_parser.dart';
import 'popup_bg_view.dart';
import 'reward_chips.dart';

/// "Snake" 6-slot offer popup. Slots follow the F-F-P-F-P-F pattern —
/// two paid anchors (slots 3 and 5) interleaved with free unlocks.
///
/// Data-driven from `monetization__offers_snake__v1.offers.<assetId>`
/// + `monetization__popup_config__v1.offers.<assetId>`.
class SnakeOfferPopup extends StatefulWidget {
  final String assetId;
  const SnakeOfferPopup({super.key, required this.assetId});

  static Future<void> show(BuildContext context, {required String assetId}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => SnakeOfferPopup(assetId: assetId),
    );
  }

  @override
  State<SnakeOfferPopup> createState() => _SnakeOfferPopupState();
}

class _SnakeOfferPopupState extends State<SnakeOfferPopup> {
  static const double _aspect = 862 / 1824;

  Timer? _ticker;
  Duration _remaining = const Duration(hours: 47, minutes: 59, seconds: 59);

  @override
  void initState() {
    super.initState();
    final config = RemoteConfigService.instance.popupFor(widget.assetId);
    final hours = config?['duration_hours'];
    if (hours is num) {
      _remaining = Duration(seconds: (hours * 3600).round());
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
    final rcs = RemoteConfigService.instance;
    final config = rcs.popupFor(widget.assetId) ?? const <String, dynamic>{};
    final offer = rcs.offersSnake[widget.assetId];

    final displayName = (config['display_name'] as String?) ?? widget.assetId;
    final popupBg = config['popup_bg'] as String?;
    final cycle = config['trigger_challenge_id'] as String?;

    final slots = _readSlots(offer);

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
                top: constraints.maxHeight * 0.13,
                bottom: constraints.maxHeight * 0.04,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Header(displayName: displayName),
                    Expanded(child: _SnakeGrid(slots: slots)),
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

  static List<_SnakeSlot> _readSlots(dynamic offer) {
    if (offer is! Map) return const [];
    final raw = offer['slots'];
    if (raw is! List) return const [];
    return raw.map<_SnakeSlot>((s) {
      if (s is! Map) return _SnakeSlot.empty();
      final r1 = s['reward_1']?.toString();
      final r2 = s['reward_2']?.toString();
      final price = s['price'];
      return _SnakeSlot(
        rewards: [
          ...OfferRewardParser.parse(r1),
          ...OfferRewardParser.parse(r2),
        ],
        priceUsd: price is num ? price.toDouble() : null,
      );
    }).toList(growable: false);
  }
}

class _SnakeSlot {
  final List<OfferRewardItem> rewards;
  final double? priceUsd;
  const _SnakeSlot({required this.rewards, required this.priceUsd});
  factory _SnakeSlot.empty() => const _SnakeSlot(rewards: [], priceUsd: null);
  bool get isPaid => priceUsd != null;
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
        const SizedBox(height: 2),
        const Text(
          'CLAIM IN ORDER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
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

class _SnakeGrid extends StatelessWidget {
  final List<_SnakeSlot> slots;
  const _SnakeGrid({required this.slots});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Text(
          'No snake slots configured',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.82,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          for (int i = 0; i < slots.length; i++)
            _SnakeCell(index: i + 1, slot: slots[i]),
        ],
      ),
    );
  }
}

class _SnakeCell extends StatelessWidget {
  final int index;
  final _SnakeSlot slot;
  const _SnakeCell({required this.index, required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: slot.isPaid
            ? const Color(0xFF173404).withValues(alpha: 0.85)
            : AppColors.surfaceDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: slot.isPaid ? AppColors.greenLight : AppColors.amber,
          width: 0.7,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$index',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: slot.isPaid ? AppColors.green : AppColors.amber,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  slot.isPaid ? 'PAID' : 'FREE',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in slot.rewards) ...[
                      RewardChip(item: r, iconSize: 32),
                      const SizedBox(height: 2),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 22,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: slot.isPaid
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF6FAD1F), AppColors.green],
                    )
                  : null,
              color: slot.isPaid ? null : AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: slot.isPaid ? AppColors.greenLight : AppColors.amber,
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              slot.isPaid
                  ? '\$${slot.priceUsd!.toStringAsFixed(2)}'
                  : 'FREE',
              style: TextStyle(
                color: slot.isPaid ? Colors.white : AppColors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
