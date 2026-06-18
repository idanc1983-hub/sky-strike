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

/// "1+2" offer popup — 3 vertical slots, sequential progression.
///
/// One paid anchor (slot 1) + two free unlocks (slots 2, 3). The free
/// slots stay dimmed until the paid slot is purchased; FTO and the four
/// per-cycle `1+2_*` offers all use this template.
///
/// RC sources:
///   - `monetization.configs.<asset>` — display_name, popup_bg,
///     duration_hours
///   - `monetization.templates.one_plus_two.<asset>.slots[].{reward,
///     price}` — `reward` is a `+`-separated token list (up to 3
///     rewards), `price` is a number or the literal `"free"`.
///
/// Class name is historical (was originally "1+3"). The public template
/// is 1+2 — kept as-is to avoid churning existing call sites.
class ThreePlusOneOfferPopup extends StatefulWidget {
  final String assetId;
  const ThreePlusOneOfferPopup({super.key, required this.assetId});

  static Future<void> show(BuildContext context, {required String assetId}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (_) => ThreePlusOneOfferPopup(assetId: assetId),
    );
  }

  @override
  State<ThreePlusOneOfferPopup> createState() => _ThreePlusOneOfferPopupState();
}

class _ThreePlusOneOfferPopupState extends State<ThreePlusOneOfferPopup> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  int _claimed = 0;

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
    _loadClaimed();
  }

  Future<void> _loadClaimed() async {
    final n = await OfferStateStore.instance.claimedCount(widget.assetId);
    if (!mounted) return;
    setState(() => _claimed = n);
  }

  Future<void> _claimNext() async {
    final n = await OfferStateStore.instance.incrementClaimed(widget.assetId);
    if (!mounted) return;
    setState(() => _claimed = n);
  }

  /// Acts on the next-in-line slot. The paid anchor (slot 1) runs the
  /// platform purchase and grants only on a confirmed transaction; the two
  /// free unlocks grant immediately. The slot is recorded as claimed only
  /// after its reward is granted — never on tap alone.
  Future<void> _handleSlot(
    BuildContext context,
    String? productId,
    List<_SlotData> slots,
  ) async {
    if (_claimed >= slots.length) return;
    final slot = slots[_claimed];
    final economy = context.read<EconomyState?>();
    if (economy == null) return;

    if (slot.isPaid) {
      final messenger = ScaffoldMessenger.of(context);
      if (productId == null || productId.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('No store product configured for ${widget.assetId}'),
          ),
        );
        return;
      }
      final outcome = await economy.purchaseProduct(
        productId,
        onConfirmed: () => _grant(economy, slot),
      );
      if (!mounted) return;
      switch (outcome.result) {
        case IapPurchaseResult.success:
          break;
        case IapPurchaseResult.cancelled:
          return;
        case IapPurchaseResult.failed:
        case IapPurchaseResult.productUnknown:
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Purchase failed: '
                '${outcome.errorMessage ?? outcome.result.name}',
              ),
            ),
          );
          return;
      }
    } else {
      _grant(economy, slot);
    }
    await _claimNext();
  }

  void _grant(EconomyState economy, _SlotData slot) {
    final ungranted = OfferGrant.apply(economy, slot.rewards);
    if (ungranted.isNotEmpty) {
      debugPrint('[offer] ${widget.assetId}: ungranted reward tokens $ungranted');
    }
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

    final offer = mc.templates.onePlusTwo
        .cast<OnePlusTwoOffer?>()
        .firstWhere((o) => o?.assetId == widget.assetId, orElse: () => null);
    final slots = _parseSlots(offer?.slots);

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
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Title(displayName: displayName),
                  const SizedBox(height: 22),
                  Expanded(
                    child: _SlotsRow(
                      slots: slots,
                      claimed: _claimed,
                      onTap: () => _handleSlot(context, cfg?.productId, slots),
                    ),
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

  static List<_SlotData> _parseSlots(List<OnePlusTwoSlot>? raw) {
    if (raw == null) return const [];
    return raw
        .map((s) => _SlotData(
              rewards: OfferRewardParser.parse(s.reward),
              priceUsd: s.priceUsd,
            ))
        .toList(growable: false);
  }
}

class _SlotData {
  final List<OfferRewardItem> rewards;
  final double? priceUsd;
  const _SlotData({required this.rewards, required this.priceUsd});
  bool get isPaid => priceUsd != null;
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
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
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
          'Buy 1 & get 2 FREE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SlotsRow extends StatelessWidget {
  final List<_SlotData> slots;
  final int claimed;
  final VoidCallback onTap;

  const _SlotsRow({
    required this.slots,
    required this.claimed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Text(
          'No offer slots configured',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < slots.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _SlotColumn(
              slot: slots[i],
              isClaimed: i < claimed,
              isLocked: i > claimed,
              onTap: i == claimed ? onTap : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _SlotColumn extends StatelessWidget {
  final _SlotData slot;
  final bool isClaimed;
  final bool isLocked;
  final VoidCallback? onTap;

  const _SlotColumn({
    required this.slot,
    required this.isClaimed,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isClaimed
        ? 'CLAIMED'
        : (slot.isPaid ? '\$${slot.priceUsd!.toStringAsFixed(2)}' : 'FREE');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceBlack.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.amber, width: 0.8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (slot.rewards.isEmpty)
                  const Text(
                    '—',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  )
                else
                  for (int j = 0; j < slot.rewards.length; j++) ...[
                    Flexible(
                      child: OfferRewardChip(
                        item: slot.rewards[j],
                        iconSize: slot.rewards.length >= 3 ? 36 : 44,
                      ),
                    ),
                  ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OfferCta(
          label: label,
          claimed: isClaimed,
          locked: isLocked,
          height: 42,
          onTap: onTap,
        ),
      ],
    );
  }
}
