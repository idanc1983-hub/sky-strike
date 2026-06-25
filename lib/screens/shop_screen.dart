import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/remote_config_service.dart';
import '../economy/services/chest_reward_resolver.dart';
import '../economy/services/iap_service.dart';
import '../economy/state/economy_state.dart';
import '../economy/ui/chest_info_badge.dart';
import '../economy/ui/not_enough_coins_popup.dart';
import '../shared/theme/app_colors.dart';
import '../shared/widgets/app_buttons.dart';
import '../shared/widgets/app_top_bar.dart';
import '../shared/widgets/asset_placeholder.dart';

// ---------------------------------------------------------------------------
// Palette — kept inline to avoid disturbing the existing shop look-and-feel.
// ---------------------------------------------------------------------------
const _cGreen = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenMid = Color(0xFF639922);
const _cGreenDarker = Color(0xFF27500A);
const _cAmber = Color(0xFFEF9F27);
const _cAmberDark = Color(0xFF854F0B);
const _cAmberLight = Color(0xFFFAC775);
const _cGemBg = Color(0xFF412402);

/// Biome key → player world index (1..6). Used to gate power-up
/// unlocks per the v2 `economy__shop_powerups__v1.power_ups[*].unlock_biome`
/// config. Order mirrors world_map_screen's _biomes list.
const Map<String, int> _biomeToWorld = {
  'jungle': 1,
  'desert': 2,
  'sea': 3,
  'ice': 4,
  'volcano': 5,
  'city': 6,
};

