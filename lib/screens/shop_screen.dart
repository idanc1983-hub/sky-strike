import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/remote_config_service.dart';
import '../economy/state/economy_state.dart';
import '../shared/widgets/asset_placeholder.dart';

// ---------------------------------------------------------------------------
// Palette — kept inline to avoid disturbing the existing shop look-and-feel.
// ---------------------------------------------------------------------------
const _cGreen = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenMid = Color(0xFF639922);
const _cGreenDark = Color(0xFF173404);
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
              const _TopBar(),
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
// Top bar — level + coin/gem chips
// =============================================================================
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _PillChip(
            text: 'Lv ${economy.level}',
            bg: _cGreenDark,
            textColor: _cGreenLight,
          ),
          const Spacer(),
          _IconChip(
            asset: 'assets/ui/icon_coin.png',
            value: _formatNumber(economy.coins),
            bg: _cGreenDark,
            textColor: _cGreenPale,
          ),
          const SizedBox(width: 6),
          _IconChip(
            asset: 'assets/ui/icon_gem.png',
            value: '${economy.gems}',
            bg: _cGemBg,
            textColor: _cAmber,
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color textColor;
  const _PillChip({required this.text, required this.bg, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text,
            style: TextStyle(
                color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _IconChip extends StatelessWidget {
  final String asset;
  final String value;
  final Color bg;
  final Color textColor;
  const _IconChip(
      {required this.asset,
      required this.value,
      required this.bg,
      required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset,
                width: 16,
                height: 16,
                errorBuilder: AssetPlaceholder.image(
                    color: _cAmber, label: 'icon', borderRadius: 3)),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
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
          SizedBox(height: 18),
          _ChestsSection(),
          SizedBox(height: 18),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'GEMS'),
        const SizedBox(height: 6),
        const _SectionHint(
          icon: 'assets/ui/icon_gem.png',
          text: 'Premium currency · Chests, biome jets & monetization offers',
          tintBg: _cGemBg,
          tintBorder: _cGemBg,
          textColor: _cAmberDark,
        ),
        const SizedBox(height: 8),
        if (packs.isEmpty)
          const _EmptyDataNote(label: 'gem_packs')
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: [
              for (final p in packs) _IapPackCard(pack: p, isGem: true),
            ],
          ),
      ],
    );
  }

  static List<_PackEntry> _readGemPacks() {
    final raw = RemoteConfigService.instance.shopIap['gem_packs'];
    if (raw is! Map) return const [];
    return raw.entries.map((e) {
      final v = e.value;
      if (v is! Map) return _PackEntry.empty(e.key.toString());
      return _PackEntry(
        id: e.key.toString(),
        amount: (v['gem_amount'] as num?)?.toInt() ?? 0,
        priceUsd: (v['price_usd'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList()
      ..sort((a, b) => a.priceUsd.compareTo(b.priceUsd));
  }
}

// ----- Chests section --------------------------------------------------------
class _ChestsSection extends StatelessWidget {
  const _ChestsSection();

  @override
  Widget build(BuildContext context) {
    final chests = _readChests();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'CHESTS'),
        const SizedBox(height: 6),
        const _SectionHint(
          icon: 'assets/ui/icon_chest_basic.png',
          text: 'Buy with Coins or Gems · earn more from challenges',
          tintBg: _cGreenDark,
          tintBorder: _cGreen,
          textColor: _cGreenMid,
        ),
        const SizedBox(height: 8),
        if (chests.isEmpty)
          const _EmptyDataNote(label: 'chest_prices')
        else
          for (final c in chests) ...[
            _ChestRow(chest: c),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  static List<_ChestEntry> _readChests() {
    final raw = RemoteConfigService.instance.shopIap['chest_prices'];
    if (raw is! Map) return const [];
    // Canonical tier order — basic / unique / epic. (special_chest is
    // earned-only per the economy plan; never in shop.)
    const order = ['basic_chest', 'unique_chest', 'epic_chest'];
    final out = <_ChestEntry>[];
    for (final id in order) {
      final v = raw[id];
      if (v is! Map) continue;
      out.add(_ChestEntry(
        id: id,
        coinPrice: (v['coin_price'] as num?)?.toInt() ?? 0,
        gemPrice: (v['gem_price'] as num?)?.toInt() ?? 0,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'COINS'),
        const SizedBox(height: 6),
        const _SectionHint(
          icon: 'assets/ui/icon_coin.png',
          text: 'Soft currency · Buy chests, power-ups & jet shortcuts',
          tintBg: _cGreenDark,
          tintBorder: _cGreen,
          textColor: _cGreenMid,
        ),
        const SizedBox(height: 8),
        if (packs.isEmpty)
          const _EmptyDataNote(label: 'coin_packs')
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: [
              for (final p in packs) _IapPackCard(pack: p, isGem: false),
            ],
          ),
      ],
    );
  }

  static List<_PackEntry> _readCoinPacks() {
    final raw = RemoteConfigService.instance.shopIap['coin_packs'];
    if (raw is! Map) return const [];
    return raw.entries.map((e) {
      final v = e.value;
      if (v is! Map) return _PackEntry.empty(e.key.toString());
      return _PackEntry(
        id: e.key.toString(),
        amount: (v['coin_amount'] as num?)?.toInt() ?? 0,
        priceUsd: (v['price_usd'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList()
      ..sort((a, b) => a.priceUsd.compareTo(b.priceUsd));
  }
}

// =============================================================================
// POWER-UPS TAB  —  all 10 from RC, locked rows greyed-out per unlock_biome
// =============================================================================
class _PowerUpsTab extends StatelessWidget {
  const _PowerUpsTab();

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final entries = _readPowerUps();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      child: Column(
        children: [
          const _SectionHint(
            icon: 'assets/ui/icon_powerup_pack.png',
            text: 'Unlock by reaching new biomes · Buy spares with Coins',
            tintBg: _cGreenDark,
            tintBorder: _cGreen,
            textColor: _cGreenMid,
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const _EmptyDataNote(label: 'power_ups')
          else
            for (final pu in entries) ...[
              _PowerUpRow(
                entry: pu,
                playerWorld: economy.currentWorld,
              ),
              const SizedBox(height: 7),
            ],
        ],
      ),
    );
  }

  static List<_PowerUpEntry> _readPowerUps() {
    final rcs = RemoteConfigService.instance;
    final powerUps = rcs.shopPowerups;
    final prices = rcs.shopIap['powerup_prices'];
    if (powerUps.isEmpty) return const [];
    final out = <_PowerUpEntry>[];
    powerUps.forEach((id, v) {
      if (v is! Map) return;
      final priceMap = prices is Map ? prices[id] : null;
      final price = (priceMap is Map && priceMap['coin_price'] is num)
          ? (priceMap['coin_price'] as num).toInt()
          : 0;
      out.add(_PowerUpEntry(
        id: id,
        displayName: (v['display_name'] as String?) ?? id,
        unlockBiome: (v['unlock_biome'] as String?) ?? 'jungle',
        category: (v['category'] as String?) ?? 'instant',
        duration: (v['duration'] as String?) ?? '-',
        coinPrice: price,
      ));
    });
    // Sort by unlock_biome order, then by price within biome.
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
  final int playerWorld;
  const _PowerUpRow({required this.entry, required this.playerWorld});

  bool get _isUnlocked {
    final reqWorld = _biomeToWorld[entry.unlockBiome] ?? 1;
    return playerWorld >= reqWorld;
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _isUnlocked;
    return Opacity(
      opacity: unlocked ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
          border: Border.all(color: _cGreenDarker, width: 0.5),
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
                    color: _cAmber, label: entry.id, borderRadius: 6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.displayName,
                      style: const TextStyle(
                          color: _cGreenPale,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.category.toUpperCase()} · ${entry.duration}',
                    style: const TextStyle(color: _cGreenMid, fontSize: 9),
                  ),
                  if (!unlocked) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Unlocks at ${entry.unlockBiome.toUpperCase()} biome',
                      style: const TextStyle(
                          color: _cAmberDark,
                          fontSize: 9,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (unlocked)
              _BuyPill(
                onTap: () => _attemptPurchase(context),
                child: _CoinAmount(amount: entry.coinPrice),
              )
            else
              const _LockedPill(),
          ],
        ),
      ),
    );
  }

  void _attemptPurchase(BuildContext context) {
    final economy = context.read<EconomyState>();
    if (!economy.spendCoins(entry.coinPrice)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }
    economy.grantPowerUp(entry.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('+1 ${entry.displayName}')),
    );
  }
}

// =============================================================================
// Cards / pills / placeholders
// =============================================================================
class _IapPackCard extends StatelessWidget {
  final _PackEntry pack;
  final bool isGem;
  const _IapPackCard({required this.pack, required this.isGem});

  @override
  Widget build(BuildContext context) {
    final accent = isGem ? _cAmber : _cGreenLight;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            isGem ? 'assets/ui/icon_gem.png' : 'assets/ui/icon_coin.png',
            width: 36,
            height: 36,
            errorBuilder: AssetPlaceholder.image(
                color: accent, label: pack.id, borderRadius: 6),
          ),
          const SizedBox(height: 6),
          Text(
            _formatNumber(pack.amount),
            style: TextStyle(
                color: accent, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            pack.id,
            style: const TextStyle(
                color: _cGreenMid, fontSize: 9, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showSnack(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _cGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '\$${pack.priceUsd.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: _cGreenPale,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('IAP flow for ${pack.id} not yet wired')),
    );
  }
}

class _ChestRow extends StatelessWidget {
  final _ChestEntry chest;
  const _ChestRow({required this.chest});

  String get _label {
    final base = chest.id.replaceAll('_chest', '');
    return base.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _ChestPreviewSheet.show(context, chest, _label),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1a0d).withValues(alpha: 0.95),
          border: Border.all(color: _cGreen, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Image.asset(
                'assets/ui/icon_${chest.id}.png',
                fit: BoxFit.contain,
                errorBuilder: AssetPlaceholder.image(
                    color: _cAmber, label: chest.id, borderRadius: 6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label,
                      style: const TextStyle(
                          color: _cGreenPale,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Text(chest.id,
                      style: const TextStyle(
                          color: _cGreenMid,
                          fontSize: 9,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _BuyPill(
              onTap: () =>
                  _ChestRowActions.buyWithCoins(context, chest, _label),
              child: _CoinAmount(amount: chest.coinPrice),
            ),
            const SizedBox(width: 6),
            _BuyPill(
              onTap: () =>
                  _ChestRowActions.buyWithGems(context, chest, _label),
              color: _cGemBg,
              borderColor: _cAmber,
              child: _GemAmount(amount: chest.gemPrice),
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
    final all = RemoteConfigService.instance.chests;
    final v = all[chest.id];
    return v is Map<String, dynamic> ? v : <String, dynamic>{};
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
/// and [_ChestPreviewSheet] (preview buttons). Keeping the spend logic in
/// one place so the snackbar copy stays consistent.
class _ChestRowActions {
  _ChestRowActions._();

  static void buyWithCoins(
      BuildContext context, _ChestEntry chest, String label) {
    final economy = context.read<EconomyState>();
    if (!economy.spendCoins(chest.coinPrice)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label chest opened (sim)')),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label chest opened (sim)')),
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

class _LockedPill extends StatelessWidget {
  const _LockedPill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _cGreenDark,
          border: Border.all(color: _cAmberDark, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 12, color: _cAmberDark),
            SizedBox(width: 4),
            Text('LOCKED',
                style: TextStyle(
                    color: _cAmberDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6)),
          ],
        ),
      );
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _cAmberDark,
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _SectionHint extends StatelessWidget {
  final String icon;
  final String text;
  final Color tintBg;
  final Color tintBorder;
  final Color textColor;
  const _SectionHint({
    required this.icon,
    required this.text,
    required this.tintBg,
    required this.tintBorder,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tintBg.withValues(alpha: 0.3),
          border: Border.all(color: tintBorder, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Image.asset(icon,
                width: 14,
                height: 14,
                errorBuilder: AssetPlaceholder.image(
                    color: _cAmber, label: 'h', borderRadius: 2)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: textColor, fontSize: 10),
              ),
            ),
          ],
        ),
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
  const _PackEntry({
    required this.id,
    required this.amount,
    required this.priceUsd,
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
