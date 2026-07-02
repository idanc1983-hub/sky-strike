import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../config/enemy_glow_config.dart';
import '../config/remote_config_service.dart';
import '../economy/services/challenge_formulas.dart';
import '../economy/services/challenge_prize_parser.dart';
import '../economy/state/challenge_state.dart';
import '../economy/state/economy_state.dart';
import '../economy/state/pending_celebration.dart';
import '../economy/ui/challenge_prizes_popup.dart';
import '../economy/ui/coming_soon_popup.dart';
import '../economy/ui/generic_offer_popup.dart';
import '../economy/ui/pre_mission_popup.dart';
import '../economy/ui/snake_offer_popup.dart';
import '../economy/ui/three_plus_one_offer_popup.dart';
import '../game/models.dart';
import '../render/enemy_glow_painter.dart';
import '../shared/widgets/app_top_bar.dart';
import '../shared/widgets/asset_placeholder.dart';
import '../shared/widgets/currency_anchors.dart';
import '../widgets/chest_open_overlay.dart';

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
// The real cycle name, background, and bar colour come from the active
// cycle's remote-config entry — wired here for the no-cycle preview path.
// Progress + target come from `EconomyState.challengeView`; the 100%
// prize amount is computed by the formula below so it scales with the
// player's level.
// ---------------------------------------------------------------------------
const String _kPlaceholderCycleDisplayName = 'Iron Skies';
const String _kPlaceholderPrizeAsset = 'assets/ui/icon_coin.png';

// Lobby icon catalog — keyed by Remote Config `monetization.configs[i].asset_name`.
// All 13 shipped lobby icons are registered here so RC can flip any of them
// on without a code change. _buildOffersRow() reads from this map when
// composing the visible offers row.
const Map<String, String> _kLobbyIconAssets = {
  'fto':
      'assets/ui/home/monetization/fto_lobby.png',
  '1+2_ironsky':
      'assets/ui/home/monetization/1+2_ironsky_lobby.png',
  'generic_ironsky':
      'assets/ui/home/monetization/generic_ironsky_lobby.png',
  'snake_ironsky':
      'assets/ui/home/monetization/snake_ironsky_lobby.png',
  '1+2_goldensky':
      'assets/ui/home/monetization/1+2_goldensky_lobby.png',
  'generic_goldensky':
      'assets/ui/home/monetization/generic_goldensky_lobby.png',
  'snake_goldensky':
      'assets/ui/home/monetization/snake_goldensky_lobby.png',
  '1+2_laststand':
      'assets/ui/home/monetization/1+2_laststand_lobby.png',
  'generic_laststand':
      'assets/ui/home/monetization/generic_laststand_lobby.png',
  'snake_laststand':
      'assets/ui/home/monetization/snake_laststand_lobby.png',
  '1+2_starascent':
      'assets/ui/home/monetization/1+2_starascent_lobby.png',
  'generic_starascent':
      'assets/ui/home/monetization/generic_starascent_lobby.png',
  'snake_starascent':
      'assets/ui/home/monetization/snake_starascent_lobby.png',
};

/// Deterministic preview of the 100% milestone reward in coins. Delegates to
/// the single source of truth in [ChallengeFormulas] — the exact coin amount
/// the player is awarded on claim — so the card, the claim, and the reveal
/// animation can never disagree.
int _previewMilestoneCoins(int playerLevel) =>
    ChallengeFormulas.milestone100Coins(playerLevel: playerLevel);

