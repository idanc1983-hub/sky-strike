import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/ace_dialogue_catalog.dart';
import '../constants/economy_constants.dart';
import '../constants/power_up_catalog.dart';
import '../services/pack_pricing.dart';
import '../state/economy_state.dart';
import 'coins_offer_popup.dart';

/// Last-chance loadout review before launch. Shows the active loadout's
/// jet + tray plus a quick-add row of frequently-bought power-ups.
///
/// Fires Ace's pre-mission intro lines the first time the player opens
/// the popup for Stage 1 (FTUE one-shot per GDD §10.4): the first line
/// requests immediately; the second is scheduled ~1.5s later so the
/// player gets a chance to dismiss the first before the second lands.
class PreMissionPopup extends StatefulWidget {
  final int world;
  final int stage;

  const PreMissionPopup({super.key, required this.world, required this.stage});

  /// Shows the popup as a fullscreen modal. Returns `true` if the player
  /// taps LAUNCH, `false` on BACK or system back-press.
  static Future<bool> show(
    BuildContext context, {
    required int world,
    required int stage,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      builder: (_) => PreMissionPopup(world: world, stage: stage),
    );
    return result ?? false;
  }

  @override
  State<PreMissionPopup> createState() => _PreMissionPopupState();
}

class _PreMissionPopupState extends State<PreMissionPopup> {
  Timer? _secondBeatTimer;

  @override
  void initState() {
    super.initState();
    // Only Stage 1's pre-mission popup gates the rookie intro. Later
    // stages skip Ace entirely — per GDD §10.4 the intro lines are
    // strictly first-mission territory.
    if (widget.world != 1 || widget.stage != 1) return;
    // Schedule Ace's pre-mission lines AFTER the first frame so the
    // bottom sheet has finished its slide-in animation and the
    // AceDialogueListener gets a clean overlay context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final economy = context.read<EconomyState>();
      economy.requestAceLine(AceLineKeys.ftuePreMission1);
      // Line 2 follows ~1.5s later — long enough for the player to
      // dismiss the first bubble before the second is queued.
      _secondBeatTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        context.read<EconomyState>().requestAceLine(
              AceLineKeys.ftuePreMission2,
            );
      });
    });
  }

  @override
  void dispose() {
    _secondBeatTimer?.cancel();
    _secondBeatTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'World ${widget.world} · Stage ${widget.stage}',
                  style: AppTypography.title,
                ),
                _CoinChip(coins: economy.coins),
              ],
            ),
            const SizedBox(height: 12),
            _LoadoutSummary(),
            const SizedBox(height: 12),
            _LoadoutSwitcher(),
            const SizedBox(height: 16),
            const Text('Quick add', style: AppTypography.label),
            const SizedBox(height: 8),
            _QuickAddRow(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.greenLabel,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('BACK'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'LAUNCH',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  final int coins;
  const _CoinChip({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Image.asset(
              'assets/ui/icon_coin.png',
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amber,
                label: 'coins',
                borderRadius: 3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('$coins',
              style: AppTypography.bodyPale.copyWith(
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _LoadoutSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final loadout = economy.activeLoadout;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.green, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/jets/${loadout.jetId}.png',
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.green,
                label: loadout.jetId,
                borderRadius: 6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loadout.name,
                    style: AppTypography.bodyPale
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: List<Widget>.generate(
                    EconomyConstants.trayPowerUpCount,
                    (i) => _TrayCell(
                      occupant: loadout.trayPowerUps[i],
                      owned: i < economy.unlockedLoadoutSlots,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrayCell extends StatelessWidget {
  final String? occupant;
  final bool owned;
  const _TrayCell({required this.occupant, required this.owned});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Opacity(
        opacity: owned ? 1.0 : 0.3,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.greenDeep,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.greenTrack, width: 0.8),
          ),
          child: occupant == null
              ? const Center(
                  child: Text('—',
                      style: TextStyle(
                        color: AppColors.greenLabel,
                        fontSize: 12,
                      )),
                )
              : Padding(
                  padding: const EdgeInsets.all(3),
                  child: Image.asset(
                    PowerUpCatalog.slotIcon(occupant!),
                    fit: BoxFit.contain,
                    errorBuilder: AssetPlaceholder.image(
                      color: AppColors.green,
                      label: occupant!,
                      borderRadius: 3,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _LoadoutSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: economy.unlockedLoadoutSlots,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final selected = economy.activeLoadoutIndex == i;
          return GestureDetector(
            onTap: () => economy.selectLoadout(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.green : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? AppColors.greenLight : AppColors.greenTrack,
                  width: 0.8,
                ),
              ),
              child: Text(
                economy.loadouts[i].name,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.greenLabel,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  /// IDs shown in the quick-add row by default. Production replaces this
  /// with the player's most-bought set; for v1.2 launch we hardcode a
  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final unlocked = economy.unlockedPowerUps;
    // Quick-add only surfaces stackable / collectible power-ups —
    // instant ones aren't shop-purchasable and never appear here.
    final ids = PowerUpCatalog.stackableIds
        .where(unlocked.contains)
        .toList();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ids.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final id = ids[i];
          final price = PackPricing.totalPrice(powerUpId: id, packSize: 1);
          return _QuickAddTile(id: id, price: price);
        },
      ),
    );
  }
}

class _QuickAddTile extends StatelessWidget {
  final String id;
  final int price;
  const _QuickAddTile({required this.id, required this.price});

  Future<void> _onTap(BuildContext context) async {
    final economy = context.read<EconomyState>();
    if (economy.coins < price) {
      await CoinsOfferPopup.show(context);
      return;
    }
    economy.buyPowerUp(id, packSize: 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.green, width: 0.6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Image.asset(
                PowerUpCatalog.slotIcon(id),
                fit: BoxFit.contain,
                errorBuilder: AssetPlaceholder.image(
                  color: AppColors.green,
                  label: id,
                  borderRadius: 4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, size: 11, color: AppColors.amber),
                const SizedBox(width: 2),
                Text('$price',
                    style: AppTypography.bodyPale
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
