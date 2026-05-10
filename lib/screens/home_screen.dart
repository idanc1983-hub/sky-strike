import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../economy/constants/ace_dialogue_catalog.dart';
import '../economy/state/economy_state.dart';
import '../economy/ui/challenge_reveal_sequence.dart';
import '../economy/ui/operation_banner.dart';
import '../economy/ui/pre_mission_popup.dart';
import '../game/models.dart';

// ---------------------------------------------------------------------------
// Biome config
// ---------------------------------------------------------------------------
class _Biome {
  final String bgAsset;
  final String enemyAsset;
  final String enemyLabel;
  final String worldName;
  final Color placeholderColor;

  const _Biome({
    required this.bgAsset,
    required this.enemyAsset,
    required this.enemyLabel,
    required this.worldName,
    required this.placeholderColor,
  });
}

const _biomes = <int, _Biome>{
  1: _Biome(
    bgAsset: 'assets/backgrounds/bg_jungle.png',
    enemyAsset: 'assets/enemies/enemy_jungle.png',
    enemyLabel: 'biplanes',
    worldName: 'Jungle',
    placeholderColor: Color(0xFF1a3a0a),
  ),
  2: _Biome(
    bgAsset: 'assets/backgrounds/bg_ocean.png',
    enemyAsset: 'assets/enemies/enemy_ocean.png',
    enemyLabel: 'naval jets',
    worldName: 'Ocean',
    placeholderColor: Color(0xFF0a1a3a),
  ),
  3: _Biome(
    bgAsset: 'assets/backgrounds/bg_desert.png',
    enemyAsset: 'assets/enemies/enemy_desert.png',
    enemyLabel: 'stealth drones',
    worldName: 'Desert',
    placeholderColor: Color(0xFF3a2a0a),
  ),
  4: _Biome(
    bgAsset: 'assets/backgrounds/bg_volcano.png',
    enemyAsset: 'assets/enemies/enemy_volcano.png',
    enemyLabel: 'fire bombers',
    worldName: 'Volcano',
    placeholderColor: Color(0xFF3a0a0a),
  ),
  5: _Biome(
    bgAsset: 'assets/backgrounds/bg_arctic.png',
    enemyAsset: 'assets/enemies/enemy_arctic.png',
    enemyLabel: 'cryo jets',
    worldName: 'Arctic',
    placeholderColor: Color(0xFF1a2a3a),
  ),
  6: _Biome(
    bgAsset: 'assets/backgrounds/bg_city.png',
    enemyAsset: 'assets/enemies/enemy_city.png',
    enemyLabel: 'rogue AI jets',
    worldName: 'Megacity',
    placeholderColor: Color(0xFF1a1a2a),
  ),
};

// ---------------------------------------------------------------------------
// Palette constants
// ---------------------------------------------------------------------------
const _cGreen = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenDeep = Color(0xFF0a1a0a);
const _cAmber = Color(0xFFEF9F27);
const _cGreenLabel = Color(0xFF639922);
const _cGreenTrack = Color(0xFF0d1f0d);

// ---------------------------------------------------------------------------
// Enemy state
// ---------------------------------------------------------------------------
class _EnemyState {
  double x;
  double y;
  double speed;
  double driftPhase;
  EnemyTier tier;
  bool flashing = false;
  int flashFrames = 0;
  bool exploding = false;
  int explosionFrame = 0;
  int respawnDelay = 0;

  _EnemyState({
    required this.x,
    required this.y,
    required this.speed,
    required this.driftPhase,
    required this.tier,
  });
}

// ---------------------------------------------------------------------------
// Bullet state
// ---------------------------------------------------------------------------
class _Bullet {
  double x;
  double y;

