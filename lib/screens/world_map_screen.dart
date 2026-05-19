import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../economy/state/economy_state.dart';
import '../shared/widgets/asset_placeholder.dart';
import 'menu_popup.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _cGreen = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenDeep = Color(0xFF071507);
const _cAmber = Color(0xFFEF9F27);

// World ordering matches HomeScreen / EconomyState (`currentWorld` 1–6).
const List<_BiomeMeta> _biomes = [
  _BiomeMeta(
    index: 1,
    name: 'Jungle',
    asset: 'assets/map/biome_jungle.png',
    fallback: Color(0xFF0d2008),
  ),
  _BiomeMeta(
    index: 2,
    name: 'Desert',
    asset: 'assets/map/biome_desert.png',
    fallback: Color(0xFF1f1005),
  ),
  _BiomeMeta(
    index: 3,
    name: 'Sea',
    asset: 'assets/map/biome_sea.png',
    fallback: Color(0xFF051020),
  ),
  _BiomeMeta(
    index: 4,
    name: 'Arctic',
    asset: 'assets/map/biome_ice.png',
    fallback: Color(0xFF051520),
  ),
  _BiomeMeta(
    index: 5,
    name: 'Volcano',
    asset: 'assets/map/biome_volcano.png',
    fallback: Color(0xFF1a0505),
  ),
  _BiomeMeta(
    index: 6,
    name: 'Megacity',
    asset: 'assets/map/biome_city.png',
    fallback: Color(0xFF0a0818),
  ),
];

// Visual constants
const double _biomeCardHeight = 140;
const double _connectorHeight = 24;

enum _BiomeState { completed, current, next, locked }

class _BiomeMeta {
  final int index;
  final String name;
  final String asset;
  final Color fallback;