// ---------------------------------------------------------------------------
// Enemy state
// ---------------------------------------------------------------------------
class _EnemyState {
  double x;
  double y;
  double speed;
  double driftPhase;
  EnemyTier tier;
  final double phaseOffset;
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
    required this.phaseOffset,
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
  /// True when Home is the selected tab in [MainShell]. Gates the in-place
  /// challenge-prize celebration so it only plays while the card is visible.
  final bool active;
  const HomeScreen({super.key, this.active = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
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

  // --- Challenge-prize celebration (in place on the challenge card) ---
  /// Drives the bar fill from the prize's start fraction up to 100%.
  late final AnimationController _challengeFill;
  /// The prize currently being celebrated (null when idle).
  PendingCelebration? _celebChallenge;
  /// Phase guard so we don't restart mid-animation.
  bool _celebrating = false;
  /// Marks the bar-end prize icon on the challenge card (used for layout;
  /// the reward itself collects through the shared [RewardFlyOverlay]).
  final GlobalKey _prizeKey = GlobalKey();

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
    _challengeFill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onBarFilled();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final eco = context.read<EconomyState>();
    if (!identical(eco, _economy)) {
      _economy?.removeListener(_onEconomyChanged);
      _economy = eco..addListener(_onEconomyChanged);
    }
    _loadBiomeAssets();
    _loadExplosionSheet();
    // Catch a challenge prize queued before Home was shown.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeStartChallengeCelebration());
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybeStartChallengeCelebration());
    }
  }

  void _onEconomyChanged() => _maybeStartChallengeCelebration();

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
    final glowPeriodSec =
        RemoteConfigService.I.enemyGlow.pulsePeriodMs / 1000.0;
    for (int i = 0; i < 7; i++) {
      final tier = tiers[_rng.nextInt(tiers.length)];
      final cfg = kEnemyConfigs[tier]!;
      _enemies.add(_EnemyState(
        x: (screenWidth / 7) * i + _rng.nextDouble() * 30,
        y: -(_rng.nextDouble() * 100 + 20),
        speed: cfg.baseSpeed * (0.8 + _rng.nextDouble() * 0.4),
        driftPhase: _rng.nextDouble() * pi * 2,
        tier: tier,
        phaseOffset: _rng.nextDouble() * glowPeriodSec,
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
    _economy?.removeListener(_onEconomyChanged);
    _challengeFill.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Challenge-prize celebration: fill the card bar from where the player was
  // up to 100%, then fly the prize from the bar into the top-right holder.
  // ---------------------------------------------------------------------------

  /// Starts the next queued challenge celebration if the card is visible and
  /// nothing is already playing. Called post-frame from [build].
  void _maybeStartChallengeCelebration() {
    if (_celebrating || !mounted || !widget.active) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    final economy = _economy;
    if (economy == null || !economy.hasPendingChallengeCelebration) return;
    final next = economy.takeChallengeCelebration();
    if (next == null) return;
    setState(() {
      _celebrating = true;
      _celebChallenge = next;
    });
    _challengeFill.forward(from: 0);
  }

  void _onBarFilled() {
    final celeb = _celebChallenge;
    // Hold at 100% briefly, then collect the prize.
    Future.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      if (celeb != null && celeb.isChest) {
        // A chest prize opens with the full chest sequence.
        await ChestOpenOverlay.show(
          context,
          coins: celeb.coins,
          gems: celeb.gems,
        );
      } else if (celeb != null) {
        // Currency prize: hand off to the shared "Tap to collect" fly so
        // every reward collects the same way (the bar fill above is the
        // challenge-specific lead-in). Both overlays release the withheld
        // holder value on land, so nothing is double-counted here.
        CurrencyAnchors.requestRefresh();
        await RewardFlyOverlay.show(
          context,
          coins: celeb.coins,
          gems: celeb.gems,
        );
      }
      _finishCelebration();
    });
  }

  void _finishCelebration() {
    if (!mounted) return;
    setState(() {
      _celebrating = false;
      _celebChallenge = null;
    });
    // Another prize queued? Play it next frame.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeStartChallengeCelebration());
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
                frame: _frame,
                worldIndex: economy.currentWorld,
                glowConfig: RemoteConfigService.I.enemyGlow,
              ),
            ),
          ),

          // Layer 2: UI
          SafeArea(
            child: Column(
              children: [
                const AppTopBar.full(forceShowCoin: true),
                _buildOffersRow(economy),
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
  // Offers row — up to 4 monetization slots, left-aligned. Reads
  // `RemoteConfigService.monetization.configs` and shows any entry whose
  // `active == true`, `unlock_level <= player.level`, and whose
  // `trigger_challenge_id` matches the player's current state:
  //   - `new_players`              → always while active (intro)
  //   - `none` / empty             → always while active
  //   - `<cycle_id>` (e.g. `iron_skies`) → only while that cycle is active
  // Iteration order follows [_kLobbyIconAssets] so the visual slot
  // order is deterministic. Entries without a registered icon (e.g.
  // `first_purchase`) are skipped — they surface via other flows.
  //
  // Tap currently opens [ComingSoonPopup]; swap to the matching offer
  // popup once they're wired (`1+2_*` → ThreePlusOneOfferPopup,
  // `snake_*` → SnakeOfferPopup, `generic_*` → GenericOfferPopup,
  // `fto` → ThreePlusOneOfferPopup).
  // ---------------------------------------------------------------------------
  Widget _buildOffersRow(EconomyState economy) {
    final specs = _resolveActiveOffers(economy);
    final active = specs.take(4).toList();
    if (active.isEmpty) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < 4; i++)
            if (i < active.length)
              _OfferIcon(
                asset: active[i].iconAsset,
                placeholderLabel: active[i].placeholderLabel,
                onTap: active[i].onTap,
              )
            else
              const SizedBox(width: 72, height: 72),
        ],
      ),
    );
  }

  List<_OfferSpec> _resolveActiveOffers(EconomyState economy) {
    final rc = RemoteConfigService.I;
    final activeCycleId = economy.activeChallengeType?.jsonValue;
    final level = economy.level;
    final out = <_OfferSpec>[];
    _kLobbyIconAssets.forEach((assetId, iconAsset) {
      final cfg = rc.monetization.configByAssetName(assetId);
      if (cfg == null) return;
      if (!cfg.active) return;
      if (level < cfg.unlockLevel) return;
      final trigger = cfg.triggerChallengeId ?? '';
      final triggerMatches = trigger.isEmpty ||
          trigger == 'none' ||
          trigger == 'new_players' ||
          trigger == activeCycleId;
      if (!triggerMatches) return;
      final displayName = cfg.displayName.isEmpty ? assetId : cfg.displayName;
      out.add(_OfferSpec(
        assetId: assetId,
        iconAsset: iconAsset,
        placeholderLabel: assetId,
        onTap: () => _openOfferPopup(assetId, displayName),
      ));
    });
    return out;
  }

  /// Routes a lobby-icon tap to the matching offer template by asset_id
  /// prefix. Anything that doesn't fit the three known templates falls
  /// back to [ComingSoonPopup] so we don't crash on a future RC entry.
  void _openOfferPopup(String assetId, String displayName) {
    if (assetId == 'fto' || assetId.startsWith('1+2_')) {
      ThreePlusOneOfferPopup.show(context, assetId: assetId);
      return;
    }
    if (assetId.startsWith('snake_')) {
      SnakeOfferPopup.show(context, assetId: assetId);
      return;
    }
    if (assetId.startsWith('generic_')) {
      GenericOfferPopup.show(context, assetId: assetId);
      return;
    }
    ComingSoonPopup.show(context, offerName: displayName);
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
    // When no real cycle exists yet, the challenge feature is still
    // locked (player hasn't crossed the unlock gate). The locked
    // variant reuses the same bar with placeholder progress so the
    // card frame is visually identical — only the title/timer/reward
    // swap and the bar's centre text reads "Unlock at stage N".
    final locked = view == null;
    final progress = view?.progress ?? 0;
    final target = view?.target ?? 0;
    final liveFraction = target > 0
        ? (progress / target).clamp(0.0, 1.0).toDouble()
        : 0.0;
    // During a prize celebration, drive the bar from where the player was
    // up to 100% instead of showing the (already reset) live fraction.
    final celeb = _celebChallenge;
    final celebrating = _celebrating && celeb != null;
    final fraction = celebrating
        ? celeb.fromFraction +
            (1.0 - celeb.fromFraction) *
                Curves.easeOut.transform(_challengeFill.value)
        : liveFraction;
    final remaining = view?.remainingFrom(DateTime.now());
    // Pull the *current* stage's prize from the active cycle's RC
    // ladder so the bar-end reward stays in sync as the player advances
    // — using stage 1 forever made every cycle look like 70coin even
    // when the player was about to clear a chest stage.
    final stages = economy.activeChallengeStages;
    final stageIdx =
        view == null ? 0 : view.stageIndex.clamp(0, stages.length - 1).toInt();
    final activePrize = stages.isNotEmpty
        ? parseChallengePrize((stages[stageIdx]['prize'] ?? '').toString())
        : ChallengePrize.unknown;
    final unitLabel = view?.metricLabel ?? 'pts';
    // Title comes from RC's `display_name` so card + popup match. Falls
    // back to the enum label, then the locked placeholder.
    final type = view?.type;
    final rcDisplayName = type == null
        ? ''
        : (RemoteConfigService.I.challengeById(type.jsonValue)?.displayName ?? '');
    final displayName = type == null
        ? _kPlaceholderCycleDisplayName
        : (rcDisplayName.isEmpty ? type.displayName : rcDisplayName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChallengeCard(
            displayName: displayName,
            progress: progress,
            target: target,
            fraction: fraction,
            unitLabel: unitLabel,
            prizeAsset: locked || activePrize.amount == 0
                ? _kPlaceholderPrizeAsset
                : activePrize.asset,
            prizeAmount: locked
                ? _previewMilestoneCoins(economy.level)
                : activePrize.amount,
            remaining: remaining,
            locked: locked,
            unlockLabel:
                'Unlock after stage ${EconomyState.challengeUnlockLevel - 1}',
            onTap: () => ChallengePrizesPopup.show(context),
            directFill: celebrating,
            prizeKey: _prizeKey,
            // Cycle bg + bar colour are dynamic via remote config. Until
            // the cycle plumbing lands, render the styled fallback.
            bgAsset: null,
            barColor: _cGreen,
          ),
          const SizedBox(height: 48),
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
  /// the challenge system if it's still locked. The real gate is the
  /// `priorGlobalLevel < challengeUnlockLevel` check in
  /// [EconomyState.setCurrentStage] (crossing stage 3 → 4); this debug
  /// path forces the reveal directly via [markChallengeRevealed], which
  /// is idempotent so re-tapping is safe after the gate has already fired.
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
  final int frame;
  final int worldIndex;
  final EnemyGlowConfig glowConfig;

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
    required this.frame,
    required this.worldIndex,
    required this.glowConfig,
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
        if (!e.flashing) {
          paintEnemyGlow(
            canvas,
            enemyImage!,
            dst,
            glowConfig,
            worldIndex,
            frame / 60.0,
            phaseOffset: e.phaseOffset,
          );
        }
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
  /// Metric-specific unit suffix (e.g. 'kills', 'survives', 'score',
  /// 'stars'). Pulled from the active cycle's RC `metric` so each cycle
  /// reads in its own units instead of a generic "pts".
  final String unitLabel;
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

  /// Pre-unlock variant: hide title + timer + prize, replace the prize
  /// icon with a lock, and show [unlockLabel] inside the bar.
  final bool locked;
  final String unlockLabel;

  /// When true the bar fills directly to [fraction] (driven frame-by-frame
  /// during a prize celebration) instead of the default 0→fraction tween.
  final bool directFill;

  /// Attached to the bar-end prize icon so a won prize can fly from it.
  final Key? prizeKey;

  const _ChallengeCard({
    required this.displayName,
    required this.progress,
    required this.target,
    required this.fraction,
    required this.unitLabel,
    required this.prizeAsset,
    required this.prizeAmount,
    required this.onTap,
    this.remaining,
    this.bgAsset,
    this.barColor = _cGreen,
    this.locked = false,
    this.unlockLabel = '',
    this.directFill = false,
    this.prizeKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Locked variant is non-interactive — the player has nothing to
      // see yet; tapping the card is a no-op until the unlock gate.
      onTap: locked ? null : onTap,
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
              // Title row — hidden but space-preserving when locked so
              // the card keeps the same overall height as the unlocked
              // variant (and therefore the same tap-target footprint).
              Visibility(
                visible: !locked,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              _ChallengeBar(
                fraction: fraction,
                progress: progress,
                target: target,
                unitLabel: unitLabel,
                prizeAsset: prizeAsset,
                prizeAmount: prizeAmount,
                barColor: barColor,
                locked: locked,
                lockedLabel: unlockLabel,
                directFill: directFill,
                prizeKey: prizeKey,
              ),
              const SizedBox(height: 8),
              // Countdown row — same space-preserving treatment as the
              // title so the locked card matches the unlocked layout.
              Visibility(
                visible: !locked && remaining != null,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _CountdownRow(
                  // Any non-zero duration keeps `_CountdownRow` from
                  // collapsing to SizedBox.shrink, so `maintainSize`
                  // can actually preserve its height when hidden.
                  remaining: remaining ?? const Duration(hours: 1),
                ),
              ),
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
// Progress bar with a single completion-prize icon at the 100% end.
//
// Layout rules (per May 2026 redesign mock):
//   - The completion prize sits at the right end of the bar; the icon's
//     left 10% overlaps the bar (the bar is shortened by 90% of the icon
//     width).
//   - No amount badge under the icon (removed per mock).
// ---------------------------------------------------------------------------
class _ChallengeBar extends StatelessWidget {
  static const double _barHeight = 28;
  static const double _prizeIconSize = 36;
  static const double _amountBadgeHeight = 18;
  // Wide-enough envelope to fit 3–4-digit prize numbers centred on the
  // icon centre without horizontal overflow.
  static const double _badgeBoxWidth = 56;
  // Fraction of the icon's width that overlaps the bar at the 100% end.
  static const double _barOverlapFraction = 0.10;
  // Fraction of the amount badge's height that overlaps the prize icon.
  static const double _badgeOverlapFraction = 0.10;

  final double fraction;
  final int progress;
  final int target;
  final String unitLabel;
  final String prizeAsset;
  final int prizeAmount;
  final Color barColor;
  final bool locked;
  final String lockedLabel;
  final bool directFill;
  final Key? prizeKey;

  const _ChallengeBar({
    required this.fraction,
    required this.progress,
    required this.target,
    required this.unitLabel,
    required this.prizeAsset,
    required this.prizeAmount,
    required this.barColor,
    this.locked = false,
    this.lockedLabel = '',
    this.directFill = false,
    this.prizeKey,
  });

  @override
  Widget build(BuildContext context) {
    const barRightInset = _prizeIconSize * (1 - _barOverlapFraction);
    const barTop = (_prizeIconSize - _barHeight) / 2;
    const badgeTop = _prizeIconSize - _amountBadgeHeight * _badgeOverlapFraction;
    const totalHeight = _prizeIconSize +
        _amountBadgeHeight * (1 - _badgeOverlapFraction);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: barRightInset,
            top: barTop,
            height: _barHeight,
            child: _BarTrack(
              fraction: fraction,
              barColor: barColor,
              directFill: directFill,
              // Locked: same green fill as the unlocked state — only
              // the centre label swaps to "Unlock at stage N". The
              // shown progress clamps at the goal so a stale save
              // (e.g. legacy cumulative counter) doesn't render
              // "119/5 kills" — the active card in the popup uses
              // the same clamp.
              progressText: locked
                  ? lockedLabel
                  : (directFill
                      ? '${(fraction * 100).round()}%'
                      : '${progress > target ? target : progress}/$target $unitLabel'),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: _prizeIconSize,
            height: _prizeIconSize,
            child: locked
                ? Transform.scale(
                    scale: 1.5,
                    child: Image.asset(
                      'assets/ui/challenges/challenge_lock.png',
                      errorBuilder: AssetPlaceholder.image(
                        color: _cAmber,
                        label: 'lock',
                        borderRadius: 4,
                      ),
                    ),
                  )
                : Image.asset(
                    prizeAsset,
                    key: prizeKey,
                    errorBuilder: AssetPlaceholder.image(
                      color: _cAmber,
                      label: 'prize',
                      borderRadius: 4,
                    ),
                  ),
          ),
          // Amount badge centred horizontally on the prize icon's centre.
          // The Positioned area is wider than the icon so a badge with a
          // 3-digit number still fits centred (Align would otherwise let
          // the container overflow asymmetrically).
          //
          // Icon centre is at `right: _prizeIconSize / 2` from the Stack's
          // right edge → 16px. To centre a `_badgeBoxWidth`-wide area on
          // that point, the box's `right` value is
          //   centre − boxWidth/2 = 16 − boxWidth/2.
          if (!locked)
            Positioned(
              right: 16 - _badgeBoxWidth / 2,
              top: badgeTop,
              width: _badgeBoxWidth,
              height: _amountBadgeHeight,
              child: Center(
                child: Container(
                  height: _amountBadgeHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1606),
                    border: Border.all(color: _cAmber, width: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$prizeAmount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _cGreenPale,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
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

class _BarTrack extends StatelessWidget {
  final double fraction;
  final Color barColor;
  final String progressText;
  final bool directFill;

  const _BarTrack({
    required this.fraction,
    required this.barColor,
    required this.progressText,
    this.directFill = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        children: [
          // Track. `Positioned.fill` is required — a bare `Container` in
          // a Stack collapses to 0x0, so the empty (fraction == 0) bar
          // would otherwise render invisible against the card bg.
          Positioned.fill(
            child: Container(color: _cChallengeBarTrack),
          ),
          LayoutBuilder(builder: (ctx, constraints) {
            // During a prize celebration the parent drives [fraction]
            // frame-by-frame, so render it directly (the 0→fraction tween
            // would otherwise fight the per-frame updates).
            if (directFill) {
              return Container(
                width: constraints.maxWidth * fraction,
                decoration: BoxDecoration(color: barColor),
              );
            }
            // TweenAnimationBuilder animates from 0 → fraction on the
            // first build (visible fill on lobby entry) and from the
            // previous end → new end whenever the player earns more
            // progress while on screen.
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Container(
                width: constraints.maxWidth * value,
                decoration: BoxDecoration(color: barColor),
              ),
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
                fontSize: 15,
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

// ---------------------------------------------------------------------------
// One monetization slot in the home offers row. The row supports up to 4
// of these and filters them by `OfferConfig.active` + unlock/trigger gates.
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
        width: 72,
        height: 72,
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
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6FAD1F), _cGreen],
          ),
          borderRadius: BorderRadius.circular(14),
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

