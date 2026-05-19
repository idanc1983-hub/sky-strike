import 'dart:async';
import 'package:flutter/material.dart';

const _cGreen = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenMid = Color(0xFF639922);

// Biome ordering follows Levels-economy.xlsx — one biome per 10 levels:
// W1 Jungle (1–10) → W2 Desert (11–20) → W3 Sea (21–30) →
// W4 Arctic (31–40) → W5 Volcano (41–50) → W6 City (51–60).
const _worldNames = {
  1: 'Jungle',
  2: 'Desert',
  3: 'Sea',
  4: 'Arctic',
  5: 'Volcano',
  6: 'City',
};

String _loadingBg(int world) {
  const map = <int, String>{
    1: 'assets/backgrounds/Jungle_loading.png',
    2: 'assets/backgrounds/Desert_loading.png',
    3: 'assets/backgrounds/Sea_loading.png',
    4: 'assets/backgrounds/Arctic_loading.png',
    5: 'assets/backgrounds/Volcano_loading.png',
    6: 'assets/backgrounds/City_loading.png',
  };
  return map[world] ?? 'assets/backgrounds/Jungle_loading.png';
}

const _tips = [
  'Scanning hostile airspace...',
  'Calibrating weapon systems...',
  'Establishing mission uplink...',
  'Deploying recon assets...',
  'Arming payload...',
  'Running flight diagnostics...',
  'Locking on targets...',
];

class LoadingScreen extends StatefulWidget {
  final int world;
  final int stage;

  const LoadingScreen({super.key, required this.world, required this.stage});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  int _tipIndex = 0;
  Timer? _tipTimer;
  bool _launched = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Multi-stage curve with realistic stalls at ~30%, ~62%, ~88%
    _progress = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.28)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 18),
      TweenSequenceItem(
          tween: Tween(begin: 0.28, end: 0.30)
              .chain(CurveTween(curve: Curves.linear)),
          weight: 7),
      TweenSequenceItem(
          tween: Tween(begin: 0.30, end: 0.61)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 22),
      TweenSequenceItem(
          tween: Tween(begin: 0.61, end: 0.63)
              .chain(CurveTween(curve: Curves.linear)),
          weight: 7),
      TweenSequenceItem(
          tween: Tween(begin: 0.63, end: 0.87)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 0.87, end: 0.89)
              .chain(CurveTween(curve: Curves.linear)),
          weight: 6),
      TweenSequenceItem(
          tween: Tween(begin: 0.89, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 20),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_launched) {
        if (!mounted) return;
        _launched = true;
        Navigator.pushReplacementNamed(
          context,
          '/game',
          arguments: {'world': widget.world, 'stage': widget.stage},
        );
      }
    });

    _controller.forward();

    _tipTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worldName = _worldNames[widget.world] ?? 'Jungle';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _loadingBg(widget.world),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF0a1a0a)),
          ),
          // Bottom-heavy dark gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x22000000),
                  Color(0x88000000),
                  Color(0xEE000000),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildWorldInfo(worldName),
                const Spacer(),
                _buildLoadingSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldInfo(String worldName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF173404).withValues(alpha: 0.88),
              border: Border.all(color: _cGreen, width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'WORLD ${widget.world}',
              style: const TextStyle(
                color: _cGreenLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            worldName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 5,
              shadows: [
                Shadow(
                  color: Color(0xFF3B6D11),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'STAGE  ${widget.stage}',
            style: const TextStyle(
              color: _cGreenPale,
              fontSize: 14,
              letterSpacing: 6,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tip text with animated crossfade
          SizedBox(
            height: 18,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Align(
                key: ValueKey(_tipIndex),
                alignment: Alignment.centerLeft,
                child: Text(
                  _tips[_tipIndex],
                  style: const TextStyle(
                    color: _cGreenMid,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Bar + percentage
          AnimatedBuilder(
            animation: _progress,
            builder: (_, __) {
              final pct = _progress.value.clamp(0.0, 1.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Track
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a2a1a),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B6D11), Color(0xFF97C459)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x7797C459),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LOADING',
                        style: TextStyle(
                          color: _cGreenMid,
                          fontSize: 9,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(pct * 100).toInt()}%',
                        style: const TextStyle(
                          color: _cGreenLight,
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