// ---------------------------------------------------------------------------
// ShopScreen — v2: 2 tabs (Deals / Power-Ups), data-driven from Remote Config
// ---------------------------------------------------------------------------
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _activeTab = 0; // 0 = Deals, 1 = Power-Ups

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/backgrounds/shop_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar.full(),
              const SizedBox(height: 8),
              _TabRow(
                activeIndex: _activeTab,
                onChange: (i) => setState(() => _activeTab = i),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: IndexedStack(
                  index: _activeTab,
                  children: const [
                    _DealsTab(),
                    _PowerUpsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Tab row — 2 tabs only: Deals / Power-Ups
// =============================================================================
class _TabRow extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onChange;
  const _TabRow({required this.activeIndex, required this.onChange});

  @override
  Widget build(BuildContext context) {
    const labels = ['Deals', 'Power-Ups'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0a1a0a),
          border: Border.all(color: _cGreen, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final isActive = i == activeIndex;
            final radius = i == 0
                ? const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    bottomLeft: Radius.circular(7),
                  )
                : const BorderRadius.only(
                    topRight: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  );
            return Expanded(
              child: GestureDetector(
                onTap: () => onChange(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? _cGreen : Colors.transparent,
                    borderRadius: radius,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: isActive ? _cGreenPale : _cGreenMid,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// =============================================================================
// DEALS TAB  —  vertical scroll: Gems → Chests → Coins
// =============================================================================
class _DealsTab extends StatelessWidget {
  const _DealsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(14, 4, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GemPacksSection(),
          SizedBox(height: 14),
          _ChestsSection(),
          SizedBox(height: 14),
          _CoinPacksSection(),
        ],
      ),
    );
  }
}

// ----- Gems section ----------------------------------------------------------
class _GemPacksSection extends StatelessWidget {
  const _GemPacksSection();

  @override
  Widget build(BuildContext context) {
    final packs = _readGemPacks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DealsSectionHeader(
          title: 'Gems',
          iconColor: Color(0xFF7BB8FF),
          subtitle: 'Revives, exclusive jets & chests',
        ),
        const SizedBox(height: 10),
        if (packs.isEmpty)
          const _EmptyDataNote(label: 'gem_packs')
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [
              for (int i = 0; i < packs.length; i++)
                _PackCard(pack: packs[i], isGem: true, tierIndex: i),
            ],
          ),
      ],
    );
  }

  static List<_PackEntry> _readGemPacks() {
    final packs = RemoteConfigService.I.shop.gemPacks;
    return packs
        .map((p) => _PackEntry(
              id: p.id,
              amount: p.amount,
              priceUsd: p.price,
              productId: p.iapProductId,
            ))
        .toList()
      ..sort((a, b) => a.priceUsd.compareTo(b.priceUsd));
  }
}

// ----- Chests section --------------------------------------------------------
class _ChestsSection extends StatelessWidget {
  const _ChestsSection();

  // Per-tier display copy. Names + one-line perks per redesign mock.
  // Prices come from remote config (`chest_prices.<id>.coin_price`).
  static const _chestCopy = <String, ({String name, String perk})>{
    'basic_chest': (name: 'Basic', perk: 'Coins\n+\npower-ups'),
    'unique_chest': (name: 'Rare', perk: '2x Coins\nbooster'),
    'epic_chest': (name: 'Epic', perk: 'Epic jet\n+\ngem bonus'),
  };

  @override
  Widget build(BuildContext context) {
    final chests = _readChests();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DealsSectionHeader(
          title: 'Chests',
          iconColor: AppColors.amber,
        ),
        const SizedBox(height: 10),
        if (chests.isEmpty)
          const _EmptyDataNote(label: 'chest_prices')
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < chests.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _ChestCard(
                      chest: chests[i],
                      copy: _chestCopy[chests[i].id] ??
                          (name: chests[i].id, perk: ''),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static List<_ChestEntry> _readChests() {
    final deals = RemoteConfigService.I.shop.chestDeals;
    if (deals.isEmpty) return const [];
    // Canonical tier order — basic / unique / epic. (special_chest is
    // earned-only per the economy plan; never in shop.)
    const order = ['basic_chest', 'unique_chest', 'epic_chest'];
    final out = <_ChestEntry>[];
    for (final id in order) {
      final deal = deals
          .cast<ChestDeal?>()
          .firstWhere((d) => d?.chestId == id, orElse: () => null);
      if (deal == null) continue;
      out.add(_ChestEntry(
        id: id,
        coinPrice: deal.coinPrice,
        gemPrice: deal.gemPrice,
      ));
    }
    return out;
  }
}

// ----- Coin packs section ----------------------------------------------------
class _CoinPacksSection extends StatelessWidget {
  const _CoinPacksSection();

  @override
  Widget build(BuildContext context) {
    final packs = _readCoinPacks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DealsSectionHeader(
          title: 'Coins',
          iconColor: AppColors.amber,
          subtitle: 'Earn in gameplay or buy pack below',
        ),
        const SizedBox(height: 10),
        if (packs.isEmpty)
          const _EmptyDataNote(label: 'coin_packs')
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [
              for (int i = 0; i < packs.length; i++)
                _PackCard(pack: packs[i], isGem: false, tierIndex: i),
            ],
          ),
      ],
    );
  }

  static List<_PackEntry> _readCoinPacks() {
    final packs = RemoteConfigService.I.shop.coinPacks;
    return packs
        .map((p) => _PackEntry(
              id: p.id,
              amount: p.amount,
              priceUsd: p.price,
              productId: p.iapProductId,
            ))
        .toList()
      ..sort((a, b) => a.priceUsd.compareTo(b.priceUsd));
  }
}

// =============================================================================
// POWER-UPS TAB  —  RC-driven list in unlock-biome order
// =============================================================================
class _PowerUpsTab extends StatelessWidget {
  const _PowerUpsTab();

