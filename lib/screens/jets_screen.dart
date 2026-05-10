import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/jet_model.dart';
import '../widgets/jet_card.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenMid = Color(0xFF639922);
const _cAmber = Color(0xFFEF9F27);
const _cAmberBg = Color(0xFF412402);
const _cDivider = Color(0xFF1a2a1a);
const _cCardBg = Color(0xFF0d1f0d);

// ---------------------------------------------------------------------------
// Initial jets data
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
    price: 0,
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
    price: 0,
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
    price: 300,
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
    price: 600,
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
    price: 0,
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
    price: 0,
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
  int _gems = 80;

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
    if (_gems < jet.price) {
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
                'This will cost 💎 ${jet.price} gems.',
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
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString('equipped_jet', jet.id);
                        if (!mounted) return;
                        setState(() {
                          _gems -= jet.price;
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
                _buildTopBar(),
                Expanded(child: _buildGrid()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),
              const Text(
                'JETS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _cGreenPale,
                  letterSpacing: 2,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _cAmberBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '💎 $_gems',
                  style: const TextStyle(fontSize: 10, color: _cAmber),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: _cDivider),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Grid
  // ---------------------------------------------------------------------------
  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.74,
      ),
      itemCount: _jets.length,
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

