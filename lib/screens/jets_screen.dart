import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../economy/state/economy_state.dart';
import '../models/jet_model.dart';
import '../shared/widgets/asset_placeholder.dart';
import '../widgets/jet_card.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenMid = Color(0xFF639922);
const _cAmber = Color(0xFFEF9F27);
const _cAmberBg = Color(0xFF412402);
const _cCardBg = Color(0xFF0d1f0d);

// ---------------------------------------------------------------------------
// Initial jets data
//
// Placeholder seed for the simulator preview. Once the jet-tab plumbing is
// wired to remote config, both the list order and the per-jet `price` will
// come from `remote_config.jets[]` and this seed becomes a default fallback.
//
// Asset paths map to existing shop jet images:
//   scout   → jet_viper.png   (starter / Recon Tier 1)
//   phantom → jet_phantom.png
//   inferno → jet_inferno.png
//   wraith  → jet_wraith_x.png
//   nova    → jet_specter.png
//   eclipse → jet_player.png
// ---------------------------------------------------------------------------
const _kInitialJets = <JetModel>[
  JetModel(
    id: 'scout',
    name: 'Scout',
    tier: 'Recon · Tier 1',
    speed: 88,
    attack: 52,
    armor: 60,
    accentColor: Color(0xFF1D9E75),
    bgColor: Color(0xFF0F2A18),
    status: JetStatus.equipped,
    price: 50,
    assetPath: 'assets/jets/jet_viper.png',
  ),
  JetModel(
    id: 'phantom',
    name: 'Phantom',
    tier: 'Stealth · Tier 2',
    speed: 94,
    attack: 68,
    armor: 72,
    accentColor: Color(0xFF378ADD),
    bgColor: Color(0xFF0D1A30),
    status: JetStatus.owned,
    price: 75,
    assetPath: 'assets/jets/jet_phantom.png',
  ),
  JetModel(
    id: 'inferno',
    name: 'Inferno',
    tier: 'Assault · Tier 3',
    speed: 74,
    attack: 96,
    armor: 80,
    accentColor: Color(0xFFEF9F27),
    bgColor: Color(0xFF2A1200),
    status: JetStatus.purchasable,
    price: 100,
    assetPath: 'assets/jets/jet_inferno.png',
  ),
  JetModel(
    id: 'wraith',
    name: 'Wraith',
    tier: 'Spectre · Tier 4',
    speed: 98,
    attack: 88,
    armor: 65,
    accentColor: Color(0xFFD85A30),
    bgColor: Color(0xFF2A0D0D),
    status: JetStatus.purchasable,
    price: 340,
    assetPath: 'assets/jets/jet_wraith_x.png',
  ),
  JetModel(
    id: 'nova',
    name: 'Nova',
    tier: 'Titan · Tier 5',
    speed: 0,
    attack: 0,
    armor: 0,
    accentColor: Color(0xFF444444),
    bgColor: Color(0xFF141414),
    status: JetStatus.locked,
    unlockCondition: 'Reach World 6',
    price: 800,
    assetPath: 'assets/jets/jet_specter.png',
  ),
  JetModel(
    id: 'eclipse',
    name: 'Eclipse',
    tier: 'Apex · Tier 6',
    speed: 0,
    attack: 0,
    armor: 0,
    accentColor: Color(0xFF444444),
    bgColor: Color(0xFF141414),
    status: JetStatus.locked,
    unlockCondition: 'Reach World 8',
    price: 1200,
    assetPath: 'assets/jets/jet_player.png',
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class JetsScreen extends StatefulWidget {
  const JetsScreen({super.key});

  @override
  State<JetsScreen> createState() => _JetsScreenState();
}

class _JetsScreenState extends State<JetsScreen> {
  late List<JetModel> _jets;

  @override
  void initState() {
    super.initState();
    _jets = List<JetModel>.from(_kInitialJets);
    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final equippedId = prefs.getString('equipped_jet');
    if (equippedId == null) return;
    if (!mounted) return;
    setState(() {
      _jets = _jets.map((j) {
        if (j.status == JetStatus.equipped) return j.copyWith(status: JetStatus.owned);
        if (j.id == equippedId &&
            j.status != JetStatus.locked &&
            j.status != JetStatus.purchasable) {
          return j.copyWith(status: JetStatus.equipped);
        }
        return j;
      }).toList();
    });
  }

  Future<void> _equipJet(JetModel jet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('equipped_jet', jet.id);
    if (!mounted) return;
    setState(() {
      _jets = _jets.map((j) {
        if (j.status == JetStatus.equipped) return j.copyWith(status: JetStatus.owned);
        if (j.id == jet.id) return j.copyWith(status: JetStatus.equipped);
        return j;
      }).toList();
    });
  }

  void _buyJet(JetModel jet) {
    final economy = context.read<EconomyState>();
    if (economy.gems < jet.price) {
      _showSnackBar('Not enough gems');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Buy ${jet.name}?',
                style: const TextStyle(
                  color: _cGreenPale,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will cost ${jet.price} gems.',
                style: const TextStyle(color: _cGreenMid, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: _cGreenMid, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: _cGreenMid, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        final ok = economy.spendGems(jet.price);
                        if (!ok) {
                          if (mounted) _showSnackBar('Not enough gems');
                          return;
                        }
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString('equipped_jet', jet.id);
                        if (!mounted) return;
                        setState(() {
                          _jets = _jets.map((j) {
                            if (j.status == JetStatus.equipped) {
                              return j.copyWith(status: JetStatus.owned);
                            }
                            if (j.id == jet.id) {
                              return j.copyWith(status: JetStatus.equipped);
                            }
                            return j;
                          }).toList();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _cAmberBg,
                          border: Border.all(color: _cAmber, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Confirm',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _cAmber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: _cCardBg,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF0a1a0a)),
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/Jets_screen.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(economy),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar — level pill on the left, coin + gem chips on the right.
  // Mirrors the home screen so currencies feel consistent across tabs.
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(EconomyState economy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _levelChip(economy.level),
          Row(
            children: [
              _currencyChip(
                amount: economy.coins,
                asset: 'assets/ui/icon_coin.png',
                placeholderLabel: 'coin',
                placeholderColor: _cAmber,
              ),
              const SizedBox(width: 8),
              _currencyChip(
                amount: economy.gems,
                asset: 'assets/ui/icon_gem.png',
                placeholderLabel: 'gem',
                placeholderColor: const Color(0xFF7BB8FF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _levelChip(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1606).withValues(alpha: 0.92),
        border: Border.all(color: _cAmber.withValues(alpha: 0.55), width: 0.6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        'Lv. $level',
        style: const TextStyle(
          color: _cGreenPale,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _currencyChip({
    required int amount,
    required String asset,
    required String placeholderLabel,
    required Color placeholderColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1606).withValues(alpha: 0.92),
        border: Border.all(color: _cAmber.withValues(alpha: 0.55), width: 0.6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$amount',
            style: const TextStyle(
              color: _cGreenPale,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 18,
            height: 18,
            child: Image.asset(
              asset,
              errorBuilder: AssetPlaceholder.image(
                color: placeholderColor,
                label: placeholderLabel,
                borderRadius: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Jet list — full-width cards, vertical scroll
  // ---------------------------------------------------------------------------
  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      itemCount: _jets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final jet = _jets[index];
        return JetCard(
          jet: jet,
          onEquip: jet.status == JetStatus.owned
              ? () => _equipJet(jet)
              : null,
          onBuy: jet.status == JetStatus.purchasable
              ? () => _buyJet(jet)
              : null,
        );
      },
    );
  }
}