  /// One-line player-facing description per power-up id. Hard-coded for
  /// now; move to remote config when a `description` field is added.
  static const _descriptions = <String, String>{
    'speed_boost': 'Increase jets movement',
    'rapid_fire': 'Increase jet fire rate',
    'bomb': 'Clears the screen of enemies',
    'split_shot': 'Fires three bullets in a spread',
    'shield': 'Block enemies fire',
    'magnet': 'Pull all enemies drops',
    'laser': 'Continuous beam, pierces enemies',
    'freeze_time': 'Slow time briefly',
    'drone_wingman': 'Spawns a wingman drone',
    'ghost_mode': 'Brief invincibility',
  };

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final entries = _readPowerUps();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DealsSectionHeader(
            title: 'Power-Ups',
            iconColor: AppColors.amber,
            subtitle: 'Unlock by reaching new biomes, buy spares with coins',
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const _EmptyDataNote(label: 'power_ups')
          else
            for (final pu in entries) ...[
              _PowerUpRow(
                entry: pu,
                description: _descriptions[pu.id] ?? '',
                playerWorld: economy.currentWorld,
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  static List<_PowerUpEntry> _readPowerUps() {
    final rcs = RemoteConfigService.I;
    final powerUps = rcs.powerUps;
    final prices = rcs.shop.powerUps;
    if (powerUps.isEmpty) return const [];
    final out = <_PowerUpEntry>[];
    for (final pu in powerUps) {
      final priceEntry = prices
          .cast<ShopPowerUp?>()
          .firstWhere((p) => p?.powerUpId == pu.id, orElse: () => null);
      final price = priceEntry?.coinPrice ?? 0;
      out.add(_PowerUpEntry(
        id: pu.id,
        displayName: pu.name.isEmpty ? pu.id : pu.name,
        unlockBiome: pu.unlockBiome.isEmpty ? 'jungle' : pu.unlockBiome,
        category: pu.category.isEmpty ? 'instant' : pu.category,
        duration: pu.isInstant ? 'instant' : '${pu.durationSec}s',
        coinPrice: price,
      ));
    }
    // Sort by unlock_biome order, then by price within biome — matches the
    // progression in `Power-ups unlock.xlsx`.
    out.sort((a, b) {
      final aw = _biomeToWorld[a.unlockBiome] ?? 99;
      final bw = _biomeToWorld[b.unlockBiome] ?? 99;
      if (aw != bw) return aw.compareTo(bw);
      return a.coinPrice.compareTo(b.coinPrice);
    });
    return out;
  }
}

class _PowerUpRow extends StatelessWidget {
  final _PowerUpEntry entry;
  final String description;
  final int playerWorld;
  const _PowerUpRow({
    required this.entry,
    required this.description,
    required this.playerWorld,
  });

  bool get _isUnlocked {
    final reqWorld = _biomeToWorld[entry.unlockBiome] ?? 1;
    return playerWorld >= reqWorld;
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _isUnlocked;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.94),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 0.7,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset(
              'assets/ui/pu_${entry.id}_slot.png',
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amber,
                label: entry.id,
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
                  entry.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description.isNotEmpty
                      ? description
                      : '${entry.category.toUpperCase()} · ${entry.duration}',
                  style: TextStyle(
                    color: AppColors.amber.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (unlocked)
            _PuBuyChip(
              amount: entry.coinPrice,
              onTap: () => _attemptPurchase(context),
            )
          else
            _PuLockedChip(onTap: () => _showLockedInfo(context)),
        ],
      ),
    );
  }

  void _attemptPurchase(BuildContext context) {
    final economy = context.read<EconomyState>();
    if (!economy.spendCoins(entry.coinPrice)) {
      NotEnoughCoinsPopup.show(context);
      return;
    }
    economy.grantPowerUp(entry.id);
  }

  void _showLockedInfo(BuildContext context) {
    final biome = entry.unlockBiome;
    final world = _biomeToWorld[biome] ?? 1;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceBlack,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: AppColors.amber.withValues(alpha: 0.55),
            width: 0.7,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Unlock at biome ${_capitalize(biome)}'
                ' — World $world',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFBDC9A8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              AppButton.primary(
                label: 'OK',
                height: 44,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Green pill with the coin price — used on unlocked power-up rows.
class _PuBuyChip extends StatelessWidget {
  final int amount;
  final VoidCallback onTap;
  const _PuBuyChip({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.green,
          border: Border.all(color: AppColors.greenLight, width: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatNumber(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            SizedBox(
              width: 13,
              height: 13,
              child: Image.asset(
                'assets/ui/icon_coin.png',
                fit: BoxFit.contain,
                errorBuilder: AssetPlaceholder.image(
                  color: AppColors.amber,
                  label: 'c',
                  borderRadius: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green-bordered button with a lock icon — used on locked power-up rows.
/// Tapping it surfaces an info popup with the unlock biome + world.
class _PuLockedChip extends StatelessWidget {
  final VoidCallback onTap;
  const _PuLockedChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.green,
          border: Border.all(color: AppColors.greenLight, width: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.lock,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

// =============================================================================
// Cards / pills / placeholders
// =============================================================================
// ----- Section header (mock layout) -----------------------------------------
class _DealsSectionHeader extends StatelessWidget {
  final String title;
  final String? iconAsset;
  final Color iconColor;
  final String? subtitle;

  const _DealsSectionHeader({
    required this.title,
    required this.iconColor,
    this.iconAsset,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.94),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 0.7,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (iconAsset != null) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Image.asset(
                    iconAsset!,
                    fit: BoxFit.contain,
                    // When the asset is missing in dev, render nothing
                    // (no "P:" placeholder badge inside the title row).
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.amber.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----- Gem / coin pack card (mock layout) -----------------------------------
class _PackCard extends StatelessWidget {
  final _PackEntry pack;
  final bool isGem;
  // 0-based tier index used to pick the illustration: tier 0 = smallest
  // pile, tier 5 = largest pile. Clamped to [1..6] when building the
  // asset path so a 7th+ pack falls back to the largest tier.
  final int tierIndex;
  const _PackCard({
    required this.pack,
    required this.isGem,
    required this.tierIndex,
  });

  @override
  Widget build(BuildContext context) {
    final smallIcon =
        isGem ? 'assets/ui/icon_gem.png' : 'assets/ui/icon_coin.png';
    final iconColor =
        isGem ? const Color(0xFF7BB8FF) : AppColors.amber;
    final tier = (tierIndex + 1).clamp(1, 6);
    final pileAsset = isGem
        ? 'assets/ui/gems_$tier.png'
        : 'assets/ui/coins_$tier.png';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.94),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 0.7,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Amount badge — top right
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Align(
              alignment: Alignment.topRight,
              child: _AmountBadge(
                amount: pack.amount,
                iconAsset: smallIcon,
                iconColor: iconColor,
              ),
            ),
          ),
          // Illustration — tier-specific pile artwork.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Image.asset(
                pileAsset,
                fit: BoxFit.contain,
                errorBuilder: AssetPlaceholder.image(
                  color: iconColor,
                  label: pack.id,
                  borderRadius: 8,
                ),
              ),
            ),
          ),
          // Price button
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: GestureDetector(
              onTap: () => _buy(context),
              child: Container(
                width: double.infinity,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  border: Border.all(color: AppColors.greenLight, width: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${pack.priceUsd.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Starts the platform purchase flow for this pack. The coins/gems are
  /// granted only inside [EconomyState.purchaseProduct]'s success callback,
  /// after StoreKit/Play confirms a completed transaction — never on tap.
  Future<void> _buy(BuildContext context) async {
    final productId = pack.productId;
    final messenger = ScaffoldMessenger.of(context);
    if (productId == null || productId.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('No store product configured for ${pack.id}')),
      );
      return;
    }
    final economy = context.read<EconomyState>();
    final outcome = await economy.purchaseProduct(
      productId,
      onConfirmed: () {
        if (isGem) {
          economy.addGems(pack.amount, source: 'iap_$productId');
        } else {
          economy.addCoins(pack.amount, source: 'iap_$productId');
        }
      },
    );
    if (!context.mounted) return;
    switch (outcome.result) {
      case IapPurchaseResult.success:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '+${_formatNumber(pack.amount)} ${isGem ? 'gems' : 'coins'}',
            ),
          ),
        );
        break;
      case IapPurchaseResult.cancelled:
        // Player backed out of the store sheet — stay silent.
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
}

// ----- Amount badge (top-right of pack cards) -------------------------------
class _AmountBadge extends StatelessWidget {
  final int amount;
  final String iconAsset;
  final Color iconColor;

  const _AmountBadge({
    required this.amount,
    required this.iconAsset,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.7),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.6),
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatNumber(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 14.4,
            height: 14.4,
            child: Image.asset(
              iconAsset,
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: iconColor,
                label: 'b',
                borderRadius: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----- Chest card (3-col grid) ----------------------------------------------
class _ChestCard extends StatelessWidget {
  final _ChestEntry chest;
  final ({String name, String perk}) copy;
  const _ChestCard({required this.chest, required this.copy});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _ChestPreviewSheet.show(context, chest, copy.name),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceBlack.withValues(alpha: 0.94),
          border: Border.all(
            color: AppColors.amber.withValues(alpha: 0.55),
            width: 0.7,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          children: [
            ChestInfoBadge.wrap(
              SizedBox(
                height: 78,
                child: Image.asset(
                  'assets/ui/icon_${chest.id}.png',
                  fit: BoxFit.contain,
                  errorBuilder: AssetPlaceholder.image(
                    color: AppColors.amber,
                    label: chest.id,
                    borderRadius: 6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () =>
                  _ChestRowActions.buyWithCoins(context, chest, copy.name),
              child: Container(
                width: double.infinity,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  border: Border.all(color: AppColors.greenLight, width: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatNumber(chest.coinPrice),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: Image.asset(
                        'assets/ui/icon_coin.png',
                        fit: BoxFit.contain,
                        errorBuilder: AssetPlaceholder.image(
                          color: AppColors.amber,
                          label: 'c',
                          borderRadius: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- Chest preview sheet ---------------------------------------------------
class _ChestPreviewSheet extends StatelessWidget {
  final _ChestEntry chest;
  final String label;
  const _ChestPreviewSheet({required this.chest, required this.label});

  static Future<void> show(
      BuildContext context, _ChestEntry chest, String label) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0d1a0d),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => _ChestPreviewSheet(chest: chest, label: label),
    );
  }

  Map<String, dynamic> get _config {
    final def = RemoteConfigService.I.chests.byId(chest.id);
    if (def == null) return const <String, dynamic>{};
    return <String, dynamic>{
      'coin_min': def.coinMin,
      'coin_max': def.coinMax,
      'gem_min': def.gemMin,
      'gem_max': def.gemMax,
      'jet_drop_chance': def.jetDropChance,
      'jet_id': def.jetId,
    };
  }

  int _readInt(String key) {
    final v = _config[key];
    return v is num ? v.toInt() : 0;
  }

  double _readDouble(String key) {
    final v = _config[key];
    return v is num ? v.toDouble() : 0.0;
  }

  String _formatRange(int lo, int hi) {
    if (lo == hi) return _formatNumber(lo);
    return '${_formatNumber(lo)} – ${_formatNumber(hi)}';
  }

  @override
  Widget build(BuildContext context) {
    final coinLo = _readInt('coin_min');
    final coinHi = _readInt('coin_max');
    final gemLo = _readInt('gem_min');
    final gemHi = _readInt('gem_max');
    final jetChance = _readDouble('jet_drop_chance');
    final jetId = _config['jet_id'] is String
        ? _config['jet_id'] as String
        : null;
    final bonusCoinsForNoJet = _readInt('bonus_coins_in_place_of_jet');

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.asset(
                    'assets/ui/icon_${chest.id}.png',
                    fit: BoxFit.contain,
                    errorBuilder: AssetPlaceholder.image(
                        color: _cAmber, label: chest.id, borderRadius: 8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$label CHEST',
                          style: const TextStyle(
                              color: _cAmberLight,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4)),
                      const SizedBox(height: 2),
                      const Text('Possible rewards',
                          style: TextStyle(
                              color: _cGreenMid,
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close,
                      color: _cGreenLight, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Reward rows
            if (coinHi > 0)
              _RewardRow(
                icon: 'assets/ui/icon_coin.png',
                fallback: 'c',
                amount: _formatRange(coinLo, coinHi),
                label: 'Coins',
                tint: _cAmber,
              ),
            if (gemHi > 0) ...[
              const SizedBox(height: 8),
              _RewardRow(
                icon: 'assets/ui/icon_gem.png',
                fallback: 'g',
                amount: _formatRange(gemLo, gemHi),
                label: 'Gems',
                tint: _cAmberLight,
              ),
            ],
            if (jetId != null && jetChance > 0) ...[
              const SizedBox(height: 8),
              _RewardRow(
                icon: 'assets/jets/jet_player.png',
                fallback: 'j',
                amount: '${(jetChance * 100).toStringAsFixed(0)}%',
                label: 'Chance: $jetId',
                tint: _cGreenLight,
              ),
            ],
            if (bonusCoinsForNoJet > 0) ...[
              const SizedBox(height: 8),
              _RewardRow(
                icon: 'assets/ui/icon_coin.png',
                fallback: 'c',
                amount: '+${_formatNumber(bonusCoinsForNoJet)}',
                label: 'Bonus if no jet',
                tint: _cAmber,
              ),
            ],
            const SizedBox(height: 16),
            // Buy actions
            Row(
              children: [
                Expanded(
                  child: _BuyPill(
                    onTap: () {
                      Navigator.of(context).pop();
                      _ChestRowActions.buyWithCoins(context, chest, label);
                    },
                    child: Center(
                      child: _CoinAmount(amount: chest.coinPrice),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BuyPill(
                    onTap: () {
                      Navigator.of(context).pop();
                      _ChestRowActions.buyWithGems(context, chest, label);
                    },
                    color: _cGemBg,
                    borderColor: _cAmber,
                    child: Center(
                      child: _GemAmount(amount: chest.gemPrice),
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

class _RewardRow extends StatelessWidget {
  final String icon;
  final String fallback;
  final String amount;
  final String label;
  final Color tint;
  const _RewardRow({
    required this.icon,
    required this.fallback,
    required this.amount,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0a1a0a),
        border: Border.all(color: _cGreenDarker, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Image.asset(
              icon,
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                  color: tint, label: fallback, borderRadius: 4),
            ),
          ),
          const SizedBox(width: 10),
          Text(amount,
              style: TextStyle(
                  color: tint,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: _cGreenPale, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Shared chest purchase actions — used by both [_ChestRow] (inline pills)
/// and [_ChestPreviewSheet] (preview buttons). The spend and the reward
/// grant live in one place so the two halves stay atomic.
class _ChestRowActions {
  _ChestRowActions._();

  /// Single RNG so every chest open in a session shares the same source.
  /// Not seeded — payouts must look random to the player; tests pin
  /// outcomes by calling [ChestRewardResolver.resolve] directly.
  static final Random _rng = Random();

  static void buyWithCoins(
      BuildContext context, _ChestEntry chest, String label) {
    final economy = context.read<EconomyState>();
    if (!economy.spendCoins(chest.coinPrice)) {
      NotEnoughCoinsPopup.show(context);
      return;
    }
    _grantAndAnnounce(context, economy, chest, label);
  }

  static void buyWithGems(
      BuildContext context, _ChestEntry chest, String label) {
    final economy = context.read<EconomyState>();
    if (!economy.spendGems(chest.gemPrice)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough gems')),
      );
      return;
    }
    _grantAndAnnounce(context, economy, chest, label);
  }

  /// Resolves the chest payout from Remote Config and applies it to the
  /// wallet (and jet inventory for biome chests). Silently no-ops if RC
  /// has no definition for [chest.id].
  static void _grantAndAnnounce(
    BuildContext context,
    EconomyState economy,
    _ChestEntry chest,
    String label,
  ) {
    final def = RemoteConfigService.I.chests.byId(chest.id);
    if (def == null) return;
    final result = ChestRewardResolver.resolve(
      definition: <String, dynamic>{
        'coin_min': def.coinMin,
        'coin_max': def.coinMax,
        'gem_min': def.gemMin,
        'gem_max': def.gemMax,
        'jet_drop_chance': def.jetDropChance,
        'jet_id': def.jetId,
      },
      rng: _rng,
    );
    // Won from a chest → reveal it with the chest-open animation, which then
    // flies the coins/gems into the holder. grantChest also records the jet
    // (if any) at price 0 without consuming the pendingNextJetDiscount slot.
    // Plays through RewardCelebrationHost (the Shop is wrapped in one).
    economy.grantChest(
      coins: result.reward.coins,
      gems: result.reward.gems,
      jetId: result.hasJet ? result.jetId : null,
    );
  }
}

class _BuyPill extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color color;
  final Color borderColor;
  const _BuyPill({
    required this.onTap,
    required this.child,
    this.color = _cGreen,
    this.borderColor = _cGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      ),
    );
  }
}

class _CoinAmount extends StatelessWidget {
  final int amount;
  const _CoinAmount({required this.amount});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/ui/icon_coin.png',
              width: 12,
              height: 12,
              errorBuilder: AssetPlaceholder.image(
                  color: _cAmber, label: 'c', borderRadius: 2)),
          const SizedBox(width: 3),
          Text(
            _formatNumber(amount),
            style: const TextStyle(
                color: _cGreenPale, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      );
}

class _GemAmount extends StatelessWidget {
  final int amount;
  const _GemAmount({required this.amount});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/ui/icon_gem.png',
              width: 12,
              height: 12,
              errorBuilder: AssetPlaceholder.image(
                  color: _cAmber, label: 'g', borderRadius: 2)),
          const SizedBox(width: 3),
          Text(
            '$amount',
            style: const TextStyle(
                color: _cAmberLight,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      );
}


class _EmptyDataNote extends StatelessWidget {
  final String label;
  const _EmptyDataNote({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0x44000000),
          border: Border.all(color: _cAmberDark, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            'No data for "$label" — check Remote Config',
            style: const TextStyle(
                color: _cAmberLight, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ),
      );
}

// =============================================================================
// Data holders
// =============================================================================
class _PackEntry {
  final String id;
  final int amount;
  final double priceUsd;

  /// Platform store product id for this pack; null when unmapped (CTA
  /// disabled rather than granting for free).
  final String? productId;

  const _PackEntry({
    required this.id,
    required this.amount,
    required this.priceUsd,
    this.productId,
  });
  factory _PackEntry.empty(String id) =>
      _PackEntry(id: id, amount: 0, priceUsd: 0.0);
}

class _ChestEntry {
  final String id;
  final int coinPrice;
  final int gemPrice;
  const _ChestEntry({
    required this.id,
    required this.coinPrice,
    required this.gemPrice,
  });
}

class _PowerUpEntry {
  final String id;
  final String displayName;
  final String unlockBiome;
  final String category;
  final String duration;
  final int coinPrice;
  const _PowerUpEntry({
    required this.id,
    required this.displayName,
    required this.unlockBiome,
    required this.category,
    required this.duration,
    required this.coinPrice,
  });
}

// =============================================================================
// Helpers
// =============================================================================
String _formatNumber(int n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
  }
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
  }
  return n.toString();
}