  _Bullet({required this.x, required this.y});
}

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Animation — started after all images resolve (prevents square-enemy bug on home screen)
  Ticker? _ticker;
  int _frame = 0;
  int _pendingImageLoads = 5; // bg + jet + enemy + bullet + explosion

  // Background scroll
  double _bgOffset = 0;

  // Player jet
  double _jetX = 0;
  double _jetDx = 0.55;

  // Bullets
  final List<_Bullet> _bullets = [];
  int _bulletTimer = 0;

  // Enemies
  final List<_EnemyState> _enemies = [];

  // Images
  ui.Image? _bgImage;
  ui.Image? _jetImage;
  ui.Image? _enemyImage;
  ui.Image? _bulletImage;
  ui.Image? _explosionSheet;
  bool _bgLoaded = false;
  bool _jetLoaded = false;
  bool _enemyLoaded = false;
  bool _bulletLoaded = false;
  bool _explosionLoaded = false;
  int _currentBiomeLoaded = 0;


  // Cached screen dimensions for simulation (set in build, consumed in _onTick)
  double _screenW = 0;
  double _screenH = 0;

  final _rng = Random();

  /// Captured in [didChangeDependencies] so non-build callbacks (timers,
  /// ticker, image loaders) can read the same instance without going
  /// through `context`. The reactive subscription happens via
  /// `context.watch<EconomyState>()` in [build].
  EconomyState? _economy;

  /// Guards against double-launch (rapid taps on LAUNCH MISSION). Cleared
  /// when the launched route returns.
  bool _launchInFlight = false;

  @override
  void initState() {
    super.initState();
    // Ticker is started once all images resolve (see _onImageLoaded).
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _economy ??= context.read<EconomyState>();
    _loadBiomeAssets();
    _loadExplosionSheet();
  }

  void _loadBiomeAssets() {
    final world = _economy?.currentWorld ?? 1;
    if (_currentBiomeLoaded == world) return;
    _currentBiomeLoaded = world;

    _bgLoaded = false;
    _jetLoaded = false;
    _enemyLoaded = false;
    _bulletLoaded = false;

    _loadImage('assets/backgrounds/Home_screen_Airstrip.png', (img) => setState(() {
          _bgImage = img;
          _bgLoaded = true;
          _onImageLoaded();
        }));
    _loadImage('assets/jets/jet_player.png', (img) => setState(() {
          _jetImage = img;
          _jetLoaded = true;
          _onImageLoaded();
        }));
    _loadImage('assets/enemies/Arctic_enemy_3.png', (img) => setState(() {
          _enemyImage = img;
          _enemyLoaded = true;
          _onImageLoaded();
        }));
    _loadImage(bulletAsset(world), (img) => setState(() {
          _bulletImage = img;
          _bulletLoaded = true;
          _onImageLoaded();
        }));
  }

  void _loadExplosionSheet() {
    if (_explosionLoaded) return;
    _loadImage('assets/ui/explosion_sheet.png', (img) => setState(() {
          _explosionSheet = img;
          _explosionLoaded = true;
          _onImageLoaded();
        }));
  }

  void _loadImage(String asset, void Function(ui.Image) onLoad) {
    final config = ImageConfiguration(bundle: DefaultAssetBundle.of(context));
    final stream = AssetImage(asset).resolve(config);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        onLoad(info.image);
      },
      // Errored loads must still tick the pending counter — otherwise
      // the home screen freezes on a static frame because the ticker
      // never starts. Treat a missing asset like a successful no-op.
      onError: (_, __) {
        stream.removeListener(listener);
        if (mounted) _onImageLoaded();
      },
    );
    stream.addListener(listener);
  }

  void _onImageLoaded() {
    if (_ticker != null) return; // already started
    _pendingImageLoads--;
    if (_pendingImageLoads <= 0) {
      _ticker = createTicker(_onTick)..start();
    }
  }

  void _initEnemies(double screenWidth) {
    if (_enemies.isNotEmpty) return;
    final tiers = activeEnemyTiers(_economy?.currentStage ?? 1);
    for (int i = 0; i < 7; i++) {
      final tier = tiers[_rng.nextInt(tiers.length)];
      final cfg = kEnemyConfigs[tier]!;
      _enemies.add(_EnemyState(
        x: (screenWidth / 7) * i + _rng.nextDouble() * 30,
        y: -(_rng.nextDouble() * 100 + 20),
        speed: cfg.baseSpeed * (0.8 + _rng.nextDouble() * 0.4),
        driftPhase: _rng.nextDouble() * pi * 2,
        tier: tier,
      ));
    }
    _jetX = screenWidth / 2;
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_screenW > 0) {
      _initEnemies(_screenW);
      _updateSimulation(_screenW, _screenH);
    }
    setState(() {
      _frame++;
    });
  }

  void _updateSimulation(double screenWidth, double screenHeight) {
    // Background scroll
    _bgOffset += 0.4;
    final bgH = _bgImage != null
        ? _bgImage!.height.toDouble() * (screenWidth / _bgImage!.width)
        : screenHeight;
    if (_bgOffset >= bgH) _bgOffset = 0;

    // Player jet patrol
    _jetX += _jetDx;
    if (_jetX > screenWidth - 20) _jetDx = -0.55;
    if (_jetX < 20) _jetDx = 0.55;

    // Bullets
    _bulletTimer++;
    if (_bulletTimer >= 20) {
      _bulletTimer = 0;
      _bullets.add(_Bullet(x: _jetX, y: screenHeight * 0.78 - 20));
    }
    _bullets.removeWhere((b) {
      b.y -= 4;
      return b.y < -10;
    });

    // Enemies
    for (final e in _enemies) {
      if (e.respawnDelay > 0) {
        e.respawnDelay--;
        if (e.respawnDelay == 0) {
          final tiers = activeEnemyTiers(_economy?.currentStage ?? 1);
          e.tier = tiers[_rng.nextInt(tiers.length)];
          e.x = _rng.nextDouble() * screenWidth;
          e.y = -20;
          e.exploding = false;
          e.flashing = false;
          e.explosionFrame = 0;
        }
        continue;
      }

      if (e.exploding) {
        e.explosionFrame++;
        if (e.explosionFrame >= 16) {
          e.respawnDelay = 55;
        }
        continue;
      }

      if (e.flashing) {
        e.flashFrames--;
        if (e.flashFrames <= 0) {
          e.flashing = false;
          e.exploding = true;
          e.explosionFrame = 0;
        }
        continue;
      }

      e.y += e.speed;
      e.x += sin(_frame * 0.04 + e.driftPhase) * 0.4;

      if (e.y > screenHeight + 20) {
        e.y = -20;
        e.x = _rng.nextDouble() * screenWidth;
      }

      // Collision with bullets
      _Bullet? hitBullet;
      for (final b in _bullets) {
        if ((b.x - e.x).abs() < 20 && (b.y - e.y).abs() < 20) {
          e.flashing = true;
          e.flashFrames = 2;
          hitBullet = b;
          break;
        }
      }
      if (hitBullet != null) _bullets.remove(hitBullet);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }


  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;

    _screenW = screenW;
    _screenH = screenH;

    // Default to W1 if the persisted world is out of range (corrupt
    // save / debug grant) so the home screen renders without crashing.
    final biome = _biomes[economy.currentWorld] ?? _biomes[1]!;

    return Scaffold(
      backgroundColor: _cGreenDeep,
      body: Stack(
        children: [
          // Layer 1: animated background canvas
          RepaintBoundary(
            child: CustomPaint(
              size: Size(screenW, screenH),
              painter: _BackgroundPainter(
                bgImage: _bgLoaded ? _bgImage : null,
                jetImage: _jetLoaded ? _jetImage : null,
                enemyImage: _enemyLoaded ? _enemyImage : null,
                bulletImage: _bulletLoaded ? _bulletImage : null,
                explosionSheet: _explosionLoaded ? _explosionSheet : null,
                bgOffset: _bgOffset,
                jetX: _jetX,
                jetY: screenH * 0.78,
                bullets: List.unmodifiable(_bullets),
                enemies: List.unmodifiable(_enemies),
                biomePlaceholder: biome.placeholderColor,
                screenW: screenW,
                screenH: screenH,
              ),
            ),
          ),

          // Layer 2: UI
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(economy),
                _buildLeaderboardRow(),
                Expanded(child: _buildCentreContent(economy, biome, screenW)),
                const OperationBanner(),
                const SizedBox(height: 4),
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
  Widget _buildTopBar(EconomyState economy) {
    return Padding(
      padding: const EdgeInsets.all(9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _chip('Lv ${economy.level}',
              bg: const Color(0xFF173404),
              opacity: 0.85,
              textColor: _cGreenLight),
          // FTUE: coin chip is hidden until Stage 1 first clear.
          if (economy.showHomeBalance)
            _chip('★ ${economy.coins}',
                bg: const Color(0xFF173404),
                opacity: 0.85,
                textColor: _cGreenPale),
          _chip('💎 ${economy.gems}',
              bg: const Color(0xFF412402),
              opacity: 0.85,
              textColor: _cAmber),
        ],
      ),
    );
  }

  Widget _chip(String text,
      {required Color bg, required double opacity, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(color: textColor, fontSize: 11)),
    );
  }

  // ---------------------------------------------------------------------------
  // Leaderboard row
  // ---------------------------------------------------------------------------
  Widget _buildLeaderboardRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Coming soon'))),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF050A05).withValues(alpha: 0.8),
                border: Border.all(color: _cGreen, width: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '🏆 Leaderboard',
                style: TextStyle(color: _cGreenLight, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Centre content
  // ---------------------------------------------------------------------------
  Widget _buildCentreContent(EconomyState economy, _Biome biome, double screenW) {
    // Defensive divisor — if a corrupt save or backend bug ever pushed
    // xpMax to 0, the bar would render NaN and the FractionallySizedBox
    // assertion would crash the home tab.
    final xpMaxSafe = economy.xpMax > 0 ? economy.xpMax : 1;
    final xpFraction = economy.xp / xpMaxSafe;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title
        const Text(
          'SKYSTRIKE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w500,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        // Subtitle
        const Text(
          'AERIAL COMBAT',
          style: TextStyle(
            color: Color(0xFFaaaaaa),
            fontSize: 11,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 10),

        // Mission badge
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF050F05).withValues(alpha: 0.82),
            border: Border.all(color: _cGreen, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              const Text(
                'CURRENT MISSION',
                style: TextStyle(color: _cGreenLabel, fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                '${biome.worldName} · Stage ${economy.currentStage}',
                style: const TextStyle(
                  color: _cGreenPale,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // XP label row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level ${economy.level}',
                  style:
                      const TextStyle(color: _cGreenLabel, fontSize: 10)),
              Text('${economy.xp} / ${economy.xpMax} XP',
                  style:
                      const TextStyle(color: _cGreenLabel, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // XP bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(builder: (ctx, constraints) {
            return Container(
              height: 5,
              decoration: BoxDecoration(
                color: _cGreenTrack,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: xpFraction.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cGreen,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),

        // Launch Mission button — long-press for debug Stage-3-clear sim.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: GestureDetector(
              onLongPress: () => _onLaunchLongPressed(economy),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _cGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _onLaunchPressed(economy),
                child: const Text(
                  'LAUNCH MISSION',
                  style: TextStyle(
                    color: _cGreenPale,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onLaunchPressed(EconomyState economy) async {
    if (_launchInFlight) return;
    _launchInFlight = true;
    try {
      final ok = await PreMissionPopup.show(
        context,
        world: economy.currentWorld,
        stage: economy.currentStage,
      );
      if (!mounted || !ok) return;
      economy.beginStage(economy.currentStage);
      if (!mounted) return;
      // Await the result so the stage clear's `stageDelta` actually
      // advances `currentStage`. Without the await the result map is
      // dropped on the floor and the player keeps replaying the same
      // stage forever.
      final result = await Navigator.pushNamed(
        context,
        '/loading',
        arguments: {
          'world': economy.currentWorld,
          'stage': economy.currentStage,
        },
      );
      if (!mounted) return;
      if (result is Map && result['stageDelta'] is int) {
        final delta = result['stageDelta'] as int;
        if (delta > 0) {
          economy.setCurrentStage(economy.currentStage + delta);
        }
      }
    } finally {
      if (mounted) _launchInFlight = false;
    }
  }

  /// Long-press LAUNCH debug hook: simulates a Stage 3 clear so the
  /// challenge reveal sequence can be tested without the real gameplay
  /// loop. Removed when real `onStageCleared` integration lands.
  Future<void> _onLaunchLongPressed(EconomyState economy) async {
    final outcome = economy.debugSimulateStageClear(
      world: 1,
      stage: 3,
      stars: 3,
      isBossDefeat: true,
      diedDuringRun: false,
      simulatedRunCoins: 600,
    );
    if (!mounted) return;
    if (outcome.shouldShowChallengeReveal) {
      economy.markChallengeRevealed();
      final type = economy.activeChallengeType;
      if (type != null) {
        await ChallengeRevealSequence.show(context, type);
        if (!mounted) return;
        economy.requestAceLine(AceLineKeys.aceChallengeRevealClose);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stage 3 already cleared. Awarded ${outcome.reward.coins} coins.',
          ),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Background canvas painter
// ---------------------------------------------------------------------------
class _BackgroundPainter extends CustomPainter {
  final ui.Image? bgImage;
  final ui.Image? jetImage;
  final ui.Image? enemyImage;
  final ui.Image? bulletImage;
  final ui.Image? explosionSheet;
  final double bgOffset;
  final double jetX;
  final double jetY;
  final List<_Bullet> bullets;
  final List<_EnemyState> enemies;
  final Color biomePlaceholder;
  final double screenW;
  final double screenH;

  _BackgroundPainter({
    required this.bgImage,
    required this.jetImage,
    required this.enemyImage,
    required this.bulletImage,
    required this.explosionSheet,
    required this.bgOffset,
    required this.jetX,
    required this.jetY,
    required this.bullets,
    required this.enemies,
    required this.biomePlaceholder,
    required this.screenW,
    required this.screenH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawEnemies(canvas, size);
    _drawBullets(canvas);
    _drawJet(canvas, size);
    _drawDarkOverlay(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    if (bgImage == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = biomePlaceholder,
      );
      return;
    }

    final img = bgImage!;
    final imgAspect = img.width / img.height;
    final drawH = size.width / imgAspect;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // Draw two tiles offset by bgOffset
    final paint = Paint()..filterQuality = FilterQuality.low;
    canvas.drawImageRect(
      img,
      src,
      Rect.fromLTWH(0, bgOffset - drawH, size.width, drawH),
      paint,
    );
    canvas.drawImageRect(
      img,
      src,
      Rect.fromLTWH(0, bgOffset, size.width, drawH),
      paint,
    );
    canvas.drawImageRect(
      img,
      src,
      Rect.fromLTWH(0, bgOffset + drawH, size.width, drawH),
      paint,
    );
  }

  void _drawEnemies(Canvas canvas, Size size) {
    for (final e in enemies) {
      if (e.respawnDelay > 0) continue;

      if (e.exploding && explosionSheet != null) {
        _drawExplosionFrame(canvas, e);
        continue;
      }

      final cfg = kEnemyConfigs[e.tier]!;
      final sz = cfg.renderSize;

      if (enemyImage != null) {
        final src = Rect.fromLTWH(
            0, 0, enemyImage!.width.toDouble(), enemyImage!.height.toDouble());
        final dst =
            Rect.fromCenter(center: Offset(e.x, e.y), width: sz, height: sz);
        canvas.save();
        canvas.translate(e.x, e.y);
        canvas.rotate(pi);
        canvas.translate(-e.x, -e.y);
        final imgPaint = e.flashing
            ? (Paint()
              ..colorFilter = const ColorFilter.matrix([
                1, 0, 0, 0, 255,
                0, 1, 0, 0, 255,
                0, 0, 1, 0, 255,
                0, 0, 0, 1, 0,
              ]))
            : Paint();
        canvas.drawImageRect(enemyImage!, src, dst, imgPaint);
        canvas.restore();
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(e.x, e.y), width: sz, height: sz),
            const Radius.circular(3),
          ),
          Paint()..color = cfg.placeholderColor,
        );
      }
    }
  }

  void _drawExplosionFrame(Canvas canvas, _EnemyState e) {
    final sheet = explosionSheet!;
    final frameIndex = (e.explosionFrame % 16);
    final col = frameIndex % 4;
    final row = frameIndex ~/ 4;
    const frameSize = 128.0;
    final src = Rect.fromLTWH(
        col * frameSize, row * frameSize, frameSize, frameSize);
    final dst = Rect.fromCenter(
        center: Offset(e.x, e.y), width: 48, height: 48);
    canvas.drawImageRect(sheet, src, dst, Paint());
  }

  void _drawBullets(Canvas canvas) {
    for (final b in bullets) {
      if (bulletImage != null) {
        final img = bulletImage!;
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src,
            Rect.fromCenter(center: Offset(b.x, b.y), width: 10, height: 18),
            Paint());
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(b.x, b.y), width: 3, height: 9),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF97C459),
        );
      }
    }
  }

  void _drawJet(Canvas canvas, Size size) {
    if (jetImage == null) {
      final paint = Paint()..color = const Color(0xFF97C459);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(jetX, jetY), width: 24, height: 32),
        paint,
      );
      return;
    }
    final src = Rect.fromLTWH(
        0, 0, jetImage!.width.toDouble(), jetImage!.height.toDouble());
    final dst =
        Rect.fromCenter(center: Offset(jetX, jetY), width: 44, height: 44);
    canvas.drawImageRect(jetImage!, src, dst, Paint());
  }

  void _drawDarkOverlay(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.40),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => true;
}