  const _BiomeMeta({
    required this.index,
    required this.name,
    required this.asset,
    required this.fallback,
  });
}

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Auto-centre on the current world once layout settles. Read-only
    // peek at EconomyState — no listener needed since the map is static
    // for the duration of this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final economy = context.read<EconomyState>();
      final worldIndex = (economy.currentWorld - 1).clamp(0, _biomes.length - 1);
      const cardStride = _biomeCardHeight + _connectorHeight;
      final targetOffset = worldIndex * cardStride;
      final screenH = MediaQuery.of(context).size.height;
      final desired = targetOffset - (screenH / 2) + (_biomeCardHeight / 2);
      final clamped = desired.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final currentWorld = economy.currentWorld.clamp(1, _biomes.length);
    final maxWorld = economy.maxWorldReached.clamp(1, _biomes.length);

    return Scaffold(
      backgroundColor: _cGreenDeep,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/map/map_bg.png',
              fit: BoxFit.cover,
              errorBuilder: AssetPlaceholder.image(
                color: _cGreenDeep,
                label: 'map_bg',
                borderRadius: 0,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  // reverse:true lays out item 0 at the bottom so worlds
                  // progress upward — W1 lives at the bottom of the column
                  // and W6 sits at the top. Connectors stay above each
                  // card inside its column, which is what the visual flow
                  // wants since the next world is always above the one
                  // below it.
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    itemCount: _biomes.length,
                    itemBuilder: (ctx, i) {
                      final meta = _biomes[i];
                      final state = _resolveState(
                        worldIndex: meta.index,
                        currentWorld: currentWorld,
                        maxWorld: maxWorld,
                      );
                      return Column(
                        children: [
                          if (i > 0) _buildConnector(state),
                          _buildBiomeRow(meta, state),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _BiomeState _resolveState({
    required int worldIndex,
    required int currentWorld,
    required int maxWorld,
  }) {
    if (worldIndex < currentWorld) return _BiomeState.completed;
    if (worldIndex == currentWorld) return _BiomeState.current;
    if (worldIndex == currentWorld + 1 && worldIndex <= maxWorld + 1) {
      return _BiomeState.next;
    }
    return _BiomeState.locked;
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xF20A1A0A),
        border: Border(
          bottom: BorderSide(color: _cGreen, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          const Expanded(
            child: Text(
              'WORLD MAP',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _cGreenPale,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ),
          MenuCloseButton(onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  // ─── Connector ─────────────────────────────────────────────────────────────
  Widget _buildConnector(_BiomeState below) {
    final color = switch (below) {
      _BiomeState.completed => _cGreen,
      _BiomeState.current => _cGreen,
      _BiomeState.next => _cGreen.withValues(alpha: 0.30),
      _BiomeState.locked => _cGreen.withValues(alpha: 0.08),
    };
    return Container(width: 2, height: _connectorHeight, color: color);
  }

  // ─── Biome row ─────────────────────────────────────────────────────────────
  Widget _buildBiomeRow(_BiomeMeta meta, _BiomeState state) {
    return state == _BiomeState.locked
        ? _buildCloudCard(meta)
        : _buildBiomeCard(meta, state);
  }

  Widget _buildBiomeCard(_BiomeMeta meta, _BiomeState state) {
    final isCurrent = state == _BiomeState.current;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: _biomeCardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: switch (state) {
            _BiomeState.completed => _cGreen.withValues(alpha: 0.5),
            _BiomeState.current => _cGreenLight,
            _BiomeState.next => _cGreen.withValues(alpha: 0.30),
            _BiomeState.locked => Colors.transparent,
          },
          width: isCurrent ? 1.5 : 0.6,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Biome art
            Positioned.fill(
              child: Image.asset(
                meta.asset,
                fit: BoxFit.cover,
                errorBuilder: AssetPlaceholder.image(
                  color: meta.fallback,
                  label: 'biome_${meta.name.toLowerCase()}',
                  borderRadius: 12,
                ),
              ),
            ),
            // State-driven tint
            Positioned.fill(
              child: Container(
                color: switch (state) {
                  _BiomeState.completed =>
                    const Color(0xFF3B6D11).withValues(alpha: 0.40),
                  _BiomeState.current =>
                    Colors.black.withValues(alpha: 0.20),
                  _BiomeState.next =>
                    Colors.black.withValues(alpha: 0.65),
                  _BiomeState.locked => Colors.transparent,
                },
              ),
            ),
            // Top labels
            Positioned(
              left: 8,
              top: 8,
              right: 8,
              child: _buildCardTopRow(meta, state),
            ),
            // Bottom name bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildCardBottom(meta, state),
            ),
            // Jet marker — current world only
            if (isCurrent)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: _buildJetMarker(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTopRow(_BiomeMeta meta, _BiomeState state) {
    final label = switch (state) {
      _BiomeState.completed => 'Completed',
      _BiomeState.current => 'Current',
      _BiomeState.next => 'Next',
      _BiomeState.locked => '',
    };
    final labelColor = switch (state) {
      _BiomeState.completed => _cGreenLight,
      _BiomeState.current => _cGreenPale,
      _BiomeState.next => _cGreenPale.withValues(alpha: 0.55),
      _BiomeState.locked => Colors.transparent,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: labelColor,
              letterSpacing: 1,
            ),
          ),
        ),
        if (state == _BiomeState.completed)
          const Icon(Icons.check_circle_outline,
              color: _cGreenLight, size: 16),
      ],
    );
  }

  Widget _buildCardBottom(_BiomeMeta meta, _BiomeState state) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xCC071507),
      alignment: Alignment.centerLeft,
      child: Text(
        meta.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: switch (state) {
            _BiomeState.completed => _cGreenLight,
            _BiomeState.current => _cGreenPale,
            _BiomeState.next => _cGreenPale.withValues(alpha: 0.55),
            _BiomeState.locked => _cGreenPale.withValues(alpha: 0.25),
          },
        ),
      ),
    );
  }

  Widget _buildCloudCard(_BiomeMeta meta) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: _biomeCardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/map/cloud_dark.png',
                fit: BoxFit.cover,
                errorBuilder: AssetPlaceholder.image(
                  color: const Color(0xFF1a1a1a),
                  label: 'cloud',
                  borderRadius: 12,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, color: Colors.white24, size: 22),
                  SizedBox(height: 4),
                  Text(
                    'Locked',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Jet marker (pulsing) ─────────────────────────────────────────────────
  Widget _buildJetMarker() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, __) {
        final scale = _pulseAnimation.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 48 * scale,
              height: 48 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _cGreenLight.withValues(
                    alpha: (1.3 - scale).clamp(0.0, 1.0),
                  ),
                  width: 1.5,
                ),
              ),
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: Image.asset(
                'assets/jets/jet_player.png',
                fit: BoxFit.contain,
                errorBuilder: AssetPlaceholder.image(
                  color: _cAmber,
                  label: 'jet',
                  borderRadius: 6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
