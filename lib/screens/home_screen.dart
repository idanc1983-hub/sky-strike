import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../config/remote_config_service.dart';
import '../economy/state/challenge_state.dart';
import '../economy/state/economy_state.dart';
import '../economy/ui/challenge_prizes_popup.dart';
import '../economy/ui/pre_mission_popup.dart';
import '../economy/ui/snake_offer_popup.dart';
import '../economy/ui/three_plus_one_offer_popup.dart';
import '../game/models.dart';
import '../shared/widgets/app_top_bar.dart';
import '../shared/widgets/asset_placeholder.dart';

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

// World ordering follows Levels-economy.xlsx — one biome per 10 levels.
const _biomes = <int, _Biome>{
  1: _Biome(
    bgAsset: 'assets/backgrounds/bg_jungle.png',
    enemyAsset: 'assets/enemies/enemy_jungle.png',
    enemyLabel: 'biplanes',
    worldName: 'Jungle',
    placeholderColor: Color(0xFF1a3a0a),
  ),
  2: _Biome(
    bgAsset: 'assets/backgrounds/bg_desert.png',
    enemyAsset: 'assets/enemies/enemy_desert.png',
    enemyLabel: 'stealth drones',
    worldName: 'Desert',
    placeholderColor: Color(0xFF3a2a0a),
  ),
  3: _Biome(
    bgAsset: 'assets/backgrounds/bg_sea.png',
    enemyAsset: 'assets/enemies/enemy_sea.png',
    enemyLabel: 'naval jets',
    worldName: 'Sea',
    placeholderColor: Color(0xFF0a1a3a),
  ),
  4: _Biome(
    bgAsset: 'assets/backgrounds/bg_ice.png',
    enemyAsset: 'assets/enemies/enemy_ice.png',
    enemyLabel: 'cryo jets',
    worldName: 'Arctic',
    placeholderColor: Color(0xFF1a2a3a),
  ),
  5: _Biome(
    bgAsset: 'assets/backgrounds/bg_volcano.png',
    enemyAsset: 'assets/enemies/enemy_volcano.png',
    enemyLabel: 'fire bombers',
    worldName: 'Volcano',
    placeholderColor: Color(0xFF3a0a0a),
  ),
  6: _Biome(
    bgAsset: 'assets/backgrounds/bg_city.png',
    enemyAsset: 'assets/enemies/enemy_city.png',
    enemyLabel: 'rogue AI jets',
    worldName: 'City',
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
const _cChallengeBg = Color(0xFF040C04);
const _cChallengeBarTrack = Color(0xFF0d1a0d);

// ---------------------------------------------------------------------------
// Placeholder challenge cycle data
//
// The real values come from the active cycle's remote-config entry —
// `display_name`, `bg_asset`, `bar_color`, and the 100% milestone prize.
// Until the cycle plumbing is in place we render the screenshot's
// "Iron Skies" + coin-prize sample so the home screen is reviewable in
// the simulator.
// ---------------------------------------------------------------------------
const String _kPlaceholderCycleDisplayName = 'Iron Skies';
// v2: single completion prize at 100%. The 50% mid-cycle prize was removed.
const String _kPlaceholderPrizeAsset = 'assets/ui/icon_coin.png';
const int _kPlaceholderPrizeAmount = 800;
const int _kPlaceholderProgress = 216;
const int _kPlaceholderTarget = 350;

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

  /// Ticks every 30 seconds so the challenge-card countdown stays fresh.
  /// Display granularity is "Xd Yh remaining" so a 30s cadence is plenty
  /// without burning frames.
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Ticker is started once all images resolve (see _onImageLoaded).
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) setState(() {});
      },
    );
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
    _loadImage('assets/enemies/Ice_enemy_3.png', (img) => setState(() {
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
    _countdownTimer?.cancel();
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
                const AppTopBar.full(),
                _buildOffersRow(),
                Expanded(child: _buildCentreContent()),
                _buildChallengeAndLaunch(economy),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Offers row — up to 4 monetization slots, left-aligned. Only offers
  // marked `active: true` in remote config render; the row hides entirely
  // when no offers are active.
  //
  // Add a new entry to [specs] when a new offer popup is wired. The order
  // here determines the left-to-right display order.
  // ---------------------------------------------------------------------------
  Widget _buildOffersRow() {
    final rc = RemoteConfigService.instance;
    final specs = <_OfferSpec>[
      _OfferSpec(
        assetId: '1+2_ironsky',
        iconAsset: 'assets/ui/home/1plus3_lobby_iron_skies.png',
        placeholderLabel: '1+3',
        onTap: () => ThreePlusOneOfferPopup.show(
          context,
          assetId: '1+2_ironsky',
        ),
      ),
      _OfferSpec(
        assetId: 'snake_ironsky',
        iconAsset: 'assets/ui/home/snake_lobby_iron_skies.png',
        placeholderLabel: 'SNAKE',
        onTap: () => SnakeOfferPopup.show(
          context,
          assetId: 'snake_ironsky',
        ),
      ),
    ];
    final active =
        specs.where((s) => rc.isOfferActive(s.assetId)).take(4).toList();
    if (active.isEmpty) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          for (int i = 0; i < active.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _OfferIcon(
              asset: active[i].iconAsset,
              placeholderLabel: active[i].placeholderLabel,
              onTap: active[i].onTap,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Centre content — title block only. Challenge card + CTA live in
  // [_buildChallengeAndLaunch] and dock to the bottom of the column.
  // ---------------------------------------------------------------------------
  Widget _buildCentreContent() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'SKYSTRIKE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w500,
            letterSpacing: 4,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'AERIAL COMBAT',
          style: TextStyle(
            color: Color(0xFFaaaaaa),
            fontSize: 11,
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Challenge card + Launch CTA stack (docked above the bottom nav)
  // ---------------------------------------------------------------------------
  Widget _buildChallengeAndLaunch(EconomyState economy) {
    final view = economy.challengeView;
    // Pre-Stage-3 (or any state where no real challenge exists) the card
    // still renders so the home screen has its hero element. Placeholder
    // numbers are used so the simulator preview matches the design mock.
    final progress = view?.progress ?? _kPlaceholderProgress;
    final target = view?.target ?? _kPlaceholderTarget;
    final fraction = target > 0
        ? (progress / target).clamp(0.0, 1.0).toDouble()
        : 0.0;
    // Live countdown — null when no real cycle exists so the timer row
    // hides instead of showing a misleading static placeholder.
    final remaining = view?.remainingFrom(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChallengeCard(
            displayName: _kPlaceholderCycleDisplayName,
            progress: progress,
            target: target,
            fraction: fraction,
            prizeAsset: _kPlaceholderPrizeAsset,
            prizeAmount: _kPlaceholderPrizeAmount,
            remaining: remaining,
            onTap: () => ChallengePrizesPopup.show(context),
            // Cycle bg + bar colour are dynamic via remote config. Until
            // the cycle plumbing lands, render the styled fallback.
            bgAsset: null,
            barColor: _cGreen,
          ),
          const SizedBox(height: 14),
          _LaunchMissionCta(
            onPressed: () => _onLaunchPressed(economy),
            onLongPress: () => _onLaunchLongPressed(economy),
          ),
        ],
      ),
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

  /// Long-press LAUNCH debug hook: simulates a Stage 3 clear and reveals
  /// the challenge system if it's still locked. Per v2 the gate is player
  /// level 4 (set via Dev Tools); [EconomyState.markChallengeRevealed]
  /// is idempotent so this stays safe after the gate has already fired.
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
    economy.markChallengeRevealed();
    final type = economy.activeChallengeType;
    final label = type?.displayName ?? 'no active cycle';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stage 3 sim → $label. Awarded ${outcome.reward.coins} coins.',
        ),
      ),
    );
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

// ---------------------------------------------------------------------------
// Challenge card — "Iron Skies" hero block with progress bar, 50% / 100%
// milestone markers, and an overlapping prize icon at the 100% end.
//
// Three things are designed to be dynamic (driven by the active cycle's
// remote-config entry). The widget already accepts them as constructor
// params — the call site just needs to swap the placeholder constants
// for real `EconomyState` getters once the cycle plumbing lands:
//   1. Card background — `bgAsset` ⇒ `assets/ui/home/challenge_card_bg.png`.
//   2. Progress-bar fill colour — `barColor`.
//   3. Prize icon — `prizeAsset` (already wired to existing currency /
//      chest assets so no new art is needed).
// ---------------------------------------------------------------------------
class _ChallengeCard extends StatelessWidget {
  final String displayName;
  final int progress;
  final int target;
  final double fraction;
  // v2: single completion prize at 100% — no mid-cycle 50% milestone.
  final String prizeAsset;
  final int prizeAmount;

  /// Time left in the active cycle, or null when no real cycle exists
  /// (pre-FTUE / placeholder mode) — in which case the timer row hides.
  final Duration? remaining;

  /// Tap target for the whole card. Opens the prize-ladder popup.
  final VoidCallback onTap;

  /// When non-null, this PNG replaces the styled `Container` background.
  /// Wire it from the cycle's remote-config entry when ready.
  final String? bgAsset;

  /// Progress-bar fill colour. Defaults to the existing in-game green.
  final Color barColor;

  const _ChallengeCard({
    required this.displayName,
    required this.progress,
    required this.target,
    required this.fraction,
    required this.prizeAsset,
    required this.prizeAmount,
    required this.onTap,
    this.remaining,
    this.bgAsset,
    this.barColor = _cGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _cChallengeBg.withValues(alpha: 0.94),
          border: Border.all(
            color: _cAmber.withValues(alpha: 0.55),
            width: 0.7,
          ),
          borderRadius: BorderRadius.circular(10),
          image: bgAsset == null
              ? null
              : DecorationImage(
                  image: AssetImage(bgAsset!),
                  fit: BoxFit.cover,
                  onError: (_, __) {},
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              _ChallengeBar(
                fraction: fraction,
                progress: progress,
                target: target,
                prizeAsset: prizeAsset,
                prizeAmount: prizeAmount,
                barColor: barColor,
              ),
              if (remaining != null) ...[
                const SizedBox(height: 8),
                _CountdownRow(remaining: remaining!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact "🕐 1d 3h remaining" row. Formats:
///   - `≥1d`  → `Xd Yh remaining`
///   - `<1d`  → `Xh Ym remaining`
///   - `<1h`  → `Xm remaining`
///   - `=0`   → hidden (cycle has elapsed; caller should refresh state)
class _CountdownRow extends StatelessWidget {
  final Duration remaining;
  const _CountdownRow({required this.remaining});

  @override
  Widget build(BuildContext context) {
    if (remaining.inSeconds <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.access_time,
          color: _cGreenPale,
          size: 13,
        ),
        const SizedBox(width: 5),
        Text(
          '${_formatRemaining(remaining)} remaining',
          style: const TextStyle(
            color: _cGreenPale,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static String _formatRemaining(Duration d) {
    if (d.inDays >= 1) {
      final h = d.inHours - d.inDays * 24;
      return '${d.inDays}d ${h}h';
    }
    if (d.inHours >= 1) {
      final m = d.inMinutes - d.inHours * 60;
      return '${d.inHours}h ${m}m';
    }
    final m = d.inMinutes;
    return '${m < 1 ? 1 : m}m';
  }
}

// ---------------------------------------------------------------------------
// Progress bar with a single completion-prize overlay at the 100% end.
//
// Layout rules (per v2 design):
//   - The completion prize sits at the right end of the bar; the icon's
//     left 10% overlaps the bar (the bar is shortened by 90% of the icon
//     width).
//   - Under the prize icon sits an amount badge; the top 10% of the
//     badge overlaps the bottom of the icon.
//
// v2 removed the 50% mid-cycle prize/tick; players see a single reward
// at completion.
// ---------------------------------------------------------------------------
class _ChallengeBar extends StatelessWidget {
  static const double _barHeight = 14;
  static const double _prizeIconSize = 34;
  static const double _amountBadgeHeight = 14;
  // Fraction of the icon's width that overlaps the bar at the 100% end.
  static const double _barOverlapFraction = 0.10;
  // Fraction of the amount badge's height that overlaps the prize icon.
  static const double _badgeOverlapFraction = 0.10;

  final double fraction;
  final int progress;
  final int target;
  final String prizeAsset;
  final int prizeAmount;
  final Color barColor;

  const _ChallengeBar({
    required this.fraction,
    required this.progress,
    required this.target,
    required this.prizeAsset,
    required this.prizeAmount,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    // The bar stops short of the row's right edge by (1 - overlap) × icon
    // size so the icon's right edge lands at the row's right edge while
    // its left 10% overlaps the bar.
    const barRightInset = _prizeIconSize * (1 - _barOverlapFraction);
    // Total height = icon stack + (1 - overlap) × badge height. Lets the
    // amount badge sit fully under the icon with exactly 10% overlap and
    // without bleeding past this widget's bounds.
    const totalHeight =
        _prizeIconSize + _amountBadgeHeight * (1 - _badgeOverlapFraction);
    const barTop = (_prizeIconSize - _barHeight) / 2;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bar
          Positioned(
            left: 0,
            right: barRightInset,
            top: barTop,
            height: _barHeight,
            child: _BarTrack(
              fraction: fraction,
              barColor: barColor,
              progressText: '$progress/$target',
            ),
          ),
          // Completion prize — right end, 10% overlap with bar.
          Positioned(
            right: 0,
            top: 0,
            width: _prizeIconSize,
            child: _PrizeOverlay(
              asset: prizeAsset,
              amount: prizeAmount,
              iconSize: _prizeIconSize,
              badgeHeight: _amountBadgeHeight,
              badgeOverlapFraction: _badgeOverlapFraction,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarTrack extends StatelessWidget {
  final double fraction;
  final Color barColor;
  final String progressText;

  const _BarTrack({
    required this.fraction,
    required this.barColor,
    required this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        children: [
          Container(color: _cChallengeBarTrack),
          LayoutBuilder(builder: (ctx, constraints) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: constraints.maxWidth * fraction,
              decoration: BoxDecoration(color: barColor),
            );
          }),
          // Progress label — centred along the bar (v2 removed the 50%
          // tick and the left/right label shift that depended on it).
          Align(
            alignment: const Alignment(0, 0),
            child: Text(
              progressText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: Color(0xCC000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrizeOverlay extends StatelessWidget {
  final String asset;
  final int amount;
  final double iconSize;
  final double badgeHeight;
  final double badgeOverlapFraction;

  const _PrizeOverlay({
    required this.asset,
    required this.amount,
    required this.iconSize,
    required this.badgeHeight,
    required this.badgeOverlapFraction,
  });

  @override
  Widget build(BuildContext context) {
    final totalH = iconSize + badgeHeight * (1 - badgeOverlapFraction);
    // Badge's top edge — sits at (iconSize - 10% of badge height) so its
    // top 10% overlaps the bottom of the prize icon.
    final badgeTop = iconSize - badgeHeight * badgeOverlapFraction;

    return SizedBox(
      width: iconSize,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Prize icon — anchored to the top of the overlay box.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: iconSize,
            child: Image.asset(
              asset,
              errorBuilder: AssetPlaceholder.image(
                color: _cAmber,
                label: 'prize',
                borderRadius: 4,
              ),
            ),
          ),
          // Amount badge — centred horizontally below the icon.
          Positioned(
            top: badgeTop,
            left: 0,
            right: 0,
            height: badgeHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: badgeHeight,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1606),
                  border: Border.all(color: _cAmber, width: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$amount',
                  style: const TextStyle(
                    color: _cGreenPale,
                    fontSize: 10,
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
}

// ---------------------------------------------------------------------------
// One monetization slot in the home offers row. The row supports up to 4
// of these and filters them by `RemoteConfigService.isOfferActive`.
// ---------------------------------------------------------------------------
class _OfferSpec {
  final String assetId;
  final String iconAsset;
  final String placeholderLabel;
  final VoidCallback onTap;

  const _OfferSpec({
    required this.assetId,
    required this.iconAsset,
    required this.placeholderLabel,
    required this.onTap,
  });
}

// ---------------------------------------------------------------------------
// Offer icon — small docked badge at the top of the home screen, rendered
// from cycle-specific art. Falls back to the AssetPlaceholder badge if
// the file is missing so missing assets are visible in dev builds.
// ---------------------------------------------------------------------------
class _OfferIcon extends StatelessWidget {
  final String asset;
  final String placeholderLabel;
  final VoidCallback onTap;

  const _OfferIcon({
    required this.asset,
    required this.placeholderLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Image.asset(
          asset,
          errorBuilder: AssetPlaceholder.image(
            color: _cAmber,
            label: placeholderLabel,
            borderRadius: 10,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Launch Mission CTA. Coded as a styled button for the simulator preview;
// when the dynamic CTA artwork lands, swap the inner Container for an
// `Image.asset('assets/ui/home/cta_launch_mission.png')` and the gesture
// detector keeps working unchanged.
// ---------------------------------------------------------------------------
class _LaunchMissionCta extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  const _LaunchMissionCta({
    required this.onPressed,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6FAD1F), _cGreen],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _cGreenLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: _cGreen.withValues(alpha: 0.55),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
            SizedBox(width: 6),
            Text(
              'Launch Mission',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

