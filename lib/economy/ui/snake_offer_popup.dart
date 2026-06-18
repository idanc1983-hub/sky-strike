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

/// "Snake" 6-slot offer popup — strict sequential progression.
///
/// Slots are laid out in a 3-row × 2-col zigzag matching the mock; the
/// player can only act on the next-in-line slot (`_claimed`), everything
/// after it is dimmed. Free slots claim with a single tap; paid slots
/// fake the IAP for now (real IAP wiring lands later).
///
/// RC sources:
///   - `monetization.configs.<asset>` — display_name, popup_bg,
///     duration_hours
///   - `monetization.templates.snake.<asset>.slots[].{reward_1,
///     reward_2, price_usd}` — up to 2 rewards per slot, optional price
class SnakeOfferPopup extends StatefulWidget {
  final String assetId;
  const SnakeOfferPopup({super.key, required this.assetId});

  static Future<void> show(BuildContext context, {required String assetId}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (_) => SnakeOfferPopup(assetId: assetId),
    );
  }

  @override
  State<SnakeOfferPopup> createState() => _SnakeOfferPopupState();
}

class _SnakeOfferPopupState extends State<SnakeOfferPopup> {
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

  /// Acts on the next-in-line slot. Free slots grant immediately; paid
  /// slots run the platform purchase first and grant only on a confirmed
  /// transaction. The slot is recorded as claimed only after its reward is
  /// granted — never on tap alone.
  Future<void> _handleSlot(
    BuildContext context,
    String? productId,
    List<_SnakeSlot> slots,
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

  void _grant(EconomyState economy, _SnakeSlot slot) {
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

    final offer = mc.templates.snake
        .cast<SnakeOffer?>()
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
                  const SizedBox(height: 18),
                  Expanded(
                    child: _SnakeGrid(
                      slots: slots,
                      claimed: _claimed,
                      onTap: () => _handleSlot(context, cfg?.productId, slots),
                    ),
                  ),
                  const SizedBox(height: 12),
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

  static List<_SnakeSlot> _parseSlots(List<SnakeSlot>? raw) {
    if (raw == null) return const [];
    return raw
        .map((s) => _SnakeSlot(
              rewards: [
                for (final r in s.rewards) ...OfferRewardParser.parse(r),
              ],
              priceUsd: s.priceUsd,
            ))
        .toList(growable: false);
  }
}

class _SnakeSlot {
  final List<OfferRewardItem> rewards;
  final double? priceUsd;
  const _SnakeSlot({required this.rewards, required this.priceUsd});
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
          'Keep collecting rewards',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// 3 rows × 2 cols zigzag layout. Decorative arrows live between cells
/// to communicate sequential progression; the only thing that actually
/// gates input is [claimed].
class _SnakeGrid extends StatelessWidget {
  final List<_SnakeSlot> slots;
  final int claimed;
  final VoidCallback onTap;

  const _SnakeGrid({
    required this.slots,
    required this.claimed,
    required this.onTap,
  });

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
    return Column(
      children: [
        for (int row = 0; row < 3; row++) ...[
          Expanded(child: _buildRow(rowIndex: row)),
          if (row < 2)
            const SizedBox(
              height: 22,
              child: Icon(Icons.south, color: AppColors.amber, size: 18),
            ),
        ],
      ],
    );
  }

  Widget _buildRow({required int rowIndex}) {
    final leftIdx = rowIndex * 2;
    final rightIdx = rowIndex * 2 + 1;
    final left = leftIdx < slots.length ? slots[leftIdx] : null;
    final right = rightIdx < slots.length ? slots[rightIdx] : null;
    // Alternate row direction visually: row 0 + row 2 = L→R, row 1 = R→L.
    final reversed = rowIndex == 1;
    final arrowIcon = Icon(
      reversed ? Icons.west : Icons.east,
      color: AppColors.amber,
      size: 18,
    );
    final cells = <Widget>[
      Expanded(child: _buildCell(index: leftIdx, slot: left)),
      SizedBox(width: 24, child: arrowIcon),
      Expanded(child: _buildCell(index: rightIdx, slot: right)),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: reversed ? cells.reversed.toList() : cells,
    );
  }

  Widget _buildCell({required int index, required _SnakeSlot? slot}) {
    if (slot == null) return const SizedBox.shrink();
    final isClaimed = index < claimed;
    final isNext = index == claimed;
    final isLocked = index > claimed;
    return _SnakeCell(
      slot: slot,
      isClaimed: isClaimed,
      isLocked: isLocked,
      onTap: isNext ? onTap : null,
    );
  }
}

class _SnakeCell extends StatelessWidget {
  final _SnakeSlot slot;
  final bool isClaimed;
  final bool isLocked;
  final VoidCallback? onTap;

  const _SnakeCell({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlack.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amber, width: 0.8),
              ),
              child: _RewardsContent(rewards: slot.rewards),
            ),
          ),
          const SizedBox(height: 6),
          OfferCta(
            label: label,
            claimed: isClaimed,
            locked: isLocked,
            height: 36,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _RewardsContent extends StatelessWidget {
  final List<OfferRewardItem> rewards;
  const _RewardsContent({required this.rewards});

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return const Center(
        child: Text('—', style: TextStyle(color: Colors.white70)),
      );
    }
    final size = rewards.length >= 2 ? 32.0 : 44.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final r in rewards)
          Flexible(child: OfferRewardChip(item: r, iconSize: size)),
      ],
    );
  }
}
