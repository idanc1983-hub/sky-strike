import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/remote_config_service.dart';
import '../economy/state/economy_state.dart';
import '../models/jet_model.dart';
import '../shared/widgets/app_top_bar.dart';
import '../widgets/jet_card.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
const _cAmber = Color(0xFFEF9F27);

// ---------------------------------------------------------------------------
// v2 jet metadata
//
// The 6 jets are sourced from Remote Config `economy__jet_base_powers__v1`.
// Per Q3-(a): the starter jet keeps `jet_player` as the runtime ID for
// save-format compatibility, but its RC entry is keyed `basic` (display
// name + base_power come from there).
//
// Per the v2 economy plan, jets are NOT purchasable with gems. They unlock
// via biome progression (player reaches the jet's biome → eligible) and
// drop from biome chests at 10% per chest. The Jets screen models this
// as: if player has reached the jet's biome, treat as owned; otherwise
// locked. Full chest-drop ownership accounting comes later — for now this
// gives a working visualization of "unlock as you progress."
// ---------------------------------------------------------------------------

/// Code ID → RC jet key. Code IDs are stable for save compatibility; RC
/// keys are the canonical config names.
const Map<String, String> _codeIdToRcName = {
  'jet_player': 'basic',
  'wraith_x': 'Wraith X',
  'specter': 'Specter',
  'viper': 'Viper',
  'inferno': 'Inferno',
  'phantom': 'Phantom',
};

/// Display order — by biome progression (jungle → city).
const List<String> _orderedJetIds = [
  'jet_player', // jungle  · starter
  'wraith_x', // desert
  'specter', // sea
  'viper', // ice
  'inferno', // volcano
  'phantom', // city
];

const Map<String, String> _jetAssets = {
  'jet_player': 'assets/jets/jet_player.png',
  'wraith_x': 'assets/jets/jet_wraith_x.png',
  'specter': 'assets/jets/jet_specter.png',
  'viper': 'assets/jets/jet_viper.png',
  'inferno': 'assets/jets/jet_inferno.png',
  'phantom': 'assets/jets/jet_phantom.png',
};

const Map<String, String> _jetTiers = {
  'jet_player': 'Recon · Tier 1',
  'wraith_x': 'Stealth · Tier 2',
  'specter': 'Strike · Tier 3',
  'viper': 'Assault · Tier 4',
  'inferno': 'Heavy · Tier 5',
  'phantom': 'Apex · Tier 6',
};

class _JetPalette {
  final Color accent;
  final Color bg;
  const _JetPalette(this.accent, this.bg);
}

const Map<String, _JetPalette> _jetPalettes = {
  'jet_player': _JetPalette(Color(0xFF1D9E75), Color(0xFF0F2A18)),
  'wraith_x': _JetPalette(Color(0xFFD85A30), Color(0xFF2A0D0D)),
  'specter': _JetPalette(Color(0xFF378ADD), Color(0xFF0D1A30)),
  'viper': _JetPalette(Color(0xFFAB47BC), Color(0xFF1F0E25)),
  'inferno': _JetPalette(Color(0xFFEF9F27), Color(0xFF2A1200)),
  'phantom': _JetPalette(Color(0xFF7E57C2), Color(0xFF1A1428)),
};

/// Biome key → world index (1..6). Used to compute lock status against
/// `EconomyState.currentWorld`.
const Map<String, int> _biomeToWorld = {
  'jungle': 1,
  'desert': 2,
  'sea': 3,
  'ice': 4,
  'volcano': 5,
  'city': 6,
};

/// Highest base_power across all jets — used to normalize the 3 visual
/// stat bars (speed/attack/armor) since v2 only provides `base_power`.
/// Phantom = 650; if RC ships a higher-power jet later this still works.
const int _maxBasePower = 650;

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class JetsScreen extends StatefulWidget {
  const JetsScreen({super.key});

  @override
  State<JetsScreen> createState() => _JetsScreenState();
}

class _JetsScreenState extends State<JetsScreen> {
  String _equippedId = 'jet_player';

  @override
  void initState() {
    super.initState();
    _loadEquipped();
  }

  Future<void> _loadEquipped() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('equipped_jet');
    if (id != null && mounted) {
      setState(() => _equippedId = id);
    }
  }

  Future<void> _equipJet(String jetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('equipped_jet', jetId);
    if (!mounted) return;
    setState(() => _equippedId = jetId);
  }

  /// Builds the ordered jet list with status computed from RC + player
  /// progression. Returns empty when RC has no jet data (defensive).
  List<JetModel> _buildJets(int currentWorld) {
    final rcJets = RemoteConfigService.instance.jetBasePowers;
    if (rcJets.isEmpty) return const [];
    final out = <JetModel>[];
    for (final codeId in _orderedJetIds) {
      final rcName = _codeIdToRcName[codeId];
      if (rcName == null) continue;
      final entry = rcJets[rcName];
      if (entry is! Map) continue;

      final basePower = (entry['base_power'] as num?)?.toInt() ?? 0;
      final unlockBiome = (entry['unlock_biome'] as String?) ?? 'jungle';
      final unlockWorld = _biomeToWorld[unlockBiome] ?? 1;
      final unlocked = currentWorld >= unlockWorld;

      // Status: equipped > owned (if unlocked) > locked
      final JetStatus status;
      if (!unlocked) {
        status = JetStatus.locked;
      } else if (codeId == _equippedId) {
        status = JetStatus.equipped;
      } else {
        status = JetStatus.owned;
      }

      // Normalized stat fill (0..100). v2 only ships base_power, so the
      // three visual bars all show the same normalized value.
      final stat = ((basePower / _maxBasePower) * 100).round().clamp(0, 100);

      final palette =
          _jetPalettes[codeId] ?? const _JetPalette(Color(0xFF444444), Color(0xFF141414));

      out.add(JetModel(
        id: codeId,
        name: rcName, // display name from RC
        tier: _jetTiers[codeId] ?? 'Tier ?',
        speed: stat,
        attack: stat,
        armor: stat,
        accentColor: palette.accent,
        bgColor: palette.bg,
        status: status,
        price: 0, // jets are not gem-bought in v2
        unlockCondition: unlocked ? null : 'Unlocks at ${unlockBiome.toUpperCase()} biome',
        assetPath: _jetAssets[codeId] ?? 'assets/jets/jet_player.png',
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final jets = _buildJets(economy.currentWorld);
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
                const AppTopBar.full(),
                Expanded(child: _buildList(jets)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Jet list
  // ---------------------------------------------------------------------------
  Widget _buildList(List<JetModel> jets) {
    if (jets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No jet data — check Remote Config '
            '(economy__jet_base_powers__v1)',
            textAlign: TextAlign.center,
            style: TextStyle(color: _cAmber, fontSize: 12),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      itemCount: jets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final jet = jets[index];
        return JetCard(
          jet: jet,
          onEquip: jet.status == JetStatus.owned ? () => _equipJet(jet.id) : null,
          // Jets are not gem-bought in v2 — onBuy is intentionally null so
          // the JetCard renders no buy button. Ownership comes from biome
          // progression + biome chests (10% drop) + monetization bundles.
          onBuy: null,
        );
      },
    );
  }
}
