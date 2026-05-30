import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/power_up_catalog.dart';
import '../services/pack_pricing.dart';
import '../state/economy_state.dart';
import 'coins_offer_popup.dart';

/// Last-chance loadout review before launch. Shows the active loadout's
/// jet + the player's stackable power-up inventory, plus a quick-add row
/// of frequently-bought power-ups.
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
                _InventoryPreview(inventory: economy.powerUpInventory),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// POWERUP-v2.1 inventory preview: a wrapping row of the player's owned
/// stackable power-ups with stack counts. Mirrors what the in-game
/// dynamic tray will render. Empty state shows a hint to visit the shop.
class _InventoryPreview extends StatelessWidget {
  final Map<String, int> inventory;
  const _InventoryPreview({required this.inventory});

  @override
  Widget build(BuildContext context) {
    final entries = PowerUpCatalog.stackableIds
        .where((id) => (inventory[id] ?? 0) > 0)
        .toList(growable: false);
    if (entries.isEmpty) {
      return Text(
        'No power-ups — visit the shop',
        style: AppTypography.bodyPale.copyWith(
          color: AppColors.greenLabel,
          fontSize: 11,
        ),
      );
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: entries
          .map((id) => _InventoryCell(id: id, count: inventory[id] ?? 0))
          .toList(),
    );
  }
}

class _InventoryCell extends StatelessWidget {
  final String id;
  final int count;
  const _InventoryCell({required this.id, required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count >= 10 ? '9+' : '$count';
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.greenDeep,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.greenTrack, width: 0.8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(3),
            child: Image.asset(
              PowerUpCatalog.slotIcon(id),
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.green,
                label: id,
                borderRadius: 3,
              ),
            ),
          ),
          if (count >= 2)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF9F27),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF0a1a0a), width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF412402),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
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
