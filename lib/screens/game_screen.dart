import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../economy/constants/ace_dialogue_catalog.dart';
import '../economy/constants/ad_placement_catalog.dart';
import '../economy/constants/economy_constants.dart';
import '../economy/services/ads_service.dart';
import '../economy/services/ftue_triggers.dart';
import '../economy/state/economy_state.dart';
import '../economy/ui/ace_dialogue_overlay.dart';
import '../game/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerBullet {
  double x, y;
  final double dx; // 0 for straight shots; non-zero for split-shot spread
  _PlayerBullet({required this.x, required this.y, this.dx = 0});
}

class _EnemyBullet {
  double x, y;
  final double dx, dy;
  _EnemyBullet({required this.x, required this.y, this.dx = 0, required this.dy});
}

class _GameEnemy {
  double x, y;
  double speed;
  double driftPhase;
  final EnemyTier tier;
  int hp;
  final int maxHp;
  final double renderSize;
  final double hitRadius;
  final bool isElite;

  bool flashing = false;
  int flashFrames = 0;
  bool exploding = false;
  int explosionFrame = 0;

  // Pool / entry stagger
  bool active = false;      // false = waiting for entryDelay
  int entryDelay = 0;       // frames before this enemy becomes visible
  int spawnFrame = 0;       // frame when created or last respawned
  bool pendingRespawn = false;
  int respawnAt = 0;

  int fireTimer = 0;

  _GameEnemy({
    required this.x,
    required this.y,
    required this.speed,
    required this.driftPhase,
    required this.tier,
    required this.maxHp,
    required this.renderSize,
    required this.hitRadius,
    required this.isElite,
  }) : hp = maxHp;
}

class _Pickup {
  double x, y;
  final PowerUpType type;
  bool flashing = false;
  int flashFrames = 0;
  _Pickup({required this.x, required this.y, required this.type});
}

class _FloatText {
  double x, y;
  final String text;
  final Color color;
  final bool bold;
  final int life;
  // v1.4 — per-float visual params. Old combo floats keep the defaults
  // (12 px, no glow, immediate fade). The wave-clear callout passes larger
  // values so it reads as a banner rather than a damage number.
  final double fontSize;
  final double riseSpeed;     // logical px per frame
  final double glowBlur;      // 0 = no glow
  final double holdFraction;  // alpha stays at 1.0 until frame/life > this
  int frame = 0;
  _FloatText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.bold = false,
    this.life = 48,
    this.fontSize = 12,
    this.riseSpeed = 0.7,
    this.glowBlur = 0,
    this.holdFraction = 0.0,
  });
}

enum _Phase { wave, boss, stageClear, gameOver, paused }

// ─────────────────────────────────────────────────────────────────────────────
// GameScreen
// ─────────────────────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {

  // ── Route args ───────────────────────────────────────────────────────────
  int _world = 1;
  int _stage = 1;
  bool _argsLoaded = false;

  // ── Config ───────────────────────────────────────────────────────────────
  late DifficultyParams _diff;
  late List<EnemyTier> _activeTiers;

  // ── Asset loading ─────────────────────────────────────────────────────────
  bool _assetsReady = false;

  // ── Phase ────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.wave;
  _Phase _prevPhase = _Phase.wave;

  // ── Wave state ───────────────────────────────────────────────────────────
  int _currentWave = 1;
  static const int _maxWave = 10;
  int _waveTarget = 0;      // kill quota for this wave (= pool size)
  int _waveKilled = 0;
  int _waveChipPulseFrames = 0;

  // v1.4 — no-stop wave clear: green edge-sweep border + reward float.
  // The game keeps running through the wave transition; no phase change,
  // no overlay, no freeze. Sweep timing: 80 ms fade-in, 200 ms hold,
  // 600 ms fade-out (880 ms total). Reward float spawns at +200 ms;
  // _advanceWave fires at +400 ms.
  bool _showEdgeSweep = false;
  double _edgeSweepOpacity = 0.0;
  // Re-entry guard: _checkWaveComplete fires every tick the wave is
  // "done", but the phase no longer changes — without this flag the
  // 400 ms _advanceWave delay would queue dozens of duplicate callbacks
  // and the wave counter would explode.
  bool _waveClearPending = false;

  // ── Player ───────────────────────────────────────────────────────────────
  double _playerX = 0, _playerY = 0;
  bool _playerInitialized = false;
  bool _playerInvincible = false;
  int _invincibleFrames = 0;
  static const int _kInvincibleDuration = 90;
  bool _playerVisible = true;
  double _patrolDir = 1.0;
  bool _hasTouched = false;

  // Player hitbox radius (visual is 72×72, hitbox is 40×40 → radius 20)
  static const double _kPlayerHitRadius = 20.0;
  // Magnet attraction radius: 1.5 cm at 160 dp/inch baseline (1 cm ≈ 63 dp)
  static const double _kMagnetRadius = 95.0;

  // ── HP ───────────────────────────────────────────────────────────────────
  int _hp = 100;
  static const int _maxHp = 100;
  final int _fireRateBase = 18;

  // ── Score ────────────────────────────────────────────────────────────────
  int _totalScore = 0;
  int _bestCombo = 0;

  // ── Accuracy ─────────────────────────────────────────────────────────────
  int _bulletsFired = 0;
  int _bulletsHit = 0;
  final List<int> _waveAccuracies = [];
  int get _accuracy =>
      _bulletsFired > 0 ? (_bulletsHit * 100 ~/ _bulletsFired) : 0;

  // ── Combo ────────────────────────────────────────────────────────────────
  final List<int> _killFrames = [];
  static const int _kComboWindow = 120;

  // ── Economy (mock) ───────────────────────────────────────────────────────
  int _playerGems = 80;
  int _failStreak = 0;
  bool _boostUsed = false;
  bool _isBoostWave = false; // evaluated once per attempt at game start

  // ── INSTANT power-ups active ─────────────────────────────────────────────
  bool _rapidFireActive = false;
  int _rapidFireFrames = 0;

  bool _shieldActive = false;
  int _shieldHitsRemaining = 0;

  bool _splitShotActive = false;
  int _splitShotFrames = 0;

  bool _speedBoostActive = false;
  int _speedBoostFrames = 0;

  bool _droneActive = false;
  int _droneFrames = 0;
  int _droneFireTimer = 0;
  static const double _kDroneOffsetX = 52.0;

  // ── COLLECTIBLE power-ups active (gameplay effects) ───────────────────────
  bool _laserActive = false;
  int _laserFrames = 0;
  int _laserTickTimer = 0;
  static const int _kLaserTickInterval = 8;   // damage pulse every 8 frames
  static const double _kLaserHitHalfWidth = 14.0;

  bool _magnetActive = false;
  int _magnetFrames = 0;

  bool _ghostActive = false;
  int _ghostFrames = 0;

  bool _freezeActive = false;
  int _freezeFrames = 0;

  // ── Tray ─────────────────────────────────────────────────────────────────
  final _trayKey = GlobalKey<_PowerUpTrayState>();

  // ── Pickups / floats ──────────────────────────────────────────────────────
  final List<_Pickup> _pickups = [];
  final List<_FloatText> _floatTexts = [];

  // ── Entities ─────────────────────────────────────────────────────────────
  final List<_PlayerBullet> _playerBullets = [];
  int _bulletTimer = 0;
  final List<_EnemyBullet> _enemyBullets = [];
  final List<_GameEnemy> _enemies = [];

  static const int _kRespawnDelay = 75;

  // ── Boss ─────────────────────────────────────────────────────────────────
  double _bossX = 0, _bossY = 0;
  int _bossHp = 0, _bossMaxHp = 0;
  bool _bossFlashing = false;
  int _bossFlashFrames = 0;
  bool _bossExploding = false;
  int _bossExplosionFrame = 0;
  int _bossFireTimer = 0;

  // Boss entry fly-in
  bool _bossEntering = false;
  int _bossEntryFrame = 0;
  int _bossRedFlashFrames = 0;
  static const int _kBossEntryDuration = 72; // 1.2 s at 60 fps
  static const double _kBossEntryStartY = -150.0;
  static const double _kBossTargetYFrac = 0.15;

  // ── Game over / revive ───────────────────────────────────────────────────
  bool _reviveUsed = false;
  int _waveAtDeath = 1;
  double _bossHpAtDeath = 1.0;
  int _reviveCountdown = 8;
  int _reviveFrameAcc = 0;
  bool _reviveExpired = false;

  // ── Rewarded-ad CTAs (mission failed + stage clear) ──────────────────────
  bool _adInFlight = false;
  bool _rewardDoubled = false;

  // ── Visual FX ────────────────────────────────────────────────────────────
  double _vignetteOpacity = 0;
  int _vignetteFrames = 0;
  static const int _kVignetteDuration = 24;
  int _screenShakeFrames = 0;

  // ── Images ───────────────────────────────────────────────────────────────
  ui.Image? _bgImage;
  ui.Image? _jetImage;
  ui.Image? _explosionSheet;
  ui.Image? _bulletImage;
  ui.Image? _enemyBulletImage;
  final Map<PowerUpType, ui.Image?> _puDropImages = {};
  final Map<PowerUpType, ui.Image?> _puSlotImages = {};
  final Map<EnemyTier, ui.Image?> _enemyImages = {};

  // ── Frame / screen ───────────────────────────────────────────────────────
  Ticker? _ticker;
  int _frame = 0;
  double _bgOffset = 0;
  double _screenW = 0, _screenH = 0;
  final _rng = Random();

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // _loadFailStreak is called inside _loadAllAssets once world/stage are known
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      // The route is pushed with a `Map<String, dynamic>` (sometimes
      // `Map<String, int>` depending on call site). Use a tolerant
      // read so the cast can't crash mid-navigation.
      final raw = ModalRoute.of(context)?.settings.arguments;
      int? w;
      int? s;
      if (raw is Map) {
        if (raw['world'] is int) w = raw['world'] as int;
        if (raw['stage'] is int) s = raw['stage'] as int;
      }
      _world = w ?? 1;
      _stage = s ?? 1;
      _diff = getDifficulty(_stage);
      _activeTiers = activeEnemyTiers(_stage);
      _argsLoaded = true;
      _loadAllAssets();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Asset loading — all assets resolved before ticker starts
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadAllAssets() async {
    await _loadFailStreak();
    await _loadSettings();
    _isBoostWave = _failStreak >= 5 && !_boostUsed;
    if (_isBoostWave) _boostUsed = true;

    final biome = biomeName(_world);
    _bgImage        = await _loadUiImage('assets/backgrounds/bg_$biome.png');
    _jetImage       = await _loadUiImage('assets/jets/jet_player.png');
    _explosionSheet = await _loadUiImage('assets/ui/explosion_sheet.png');
    _bulletImage      = await _loadUiImage(bulletAsset(_world));
    _enemyBulletImage = await _loadUiImage(enemyBulletAsset(_world));

    for (final type in PowerUpType.values) {
      final asset = type.dropAsset;
      if (asset != null) _puDropImages[type] = await _loadUiImage(asset);
    }
    for (final type in kCollectibleSlots) {
      final asset = type.slotAsset;
      if (asset != null) _puSlotImages[type] = await _loadUiImage(asset);
    }

    final baseEnemyImg = await _loadUiImage('assets/enemies/enemy_${biomeName(_world)}.png');
    for (final tier in [..._activeTiers, EnemyTier.boss]) {
      _enemyImages[tier] =
          await _loadUiImage(enemyAsset(_world, tier)) ?? baseEnemyImg;
    }

    if (!mounted) return;
    setState(() => _assetsReady = true);
    // Guard against the rare case where dispose ran between the last
    // mounted-check and now — createTicker after dispose throws.
    if (!mounted) return;
    _ticker = createTicker(_onTick)..start();
    // Wave 1 FTUE line (Stage 1 only) — request after the first frame so
    // the AceDialogueListener is mounted and ready to present.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeFireWaveStartLine(1);
    });
  }

  Future<ui.Image?> _loadUiImage(String assetPath) async {
    try {
      final data  = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Persistence
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadFailStreak() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _failStreak = prefs.getInt('failStreak_w${_world}_s$_stage') ?? 0;
    _boostUsed  = prefs.getBool('boostUsed_w${_world}_s$_stage') ?? false;
  }

  Future<void> _loadSettings() async {
    // v1.4 — wave-clear pause removed, so settings_autoskip_timer is a no-op
    // for gameplay. Kept readable from prefs by SettingsScreen.
    return;
  }

  Future<void> _saveStageResult({required bool cleared}) async {
    // Update in-memory immediately so a quick Retry sees the correct values.
    if (cleared) {
      _failStreak = 0;
      _boostUsed  = false;
    } else {
      _failStreak++;
      if (_failStreak % 5 == 0) _boostUsed = false;
    }
    // Persist asynchronously.
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setInt('failStreak_w${_world}_s$_stage', _failStreak);
    await prefs.setBool('boostUsed_w${_world}_s$_stage', _boostUsed);
    if (cleared) {
      final key = 'bestScore_w${_world}_s$_stage';
      final prev = prefs.getInt(key) ?? 0;
      if (_totalScore > prev) await prefs.setInt(key, _totalScore);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game loop
  // ─────────────────────────────────────────────────────────────────────────

  void _onTick(Duration _) {
    if (!mounted) return;
    if (_phase == _Phase.paused) return; // no setState while paused — stops canvas repaints
    _frame++;

    final active = _phase == _Phase.wave || _phase == _Phase.boss;
    if (_screenW > 0 && _playerInitialized && active) {
      _updateSimulation();
    }

    if (_phase == _Phase.gameOver &&
        !_reviveExpired &&
        !_reviveUsed &&
        !_adInFlight) {
      _reviveFrameAcc++;
      if (_reviveFrameAcc >= 60) {
        _reviveFrameAcc = 0;
        _reviveCountdown--;
        if (_reviveCountdown <= 0) _reviveExpired = true;
      }
    }

    if (_vignetteFrames > 0) {
      _vignetteFrames--;
      _vignetteOpacity = _vignetteFrames / _kVignetteDuration * 0.28;
    } else {
      _vignetteOpacity = 0;
    }

    if (_screenShakeFrames > 0) _screenShakeFrames--;
    if (_waveChipPulseFrames > 0) _waveChipPulseFrames--;
    if (_bossRedFlashFrames > 0) _bossRedFlashFrames--;

    setState(() {});
  }

  void _updateSimulation() {
    _scrollBackground();
    _handleInvincibility();
    _tickPowerUps();
    _tickDrone();
    _tickLaser();
    _firePlayerBullet();
    _movePlayerBullets();
    _moveEnemyBullets();
    _updatePickups();
    _tickFloatTexts();
    _updateComboWindow();

    if (_phase == _Phase.wave) {
      _updateWave();
    } else {
      _updateBoss();
    }
  }

  void _scrollBackground() {
    _bgOffset += 0.6;
    final bgH = _bgImage != null
        ? _screenW * (_bgImage!.height / _bgImage!.width)
        : _screenH;
    if (_bgOffset >= bgH) _bgOffset = 0;
  }

  void _handleInvincibility() {
    if (!_playerInvincible) return;
    _invincibleFrames--;
    _playerVisible = (_invincibleFrames ~/ 8) % 2 == 0;
    if (_invincibleFrames <= 0) {
      _playerInvincible = false;
      _playerVisible = true;
    }
  }

  void _tickPowerUps() {
    if (_rapidFireActive) { _rapidFireFrames--; if (_rapidFireFrames <= 0) _rapidFireActive = false; }
    if (_splitShotActive) { _splitShotFrames--; if (_splitShotFrames <= 0) _splitShotActive = false; }
    if (_speedBoostActive) { _speedBoostFrames--; if (_speedBoostFrames <= 0) _speedBoostActive = false; }
    if (_droneActive) { _droneFrames--; if (_droneFrames <= 0) _droneActive = false; }
    if (_laserActive) { _laserFrames--; if (_laserFrames <= 0) _laserActive = false; }
    if (_magnetActive) { _magnetFrames--; if (_magnetFrames <= 0) _magnetActive = false; }
    if (_ghostActive) { _ghostFrames--; if (_ghostFrames <= 0) _ghostActive = false; }
    if (_freezeActive) { _freezeFrames--; if (_freezeFrames <= 0) _freezeActive = false; }
  }

  void _tickDrone() {
    if (!_droneActive) { _droneFireTimer = 0; return; }
    _droneFireTimer++;
    // 50% less DPS than player = fire at double the base interval
    if (_droneFireTimer >= _fireRateBase * 2) {
      _droneFireTimer = 0;
      final droneX = (_playerX + _kDroneOffsetX).clamp(10.0, _screenW - 10);
      _playerBullets.add(_PlayerBullet(x: droneX, y: _playerY - 22));
    }
  }

  void _tickLaser() {
    if (!_laserActive) { _laserTickTimer = 0; return; }
    _laserTickTimer++;
    if (_laserTickTimer < _kLaserTickInterval) return;
    _laserTickTimer = 0;

    final beamLeft   = _playerX - _kLaserHitHalfWidth;
    final beamRight  = _playerX + _kLaserHitHalfWidth;
    final beamBottom = _playerY - 38.0;

    // Wave enemies
    for (final e in _enemies) {
      if (!e.active || e.exploding || e.pendingRespawn) continue;
      if (e.x >= beamLeft && e.x <= beamRight && e.y <= beamBottom) {
        _bulletsHit++;
        _damageEnemy(e, 1);
      }
    }

    // Boss
    if (_phase == _Phase.boss && !_bossExploding) {
      final bossCfg = kEnemyConfigs[EnemyTier.boss]!;
      if ((_bossX - _playerX).abs() < bossCfg.hitRadius + _kLaserHitHalfWidth &&
          _bossY <= beamBottom) {
        _bulletsHit++;
        _bossHp--;
        _bossFlashing = true;
        _bossFlashFrames = 3;
        if (_bossHp <= 0) { _bossExploding = true; _bossExplosionFrame = 0; }
      }
    }
  }

  void _firePlayerBullet() {
    _bulletTimer++;
    if (_bulletTimer >= _effectiveFireRate()) {
      _bulletTimer = 0;
      _playerBullets.add(_PlayerBullet(x: _playerX, y: _playerY - 22));
      _bulletsFired++;
      if (_splitShotActive) {
        // ±20° spread, same speed magnitude as the centre bullet (7 lp/frame)
        const spread = 20.0 * pi / 180.0;
        const spd = 7.0;
        _playerBullets.add(_PlayerBullet(
          x: _playerX, y: _playerY - 22,
          dx: -spd * sin(spread),
        ));
        _playerBullets.add(_PlayerBullet(
          x: _playerX, y: _playerY - 22,
          dx:  spd * sin(spread),
        ));
      }
    }
  }

  int _effectiveFireRate() {
    int rate = _fireRateBase;
    if (_rapidFireActive) rate = min(rate, 10);
    if (_speedBoostActive) rate = (rate / 1.3).round();
    return rate.clamp(6, 18);
  }

  double _effectiveMoveSpeed() => _speedBoostActive ? 1.6 : 1.0;

  void _movePlayerBullets() {
    _playerBullets.removeWhere((b) {
      b.x += b.dx;
      b.y -= 7;
      return b.y < -10 || b.x < -20 || b.x > _screenW + 20;
    });
  }

  void _moveEnemyBullets() {
    _enemyBullets.removeWhere((b) {
      b.x += b.dx;
      b.y += b.dy;
      if (b.y > _screenH + 10) return true;
      if (!_playerInvincible &&
          (b.x - _playerX).abs() < _kPlayerHitRadius &&
          (b.y - _playerY).abs() < _kPlayerHitRadius) {
        _hitPlayer(fromBullet: true);
        return true;
      }
      return false;
    });
  }

  void _updatePickups() {
    _pickups.removeWhere((p) {
      if (p.flashing) {
        p.flashFrames--;
        return p.flashFrames <= 0;
      }

      if (_magnetActive) {
        final dx = _playerX - p.x;
        final dy = _playerY - p.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < _kMagnetRadius) {
          // Pull toward player at 12% of the remaining gap per frame
          p.x += dx * 0.12;
          p.y += dy * 0.12;
        } else {
          p.y += 0.8; // outside magnet range — fall normally
        }
      } else {
        p.y += 0.8;
      }

      if (p.y > _screenH + 20) return true;
      if ((p.x - _playerX).abs() < 28 && (p.y - _playerY).abs() < 28) {
        _collectPickup(p);
        if (p.type.category == PowerUpCategory.instant) {
          p.flashing = true;
          p.flashFrames = 12;
          return false;
        }
        return true;
      }
      return false;
    });
  }

  void _tickFloatTexts() {
    _floatTexts.removeWhere((t) {
      // Stay stationary during the opacity-hold window, then drift up
      // only during the fade-out. Default holdFraction is 0.0 so existing
      // combo / coin floats rise from frame 0 as before.
      final progress = t.frame / t.life;
      if (progress > t.holdFraction) t.y -= t.riseSpeed;
      t.frame++;
      return t.frame >= t.life;
    });
  }

  void _updateComboWindow() {
    _killFrames.removeWhere((f) => _frame - f > _kComboWindow);
  }

  void _autoPatrol() {
    if (_hasTouched) return;
    _playerX += _patrolDir * 0.55 * _effectiveMoveSpeed();
    if (_playerX < 20 || _playerX > _screenW - 20) _patrolDir = -_patrolDir;
    _playerX = _playerX.clamp(20.0, _screenW - 20);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Enemy pool
  // ─────────────────────────────────────────────────────────────────────────

  void _buildEnemyPool() {
    _enemies.clear();
    final n = waveEnemyCount(_world, _currentWave);
    for (int i = 0; i < n; i++) {
      _enemies.add(_createEnemy(entryDelay: _rng.nextInt(120)));
    }
  }

  _GameEnemy _createEnemy({int entryDelay = 0}) {
    final tier = _activeTiers[_rng.nextInt(_activeTiers.length)];
    final cfg  = kEnemyConfigs[tier]!;
    final elite = _rng.nextDouble() < eliteRatio(_world, _currentWave);
    final hpMult = elite ? (1.5 * _diff.hpMult).ceil() : _diff.hpMult;
    final size   = elite ? cfg.renderSize * 1.3 : cfg.renderSize;
    final radius = elite ? cfg.hitRadius  * 1.3 : cfg.hitRadius.toDouble();

    final e = _GameEnemy(
      x: _rng.nextDouble() * (_screenW - 80) + 40,
      y: -size,
      speed: waveEnemySpeed(_currentWave) * (elite ? 1.2 : 1.0),
      driftPhase: _rng.nextDouble() * pi * 2,
      tier: tier,
      maxHp: hpMult,
      renderSize: size,
      hitRadius: radius,
      isElite: elite,
    );
    e.entryDelay = entryDelay;
    e.spawnFrame = _frame;
    return e;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Wave phase
  // ─────────────────────────────────────────────────────────────────────────

  void _updateWave() {
    _autoPatrol();
    _processRespawns();

    for (int i = 0; i < _enemies.length; i++) {
      final e = _enemies[i];

      // Pending respawn — handled by _processRespawns
      if (e.pendingRespawn) continue;

      // Entry delay — not yet active
      if (!e.active) {
        if (_waveKilled < _waveTarget &&
            _frame >= e.spawnFrame + e.entryDelay) {
          e.active = true;
        }
        continue;
      }

      // Exploding
      if (e.exploding) {
        e.explosionFrame++;
        if (e.explosionFrame >= 16) _onExplosionComplete(i);
        continue;
      }

      // Hit-flash
      if (e.flashing) {
        e.flashFrames--;
        if (e.flashFrames <= 0) {
          e.flashing = false;
          if (e.hp <= 0) {
            e.exploding = true;
            e.explosionFrame = 0;
          }
        }
        continue;
      }

      // Movement and firing — suspended while freeze is active
      if (!_freezeActive) {
        final speed = e.speed * _diff.speedMult;
        e.y += speed;
        e.x += sin(_frame * 0.04 + e.driftPhase) * 0.5;
        e.x = e.x.clamp(e.renderSize / 2, _screenW - e.renderSize / 2);

        // Reached bottom → damage + respawn (not a kill)
        if (e.y > _screenH + e.renderSize) {
          _hitPlayer(fromBullet: false);
          _enemies[i] = _createEnemy(entryDelay: _rng.nextInt(60) + 15);
          continue;
        }

        if (_rng.nextDouble() < 1.0 / waveEnemyFireRate(_world, _currentWave)) {
          _enemyBullets.add(
              _EnemyBullet(x: e.x, y: e.y + e.renderSize / 2, dy: 2.5));
        }
      }

      // Player bullet hits (work even while frozen)
      _PlayerBullet? hitBullet;
      for (final b in _playerBullets) {
        if ((b.x - e.x).abs() < e.hitRadius + 3 &&
            (b.y - e.y).abs() < e.hitRadius + 3) {
          hitBullet = b;
          break;
        }
      }
      if (hitBullet != null) {
        _playerBullets.remove(hitBullet);
        _bulletsHit++;
        _damageEnemy(e, 1);
      }

      // Player body collision
      if (!_playerInvincible &&
          (e.x - _playerX).abs() < e.hitRadius + _kPlayerHitRadius &&
          (e.y - _playerY).abs() < e.hitRadius + _kPlayerHitRadius) {
        _hitPlayer(fromBullet: false);
        _damageEnemy(e, e.hp);
      }
    }

    _checkWaveComplete();
  }

  void _processRespawns() {
    if (_waveKilled >= _waveTarget) return; // quota met — no more respawns
    for (int i = 0; i < _enemies.length; i++) {
      final e = _enemies[i];
      if (e.pendingRespawn && _frame >= e.respawnAt) {
        _enemies[i] = _createEnemy(entryDelay: _rng.nextInt(60) + 15);
      }
    }
  }

  void _onExplosionComplete(int index) {
    // Kill counted already in _damageEnemy → _onEnemyKilled
    if (_waveKilled < _waveTarget) {
      // Schedule respawn
      _enemies[index].pendingRespawn = true;
      _enemies[index].respawnAt = _frame + _kRespawnDelay;
    } else {
      // Quota met — slot retires
      _enemies[index].active = false;
      _enemies[index].pendingRespawn = false;
    }
  }

  void _checkWaveComplete() {
    if (_waveClearPending) return;
    if (_waveKilled < _waveTarget) return;
    final allDone = _enemies.every(
        (e) => !e.active || e.pendingRespawn);
    if (allDone) _triggerWaveClear();
  }

  void _damageEnemy(_GameEnemy e, int dmg) {
    e.hp -= dmg;
    e.flashing = true;
    e.flashFrames = e.hp <= 0 ? 4 : 2;
    if (e.hp <= 0) _onEnemyKilled(e);
  }

  void _onEnemyKilled(_GameEnemy e) {
    _killFrames.add(_frame);
    final combo = comboMultiplier(_killFrames.length);
    final pts   = scorePerKill(_currentWave, combo);
    _totalScore += pts;
    _waveKilled++;

    if (combo > _bestCombo) _bestCombo = combo.toInt();
    if (combo >= 3.0 && _screenShakeFrames <= 0) _screenShakeFrames = 18;

    if (combo > 1.0) {
      final col = combo >= 5.0
          ? const Color(0xFFE24B4A)
          : combo >= 3.0
              ? const Color(0xFFE24B4A)
              : combo >= 2.0
                  ? const Color(0xFFEF9F27)
                  : const Color(0xFFC0DD97);
      _floatTexts.add(_FloatText(
        x: e.x, y: e.y,
        text: '+$pts ×${combo.toStringAsFixed(combo == combo.truncateToDouble() ? 0 : 1)}',
        color: col,
        bold: combo >= 5.0,
        life: 52,
      ));
    }

    _rollPowerUpDrop(e.x, e.y);
  }

  void _rollPowerUpDrop(double x, double y) {
    final economy = context.read<EconomyState>();
    if (FtueRules.shouldForceHpDrop(
      currentWorld: _world,
      currentStage: _stage,
      currentWave: _currentWave,
      firedTriggers: economy.firedFtueTriggers,
    )) {
      _pickups.add(_Pickup(x: x, y: y, type: PowerUpType.hp));
      economy.markFtueTriggerFired(FtueTriggers.stage1Wave2HpForced);
      return;
    }

    final rates = _isBoostWave ? kBoostDropRates : normalDropRates(_world, _currentWave);

    for (final entry in rates.entries) {
      if (_rng.nextDouble() < entry.value) {
        _pickups.add(_Pickup(x: x, y: y, type: entry.key));
        break;
      }
    }
  }

  void _collectPickup(_Pickup p) {
    if (p.type.category == PowerUpCategory.collectible) {
      _trayKey.currentState?.addCharge(p.type);
      return;
    }
    switch (p.type) {
      case PowerUpType.rapidFire:
        _rapidFireActive = true;
        _rapidFireFrames = PowerUpType.rapidFire.durationFrames;
      case PowerUpType.shield:
        _shieldActive = true;
        _shieldHitsRemaining = 3;
      case PowerUpType.splitShot:
        _splitShotActive = true;
        _splitShotFrames = PowerUpType.splitShot.durationFrames;
      case PowerUpType.speedBoost:
        _speedBoostActive = true;
        _speedBoostFrames = PowerUpType.speedBoost.durationFrames;
      case PowerUpType.droneWingman:
        _droneActive = true;
        _droneFrames = PowerUpType.droneWingman.durationFrames;
      case PowerUpType.hp:
        final restore = (_maxHp * 0.25).round();
        final before  = _hp;
        _hp = min(_maxHp, _hp + restore);
        final gained  = _hp - before;
        if (gained > 0) {
          _floatTexts.add(_FloatText(
            x: _playerX, y: _playerY - 20,
            text: '+$gained HP',
            color: const Color(0xFF97C459),
            life: 48,
          ));
        }
      case PowerUpType.coins:
        const amount = EconomyConstants.coinPickupValueRegular;
        context.read<EconomyState>().addCoins(amount, source: 'in_game_pickup');
        _floatTexts.add(_FloatText(
          x: _playerX, y: _playerY - 20,
          text: '+$amount',
          color: const Color(0xFFFFC83D),
          life: 48,
        ));
      default:
        break;
    }
  }

  void _onCollectibleActivated(PowerUpType type) {
    switch (type) {
      case PowerUpType.bomb:
        _detonateBomb();
      case PowerUpType.laser:
        _laserActive = true;
        _laserFrames = PowerUpType.laser.durationFrames;
      case PowerUpType.magnet:
        _magnetActive = true;
        _magnetFrames = PowerUpType.magnet.durationFrames;
      case PowerUpType.ghostMode:
        _ghostActive = true;
        _ghostFrames = PowerUpType.ghostMode.durationFrames;
      case PowerUpType.freezeTime:
        _freezeActive = true;
        _freezeFrames = PowerUpType.freezeTime.durationFrames;
      default:
        break;
    }
  }

  void _detonateBomb() {
    for (final e in _enemies) {
      if (!e.active || e.exploding || e.pendingRespawn) continue;
      _damageEnemy(e, (e.hp * 0.6).ceil());
    }
    if (_phase == _Phase.boss && !_bossExploding) {
      _bossHp = max(0, _bossHp - (_bossHp * 0.3).ceil());
      _bossFlashing = true;
      _bossFlashFrames = 3;
      if (_bossHp <= 0) { _bossExploding = true; _bossExplosionFrame = 0; }
    }
  }

  void _triggerWaveClear() {
    // v1.4 — no freeze. Capture wave accuracy for the stage average, reset
    // per-wave trackers, then fire the visual flourish (edge sweep + reward
    // float) and schedule the next wave to begin while gameplay continues.
    _waveClearPending = true;
    _waveAccuracies.add(_accuracy);
    _bulletsFired = 0;
    _bulletsHit   = 0;
    _killFrames.clear();

    // Edge sweep: opacity 0 -> 0.6 fade-in (80 ms), hold (200 ms),
    // then 0.6 -> 0 fade-out (600 ms). The AnimatedOpacity widget
    // owns the fade durations — we just toggle the target opacity.
    _showEdgeSweep = true;
    _edgeSweepOpacity = 0.6;
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _edgeSweepOpacity = 0.0);
    });
    Future.delayed(const Duration(milliseconds: 880), () {
      if (!mounted) return;
      setState(() => _showEdgeSweep = false);
    });

    // Reward float: spawns 200 ms after the sweep fires, rises and fades
    // alongside the sweep's fade-out.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _spawnWaveClearFloat();
    });

    // Wave advances 400 ms after last kill. _advanceWave handles the
    // boss transition (wave 10) on its own.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _advanceWave();
    });

    // Surface the next wave's FTUE intro now — same trigger point as
    // before; the bubble runs concurrently with the new wave entry stagger.
    // Only fires on Stage 1 for the two pre-boss transitions.
    final upcoming = _currentWave + 1;
    if (upcoming < _maxWave) _maybeFireWaveStartLine(upcoming);
  }

  void _spawnWaveClearFloat() {
    // Per design: stars are a stage-level rating only — never shown
    // mid-stage. The float is purely positive feedback for clearing a wave.
    //
    // Dead center, fully stationary, with a hard dark outline for
    // readability. Holds at full opacity for 3 s then fades in place
    // over ~1 s. Total life 240 frames @ 60 fps.
    _floatTexts.add(_FloatText(
      x: _screenW / 2,
      y: _screenH / 2,
      text: 'Wave $_currentWave clear',
      color: const Color(0xFFEF9F27),
      bold: true,
      life: 240,
      fontSize: 24,
      riseSpeed: 0.0,     // no movement — fades in place
      glowBlur: 4,        // soft black drop-shadow halo (with outline)
      holdFraction: 0.75, // 3 s held, 1 s fade
    ));
  }

  void _advanceWave() {
    _waveClearPending = false;
    _currentWave++;
    _waveChipPulseFrames = 12;
    if (_currentWave >= _maxWave) {
      // Boss transition still does a hard reset — boss entry has its own
      // fly-in/red-flash sequence.
      _enemyBullets.clear();
      _playerBullets.clear();
      _startBoss();
    } else {
      // v1.4 — keep in-flight bullets to preserve the no-stop feel.
      _waveTarget  = waveEnemyCount(_world, _currentWave);
      _waveKilled  = 0;
      _buildEnemyPool();
      _phase = _Phase.wave;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Boss phase
  // ─────────────────────────────────────────────────────────────────────────

  void _startBoss() {
    _bossHp       = bossHpForWorld(_world);
    _bossMaxHp    = _bossHp;
    _bossX        = _screenW / 2;
    _bossY        = _kBossEntryStartY;
    _bossFlashing = false;
    _bossExploding = false;
    _bossExplosionFrame = 0;
    _bossFireTimer = 0;
    _bossEntering = true;
    _bossEntryFrame = 0;
    _bossRedFlashFrames = 3;
    _enemies.clear();
    _enemyBullets.clear();
    _phase = _Phase.boss;
  }

  // Quadratic ease-out: fast start, smooth landing.
  double _easeOut(double t) {
    final c = t.clamp(0.0, 1.0);
    return 1.0 - (1.0 - c) * (1.0 - c);
  }

  void _updateBoss() {
    _autoPatrol();

    if (_bossExploding) {
      _bossExplosionFrame++;
      if (_bossExplosionFrame >= 16) {
        _totalScore += kEnemyConfigs[EnemyTier.boss]!.scoreValue;
        _saveStageResult(cleared: true);
        _phase = _Phase.stageClear;
      }
      return;
    }

    // Fly-in animation — boss cannot fire or be damaged while entering
    if (_bossEntering) {
      _bossEntryFrame++;
      final targetY = _screenH * _kBossTargetYFrac;
      final t = _easeOut(_bossEntryFrame / _kBossEntryDuration);
      _bossY = _kBossEntryStartY + (targetY - _kBossEntryStartY) * t;
      if (_bossEntryFrame >= _kBossEntryDuration) {
        _bossEntering = false;
        _bossY = targetY;
      }
      return;
    }

    if (_bossFlashing) {
      _bossFlashFrames--;
      if (_bossFlashFrames <= 0) _bossFlashing = false;
    }

    // Movement and firing — suspended while freeze is active
    if (!_freezeActive) {
      _bossX = _screenW / 2 + sin(_frame * 0.022) * (_screenW * 0.38);
      _bossY = _screenH * 0.15 + sin(_frame * 0.014) * 18;

      _bossFireTimer++;
      if (_bossFireTimer >= bossFireRate(_world)) {
        _bossFireTimer = 0;
        final spd = bossBulletSpeed(_world);
        _enemyBullets.add(_EnemyBullet(x: _bossX, y: _bossY + 40, dy: spd));
        if (_world >= 3) {
          final spread = bossBulletSpread(_world);
          _enemyBullets.add(_EnemyBullet(x: _bossX, y: _bossY + 40, dx: -spread, dy: spd * 0.93));
          _enemyBullets.add(_EnemyBullet(x: _bossX, y: _bossY + 40, dx:  spread, dy: spd * 0.93));
        }
      }
    }

    // Bullet hits and body collision still apply during freeze
    final bossCfg = kEnemyConfigs[EnemyTier.boss]!;
    _playerBullets.removeWhere((b) {
      if ((b.x - _bossX).abs() < bossCfg.hitRadius + 3 &&
          (b.y - _bossY).abs() < bossCfg.hitRadius + 3) {
        _bulletsHit++;
        _bossHp--;
        _bossFlashing = true;
        _bossFlashFrames = 3;
        if (_bossHp <= 0) { _bossExploding = true; _bossExplosionFrame = 0; }
        return true;
      }
      return false;
    });

    if (!_playerInvincible &&
        (_bossX - _playerX).abs() < bossCfg.hitRadius + _kPlayerHitRadius &&
        (_bossY - _playerY).abs() < bossCfg.hitRadius + _kPlayerHitRadius) {
      _hitPlayer(fromBullet: false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Player damage
  // ─────────────────────────────────────────────────────────────────────────

  void _hitPlayer({required bool fromBullet}) {
    if (_playerInvincible) return;
    if (_ghostActive) return; // ghost mode — total invulnerability, no vignette
    if (_shieldActive) {
      _shieldHitsRemaining--;
      if (_shieldHitsRemaining <= 0) _shieldActive = false;
      _vignetteFrames = _kVignetteDuration ~/ 2;
      return;
    }
    _hp -= fromBullet ? 10 : 15;
    _vignetteFrames = _kVignetteDuration;

    if (_hp <= 0) {
      _hp = 0;
      _waveAtDeath    = _currentWave;
      _bossHpAtDeath  = _bossMaxHp > 0 ? _bossHp / _bossMaxHp : 1.0;

      final economy = context.read<EconomyState>();
      economy.recordDeathThisStage();
      if (FtueRules.shouldFreeReviveOnDeath(
        currentWorld: _world,
        currentStage: _stage,
        firedTriggers: economy.firedFtueTriggers,
      )) {
        economy.markFtueTriggerFired(FtueTriggers.stage1FreeReviveUsed);
        economy.requestAceLine(AceLineKeys.ftueFirstDeath);
        _applyRevive(consumeOneShot: false);
        return;
      }

      _reviveCountdown = 8;
      _reviveFrameAcc  = 0;
      _reviveExpired   = false;
      _saveStageResult(cleared: false);
      _phase = _Phase.gameOver;
    } else {
      _playerInvincible = true;
      _invincibleFrames = _kInvincibleDuration;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage reset
  // ─────────────────────────────────────────────────────────────────────────

  void _fullReset() {
    // Re-evaluate boost for this retry (_failStreak already incremented by _saveStageResult)
    _isBoostWave = _failStreak >= 5 && !_boostUsed;
    if (_isBoostWave) _boostUsed = true;
    _phase = _Phase.wave;
    _currentWave  = 1;
    _waveTarget   = waveEnemyCount(_world, 1);
    _waveKilled   = 0;
    _hp           = _maxHp;
    _totalScore   = 0;
    _bestCombo    = 0;
    _bulletsFired = 0;
    _bulletsHit   = 0;
    _waveAccuracies.clear();
    _killFrames.clear();
    _playerBullets.clear();
    _enemyBullets.clear();
    _pickups.clear();
    _floatTexts.clear();
    _bossHp = 0; _bossMaxHp = 0; _bossExploding = false;
    _bossEntering = false; _bossEntryFrame = 0; _bossRedFlashFrames = 0;
    _rapidFireActive = false; _rapidFireFrames = 0;
    _shieldActive = false; _shieldHitsRemaining = 0;
    _splitShotActive = false; _splitShotFrames = 0;
    _speedBoostActive = false; _speedBoostFrames = 0;
    _droneActive = false; _droneFrames = 0; _droneFireTimer = 0;
    _laserActive = false; _laserFrames = 0; _laserTickTimer = 0;
    _magnetActive = false; _magnetFrames = 0;
    _ghostActive = false; _ghostFrames = 0;
    _freezeActive = false; _freezeFrames = 0;
    _trayKey.currentState?.reset();
    _playerX = _screenW / 2;
    _playerY = _screenH * 0.82;
    _playerInvincible = false;
    _playerVisible = true;
    _reviveUsed = false;
    _adInFlight = false;
    _rewardDoubled = false;
    _vignetteOpacity = 0;
    _vignetteFrames  = 0;
    _waveClearPending = false;
    _showEdgeSweep    = false;
    _edgeSweepOpacity = 0.0;
    _screenShakeFrames = 0;
    _hasTouched = false;
    _buildEnemyPool();
  }

  void _revive() {
    if (_playerGems < revivePrice(_waveAtDeath)) return;
    _playerGems -= revivePrice(_waveAtDeath);
    _applyRevive();
    context.read<EconomyState>().requestAceLine(AceLineKeys.ftueReviveYes);
  }

  void _applyRevive({bool consumeOneShot = true}) {
    if (consumeOneShot) _reviveUsed = true;
    _hp = _maxHp;
    if (_currentWave >= _maxWave) {
      _bossHp = (_bossHpAtDeath * _bossMaxHp).round().clamp(1, _bossMaxHp);
      _bossExploding = false;
    }
    _playerInvincible = true;
    _invincibleFrames = _kInvincibleDuration;
    _phase = _currentWave >= _maxWave ? _Phase.boss : _Phase.wave;
  }

  Future<void> _watchAdToRevive() async {
    if (_adInFlight) return;
    final economy = context.read<EconomyState>();
    if (!economy.canTakeAdRevive()) {
      _showAdSnack('No more free revives this stage');
      return;
    }
    setState(() => _adInFlight = true);
    final outcome = await economy.showRewardedAd(AdPlacement.reviveMidStage);
    if (!mounted) return;
    if (outcome.result == AdShowResult.rewardEarned) {
      economy.commitAdRevive();
      setState(() {
        _adInFlight = false;
        _applyRevive();
      });
      economy.requestAceLine(AceLineKeys.ftueReviveYes);
    } else {
      setState(() => _adInFlight = false);
      _showAdSnack(_messageForAdOutcome(outcome.result));
    }
  }

  Future<void> _watchAdToDoubleReward() async {
    if (_adInFlight || _rewardDoubled) return;
    setState(() => _adInFlight = true);
    final outcome = await context
        .read<EconomyState>()
        .showRewardedAd(AdPlacement.doubleBiomeEnd);
    if (!mounted) return;
    if (outcome.result == AdShowResult.rewardEarned) {
      setState(() {
        _adInFlight = false;
        _rewardDoubled = true;
      });
    } else {
      setState(() => _adInFlight = false);
      _showAdSnack(_messageForAdOutcome(outcome.result));
    }
  }

  void _maybeFireWaveStartLine(int wave) {
    if (_world != 1 || _stage != 1) return;
    final key = switch (wave) {
      1 => AceLineKeys.ftueWave1Start,
      2 => AceLineKeys.ftueWave2Start,
      3 => AceLineKeys.ftueWave3Start,
      _ => null,
    };
    if (key == null) return;
    context.read<EconomyState>().requestAceLine(key);
  }

  String _messageForAdOutcome(AdShowResult r) {
    switch (r) {
      case AdShowResult.dismissed:
        return 'Ad cancelled — no reward';
      case AdShowResult.failedToLoad:
        return 'Ad unavailable, try again';
      case AdShowResult.capReached:
        return 'Daily ad limit reached';
      case AdShowResult.rewardEarned:
        return '';
    }
  }

  void _showAdSnack(String msg) {
    if (msg.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    _screenW = mq.size.width;
    _screenH = mq.size.height;

    // Loading screen — shown until all assets are resolved
    if (!_assetsReady) {
      return const Scaffold(
        backgroundColor: Color(0xFF0a1a0a),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3B6D11)),
        ),
      );
    }

    if (!_playerInitialized && _screenW > 0) {
      _playerX = _screenW / 2;
      _playerY = _screenH * 0.82;
      _playerInitialized = true;
      _waveTarget = waveEnemyCount(_world, _currentWave);
      _buildEnemyPool();
    }

    double shakeX = 0, shakeY = 0;
    if (_screenShakeFrames > 0) {
      shakeX = (_rng.nextDouble() - 0.5) * 8;
      shakeY = (_rng.nextDouble() - 0.5) * 8;
    }

    double critVignette = 0;
    if (_hp > 0 && _hp / _maxHp < 0.2) {
      critVignette = sin(_frame * pi / 45) * 0.05 + 0.12;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0a1a0a),
      body: AceDialogueListener(
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          if (_phase != _Phase.wave && _phase != _Phase.boss) return;
          final sp = _effectiveMoveSpeed();
          setState(() {
            _hasTouched = true;
            _playerX = (_playerX + d.delta.dx * sp).clamp(22.0, _screenW - 22);
            _playerY = (_playerY + d.delta.dy * sp)
                .clamp(_screenH * 0.48, _screenH - 28);
          });
        },
        child: Stack(
          children: [
            // ── Canvas ───────────────────────────────────────────────────
            RepaintBoundary(
              child: Transform.translate(
                offset: Offset(shakeX, shakeY),
                child: CustomPaint(
                  size: Size(_screenW, _screenH),
                  painter: _GamePainter(
                    bgImage: _bgImage,
                    jetImage: _jetImage,
                    enemyImages: Map.unmodifiable(_enemyImages),
                    explosionSheet: _explosionSheet,
                    bulletImage: _bulletImage,
                    enemyBulletImage: _enemyBulletImage,
                    puDropImages: Map.unmodifiable(_puDropImages),
                    bgOffset: _bgOffset,
                    playerX: _playerX,
                    playerY: _playerY,
                    playerVisible: _playerVisible,
                    playerBullets: List.unmodifiable(_playerBullets),
                    enemyBullets: List.unmodifiable(_enemyBullets),
                    enemies: List.unmodifiable(_enemies),
                    pickups: List.unmodifiable(_pickups),
                    floatTexts: List.unmodifiable(_floatTexts),
                    bossX: _bossX,
                    bossY: _bossY,
                    bossFlashing: _bossFlashing,
                    bossExploding: _bossExploding,
                    bossExplosionFrame: _bossExplosionFrame,
                    phase: _phase,
                    screenW: _screenW,
                    screenH: _screenH,
                    frame: _frame,
                    laserActive: _laserActive,
                    laserFrames: _laserFrames,
                    droneActive: _droneActive,
                    ghostActive: _ghostActive,
                  ),
                ),
              ),
            ),

            // ── Boss entry red flash (3 frames) ──────────────────────────
            if (_bossRedFlashFrames > 0)
              IgnorePointer(
                child: Container(
                  color: Colors.red.withValues(alpha: 0.55),
                ),
              ),

            // ── Hit vignette ─────────────────────────────────────────────
            if (_vignetteOpacity > 0 || critVignette > 0)
              IgnorePointer(
                child: Container(
                  color: Colors.red.withValues(
                      alpha: max(_vignetteOpacity, critVignette)),
                ),
              ),

            // ── HUD ──────────────────────────────────────────────────────
            if (_phase == _Phase.wave || _phase == _Phase.boss) _buildHUD(),

            // ── Power-up tray ────────────────────────────────────────────
            // Kept continuously mounted (Offstage rather than `if`) so the
            // tray state — collectible counts — survives phase changes like
            // paused / gameOver / stageClear. Otherwise the tray widget is
            // disposed on every phase swap and collectibles reset to 0.
            Offstage(
              offstage: _phase != _Phase.wave && _phase != _Phase.boss,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: _PowerUpTray(
                      key: _trayKey,
                      slotImages: Map.unmodifiable(_puSlotImages),
                      onActivate: _onCollectibleActivated,
                    ),
                  ),
                ),
              ),
            ),

            // ── Boss HP bar ───────────────────────────────────────────────
            if (_phase == _Phase.boss && !_bossExploding && _bossMaxHp > 0)
              _buildBossHpBar(),

            // ── Drag hint ─────────────────────────────────────────────────
            if (!_hasTouched &&
                (_phase == _Phase.wave || _phase == _Phase.boss))
              _buildDragHint(),

            // ── Wave-clear edge sweep (no-stop, v1.4) ────────────────────
            // Rendered above HUD so the green border is visible on top of
            // chips. IgnorePointer so it never blocks drag input — gameplay
            // continues underneath.
            if (_showEdgeSweep) _buildEdgeSweep(),

            // ── Overlays ─────────────────────────────────────────────────
            if (_phase == _Phase.stageClear) _buildStageClearOverlay(),
            if (_phase == _Phase.gameOver)   _buildGameOverOverlay(),
            if (_phase == _Phase.paused)     _buildPauseOverlay(),
          ],
        ),
      ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HUD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHUD() {
    final hpFrac = (_hp / _maxHp).clamp(0.0, 1.0);
    final hpPct  = (hpFrac * 100).round();

    return SafeArea(
      child: Stack(
        children: [
          // Top bar
          Positioned(
            top: 0, left: 9, right: 9,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _hudChip(
                  'Wave $_currentWave/$_maxWave',
                  _waveChipPulseFrames > 0
                      ? const Color(0xFF3B6D11)
                      : const Color(0xFF173404),
                  const Color(0xFF97C459),
                ),
                _hudChip('$_totalScore', const Color(0xFF173404), const Color(0xFFC0DD97)),
                _hudChip('HP $hpPct%', const Color(0xFF412402), const Color(0xFFEF9F27)),
              ],
            ),
          ),

          // HP bar + shield placeholder
          Positioned(
            top: 26, left: 9, right: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(children: [
                    Container(height: 4, color: const Color(0xFF0d1f0d)),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      height: 4,
                      width: (_screenW - 18) * hpFrac,
                      color: _hp / _maxHp < 0.2
                          ? const Color(0xFFE24B4A)
                          : const Color(0xFF3B6D11),
                    ),
                  ]),
                ),
                const SizedBox(height: 2),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d0d1f),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                        color: const Color(0x4C534AB7), width: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Power-up tray is rendered as a sibling of the HUD in the
          // main Stack so it stays mounted across phase changes —
          // see _GameScreenState.build.

          // Pause button
          Positioned(
            bottom: 8, right: 8,
            child: GestureDetector(
              onTap: () {
                _prevPhase = _phase;
                setState(() => _phase = _Phase.paused);
              },
              child: Container(
                width: 32, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF3B6D11), width: 0.5),
                ),
                alignment: Alignment.center,
                child: const Text('II',
                    style: TextStyle(
                        color: Color(0xFF639922),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDragHint() {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.3),
        child: Text('drag to move',
            style: TextStyle(
                color: const Color(0xFF639922).withValues(alpha: 0.4),
                fontSize: 7)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Boss HP bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBossHpBar() {
    final frac = (_bossMaxHp > 0 ? _bossHp / _bossMaxHp : 0.0).clamp(0.0, 1.0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '⚠  ${worldName(_world).toUpperCase()} BOSS',
                style: const TextStyle(
                    color: Color(0xFFE24B4A),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3),
              ),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(height: 6, color: const Color(0xFF1f0d0d)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  height: 6,
                  width: (_screenW - 32) * frac,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFDD1111), Color(0xFFFF6633)]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text('$_bossHp / $_bossMaxHp',
                  style: const TextStyle(
                      color: Color(0xFFBB4444), fontSize: 8)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Wave-clear edge sweep (v1.4)
  //
  // Replaces the previous dark overlay + tap-to-continue flow. A green
  // border flashes around the screen for ~880 ms while gameplay continues
  // underneath. The reward float (spawned via _spawnWaveClearFloat) renders
  // on the canvas layer at the same time.
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEdgeSweep() {
    // Fade-in (80 ms) when _edgeSweepOpacity is being raised to 0.6,
    // fade-out (600 ms) when it drops back to 0. AnimatedOpacity takes
    // the duration we hand it for whichever direction is current.
    final fadingIn = _edgeSweepOpacity > 0;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _edgeSweepOpacity,
        duration: Duration(milliseconds: fadingIn ? 80 : 600),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF97C459),
              width: 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF97C459).withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 0,
                blurStyle: BlurStyle.inner,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage clear overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStageClearOverlay() {
    final avgAcc = _waveAccuracies.isEmpty
        ? 0
        : _waveAccuracies.reduce((a, b) => a + b) ~/ _waveAccuracies.length;
    final maxScore = maxPossibleScore(_world);
    final got2 = _totalScore >= (maxScore * 0.60).round() && avgAcc >= 70;
    final got3 = !_reviveUsed &&
        _totalScore >= (maxScore * 0.85).round() &&
        avgAcc >= 85;
    final stars    = got3 ? 3 : got2 ? 2 : 1;
    final mult     = _rewardDoubled ? 2 : 1;
    final baseReward = 500 * mult;
    final starBonus = (50 + (got2 ? 100 : 0) + (got3 ? 200 : 0)) * mult;
    final gemBonus  = (got3 ? 1 : 0) * mult;

    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stage $_stage Complete',
              style: const TextStyle(
                  color: Color(0xFFEF9F27),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3)),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEF9F27), width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(worldName(_world).toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFFEF9F27),
                    fontSize: 9,
                    letterSpacing: 2)),
          ),
          const SizedBox(height: 16),
          Text('★' * stars + '☆' * (3 - stars),
              style: const TextStyle(
                  fontSize: 28, color: Color(0xFFEF9F27))),
          const SizedBox(height: 14),
          _statRow('Total score', '$_totalScore', const Color(0xFFC0DD97)),
          _statRow('Avg accuracy', '$avgAcc%', const Color(0xFF97C459)),
          _statRow('Best combo', '×$_bestCombo', const Color(0xFFEF9F27)),
          const SizedBox(height: 10),
          _statRow('Base reward', '+$baseReward ★', const Color(0xFFEF9F27)),
          _statRow('Star bonus', '+$starBonus ★', const Color(0xFFEF9F27)),
          if (gemBonus > 0)
            _statRow('3★ bonus', '+$gemBonus 💎', const Color(0xFF97C459)),
          const SizedBox(height: 18),
          if (_rewardDoubled)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x222B6D11),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF97C459), width: 0.5),
              ),
              child: const Text('Reward Doubled ✓',
                  style: TextStyle(
                      color: Color(0xFFC0DD97),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            )
          else
            _watchAdButton(
              label: 'Watch Ad — 2× Reward',
              onTap: _watchAdToDoubleReward,
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _overlayBtn('Next Stage →', const Color(0xFF3B6D11),
                  () => Navigator.pop(context,
                      {'stageDelta': 1, 'score': _totalScore})),
              const SizedBox(width: 12),
              _overlayBtn('Home', const Color(0xFF1a1a1a),
                  () => Navigator.pop(context)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game over overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGameOverOverlay() {
    final price    = revivePrice(_waveAtDeath);
    final canRevive = !_reviveUsed && !_reviveExpired;
    final hasGems   = _playerGems >= price;
    final canAdRevive = canRevive &&
        context.watch<EconomyState>().canTakeAdRevive();

    return Container(
      color: const Color(0xB8000000),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Mission Failed',
              style: TextStyle(
                  color: Color(0xFFE24B4A),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3)),
          const SizedBox(height: 4),
          Text(
            'WAVE $_waveAtDeath  ·  ${worldName(_world).toUpperCase()} STAGE $_stage',
            style: const TextStyle(
                color: Color(0xFF791F1F), fontSize: 9, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          _statRow('Score', '$_totalScore', const Color(0xFFC0DD97)),
          _statRow('Wave reached', '$_waveAtDeath', const Color(0xFFEF9F27)),
          _statRow('Best combo', '×$_bestCombo', const Color(0xFF97C459)),
          if (_waveAtDeath >= _maxWave)
            _statRow('Boss HP left',
                '${(_bossHpAtDeath * 100).round()}%', const Color(0xFFE24B4A)),

          if (canRevive) ...[
            const SizedBox(height: 18),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x88200000),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: hasGems
                        ? const Color(0xFFE24B4A)
                        : const Color(0xFF553333),
                    width: 0.5),
              ),
              child: Column(children: [
                Text(
                  _waveAtDeath >= _maxWave
                      ? 'Return to boss fight?'
                      : 'Continue from Wave $_waveAtDeath?',
                  style: const TextStyle(
                      color: Color(0xFFEF9F27),
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_reviveCountdown s  ·  $price 💎 gems',
                  style: TextStyle(
                      color: hasGems
                          ? const Color(0xFFCC8833)
                          : const Color(0xFF664444),
                      fontSize: 11),
                ),
                const SizedBox(height: 4),
                const Text('Restores full HP · one time only',
                    style: TextStyle(
                        color: Color(0xFF885555), fontSize: 9)),
                if (_waveAtDeath >= _maxWave)
                  const Text('Boss HP preserved',
                      style: TextStyle(
                          color: Color(0xFF885555), fontSize: 9)),
                const SizedBox(height: 10),
                if (hasGems)
                  GestureDetector(
                    onTap: () => setState(_revive),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFE24B4A), width: 0.5),
                      ),
                      child: const Text('Revive',
                          style: TextStyle(
                              color: Color(0xFFFF8888),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  )
                else
                  const Text('Not enough gems',
                      style: TextStyle(
                          color: Color(0xFF664444), fontSize: 11)),
              ]),
            ),
          ],

          if (canAdRevive) ...[
            const SizedBox(height: 14),
            _watchAdButton(
              label: 'Watch Ad — Free Revive',
              onTap: _watchAdToRevive,
            ),
          ],

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _overlayBtn('Retry Stage', const Color(0xFF3B6D11), () {
                _maybeFireReviveDeclined(canRevive);
                setState(_fullReset);
              }),
              const SizedBox(width: 12),
              _overlayBtn('Home', const Color(0xFF1a1a1a), () {
                _maybeFireReviveDeclined(canRevive);
                Navigator.pop(context);
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _maybeFireReviveDeclined(bool hadReviveOption) {
    if (!hadReviveOption) return;
    context.read<EconomyState>().requestAceLine(AceLineKeys.ftueReviveNo);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pause overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Paused',
              style: TextStyle(
                  color: Color(0xFFC0DD97),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4)),
          const SizedBox(height: 6),
          Text(
            'Wave $_currentWave/$_maxWave  ·  $_totalScore pts  ·  ${(_hp / _maxHp * 100).round()}% HP',
            style: const TextStyle(color: Color(0xFF639922), fontSize: 10),
          ),
          const SizedBox(height: 28),
          _overlayBtn('Resume', const Color(0xFF3B6D11),
              () => setState(() => _phase = _prevPhase)),
          const SizedBox(height: 10),
          _overlayBtn('Restart', const Color(0xFF1a2a0a),
              () => setState(_fullReset)),
          const SizedBox(height: 10),
          _overlayBtn('Quit to Menu', const Color(0xFF1a1a1a),
              () => Navigator.pop(context)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _statRow(String label, String value, Color col) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ',
                style: const TextStyle(
                    color: Color(0xFF557755), fontSize: 12)),
            Text(value,
                style: TextStyle(
                    color: col,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _overlayBtn(String label, Color bg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24, width: 0.5),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFFC0DD97),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
        ),
      );

  Widget _watchAdButton({
    required String label,
    required Future<void> Function() onTap,
  }) {
    final loading = _adInFlight;
    return GestureDetector(
      onTap: loading ? null : () => onTap(),
      child: Opacity(
        opacity: loading ? 0.6 : 1,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFCC8833), Color(0xFFEF9F27)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFFFD27A), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF1a1a1a)),
                )
              else
                const Icon(Icons.play_arrow_rounded,
                    size: 18, color: Color(0xFF1a1a1a)),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF1a1a1a),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game canvas painter
// ─────────────────────────────────────────────────────────────────────────────

class _GamePainter extends CustomPainter {
  final ui.Image? bgImage, jetImage, explosionSheet, bulletImage, enemyBulletImage;
  final Map<PowerUpType, ui.Image?> puDropImages;
  final Map<EnemyTier, ui.Image?> enemyImages;
  final double bgOffset, playerX, playerY;
  final bool playerVisible;
  final List<_PlayerBullet> playerBullets;
  final List<_EnemyBullet> enemyBullets;
  final List<_GameEnemy> enemies;
  final List<_Pickup> pickups;
  final List<_FloatText> floatTexts;
  final double bossX, bossY;
  final bool bossFlashing, bossExploding;
  final int bossExplosionFrame;
  final _Phase phase;
  final double screenW, screenH;
  final int frame;
  final bool laserActive;
  final int laserFrames;
  final bool droneActive;
  final bool ghostActive;

  _GamePainter({
    required this.bgImage, required this.jetImage,
    required this.explosionSheet, required this.bulletImage,
    required this.enemyBulletImage,
    required this.puDropImages,
    required this.enemyImages, required this.bgOffset,
    required this.playerX, required this.playerY,
    required this.playerVisible, required this.playerBullets,
    required this.enemyBullets, required this.enemies,
    required this.pickups, required this.floatTexts,
    required this.bossX, required this.bossY,
    required this.bossFlashing, required this.bossExploding,
    required this.bossExplosionFrame, required this.phase,
    required this.screenW, required this.screenH, required this.frame,
    required this.laserActive, required this.laserFrames,
    required this.droneActive, required this.ghostActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Hard guard — never draw before core images are ready
    if (bgImage == null || jetImage == null) return;

    _drawBackground(canvas, size);
    _drawPickups(canvas);
    _drawEnemyBullets(canvas);
    _drawPlayerBullets(canvas);
    _drawEnemies(canvas);
    if (phase == _Phase.boss) _drawBoss(canvas);
    if (laserActive) _drawLaser(canvas);
    if (droneActive) _drawDrone(canvas);
    if (playerVisible) _drawPlayer(canvas);
    _drawFloatTexts(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final img  = bgImage!;
    final drawH = size.width * (img.height / img.width);
    final src  = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.low;
    canvas.drawImageRect(img, src,
        Rect.fromLTWH(0, bgOffset - drawH, size.width, drawH), paint);
    canvas.drawImageRect(img, src,
        Rect.fromLTWH(0, bgOffset, size.width, drawH), paint);
    canvas.drawImageRect(img, src,
        Rect.fromLTWH(0, bgOffset + drawH, size.width, drawH), paint);
  }

  void _drawPlayerBullets(Canvas canvas) {
    for (final b in playerBullets) {
      if (bulletImage != null) {
        final img = bulletImage!;
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src,
            Rect.fromCenter(center: Offset(b.x, b.y), width: 10, height: 18),
            Paint());
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(b.x, b.y), width: 3, height: 11),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF97C459),
        );
      }
    }
  }

  void _drawEnemyBullets(Canvas canvas) {
    for (final b in enemyBullets) {
      if (enemyBulletImage != null) {
        final img = enemyBulletImage!;
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src,
            Rect.fromCenter(center: Offset(b.x, b.y), width: 10, height: 18),
            Paint());
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(b.x, b.y), width: 3, height: 8),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFE24B4A),
        );
      }
    }
  }

  void _drawDrone(Canvas canvas) {
    final droneX = (playerX + 52.0).clamp(10.0, screenW - 10.0);
    final droneY = playerY;
    final img    = puDropImages[PowerUpType.droneWingman];

    // Teal glow beneath drone
    canvas.drawCircle(
      Offset(droneX, droneY),
      26,
      Paint()
        ..color = const Color(0x445DCAA5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    if (img != null) {
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      canvas.drawImageRect(
        img, src,
        Rect.fromCenter(center: Offset(droneX, droneY), width: 40, height: 40),
        Paint(),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(droneX, droneY), width: 40, height: 40),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF5DCAA5),
      );
    }
  }

  void _drawLaser(Canvas canvas) {
    final cx     = playerX;
    const top    = 0.0;
    final bottom = playerY - 38.0;

    // Flicker intensity: startup burst for first 12 frames, steady thereafter
    final startupBurst = laserFrames > (PowerUpType.laser.durationFrames - 12);
    final flicker      = startupBurst ? 1.3 : (0.85 + 0.15 * sin(frame * 0.7));

    // Layer 1 — wide orange-red outer glow
    canvas.drawRect(
      Rect.fromLTRB(cx - 22 * flicker, top, cx + 22 * flicker, bottom),
      Paint()
        ..color = const Color(0x44FF3300)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Layer 2 — red mid glow
    canvas.drawRect(
      Rect.fromLTRB(cx - 9, top, cx + 9, bottom),
      Paint()
        ..color = Color.fromRGBO(226, 32, 32, 0.72 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Layer 3 — vivid red beam body
    canvas.drawRect(
      Rect.fromLTRB(cx - 3.5, top, cx + 3.5, bottom),
      Paint()..color = const Color(0xFFE82020),
    );

    // Layer 4 — white-pink core
    canvas.drawRect(
      Rect.fromLTRB(cx - 1.2, top, cx + 1.2, bottom),
      Paint()..color = const Color(0xFFFFEEEE),
    );

    // Muzzle burst — orange energy ring at the jet's cannon tip
    final muzzleY = bottom;
    canvas.drawCircle(
      Offset(cx, muzzleY),
      20 * flicker,
      Paint()
        ..color = const Color(0x99FF6622)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      Offset(cx, muzzleY), 6,
      Paint()..color = const Color(0xFFFFDDCC),
    );
  }

  void _drawPickups(Canvas canvas) {
    const double orbSize = 44.0;

    for (final p in pickups) {
      final center = Offset(p.x, p.y);

      // Brief white flash when an instant power-up is collected
      if (p.flashing) {
        final alpha = p.flashFrames / 12.0;
        canvas.drawCircle(
          center, 34,
          Paint()
            ..color = Colors.white.withValues(alpha: alpha * 0.75)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        continue;
      }

      // Accent-coloured glow halo
      canvas.drawCircle(
        center, orbSize / 2 + 6,
        Paint()
          ..color = p.type.accentColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      final img = puDropImages[p.type];
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(
          img, src,
          Rect.fromCenter(center: center, width: orbSize, height: orbSize),
          Paint(),
        );
      } else {
        // Placeholder: solid coloured rect labelled with power-up name
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: orbSize, height: orbSize),
            const Radius.circular(8),
          ),
          Paint()..color = p.type.accentColor,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: p.type.displayName,
            style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: orbSize);
        tp.paint(canvas, Offset(p.x - tp.width / 2, p.y - tp.height / 2));
      }
    }
  }

  void _drawEnemies(Canvas canvas) {
    for (final e in enemies) {
      if (!e.active || e.pendingRespawn) continue;

      if (e.exploding) {
        _drawExplosion(canvas, e.x, e.y, e.explosionFrame, e.renderSize * 0.9);
        continue;
      }

      final img = enemyImages[e.tier];
      if (img == null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(e.x, e.y),
                width: e.renderSize,
                height: e.renderSize),
            const Radius.circular(4),
          ),
          Paint()..color = kEnemyConfigs[e.tier]!.placeholderColor,
        );
        // Amber border = standard, red = elite
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(e.x, e.y),
                width: e.renderSize + 2,
                height: e.renderSize + 2),
            const Radius.circular(5),
          ),
          Paint()
            ..color = e.isElite
                ? const Color(0xFFE24B4A)
                : const Color(0xFFEF9F27)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        final src = Rect.fromLTWH(
            0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = Rect.fromCenter(
            center: Offset(e.x, e.y),
            width: e.renderSize,
            height: e.renderSize);
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
        canvas.drawImageRect(img, src, dst, imgPaint);
        canvas.restore();
      }

      if (e.maxHp > 1) {
        _drawHpBar(canvas, e.x, e.y - e.renderSize / 2 - 5,
            e.hp, e.maxHp, e.renderSize * 0.8);
      }
    }
  }

  void _drawHpBar(Canvas canvas, double cx, double top,
      int hp, int maxHp, double barW) {
    final frac = (hp / maxHp).clamp(0.0, 1.0);
    final left = cx - barW / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barW, 3), const Radius.circular(2)),
      Paint()..color = const Color(0xFF333333),
    );
    if (frac > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, barW * frac, 3),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF44CC22),
      );
    }
  }

  void _drawBoss(Canvas canvas) {
    final cfg = kEnemyConfigs[EnemyTier.boss]!;

    if (bossExploding) {
      _drawExplosion(
          canvas, bossX, bossY, bossExplosionFrame, cfg.renderSize * 1.6);
      return;
    }
    final img = enemyImages[EnemyTier.boss];

    if (bossFlashing) {
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = Rect.fromCenter(
            center: Offset(bossX, bossY),
            width: cfg.renderSize,
            height: cfg.renderSize);
        canvas.save();
        canvas.translate(bossX, bossY);
        canvas.rotate(pi);
        canvas.translate(-bossX, -bossY);
        canvas.drawImageRect(img, src, dst, Paint()
          ..colorFilter = const ColorFilter.matrix([
            1, 0, 0, 0, 255,
            0, 1, 0, 0, 255,
            0, 0, 1, 0, 255,
            0, 0, 0, 1, 0,
          ]));
        canvas.restore();
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(bossX, bossY),
                width: cfg.renderSize,
                height: cfg.renderSize),
            const Radius.circular(6),
          ),
          Paint()..color = Colors.white,
        );
      }
      return;
    }

    if (img == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(bossX, bossY),
              width: cfg.renderSize,
              height: cfg.renderSize),
          const Radius.circular(6),
        ),
        Paint()..color = cfg.placeholderColor,
      );
      canvas.drawCircle(
        Offset(bossX, bossY),
        cfg.renderSize * 0.6,
        Paint()
          ..color = const Color(0x44FF2222)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    } else {
      final src = Rect.fromLTWH(
          0, 0, img.width.toDouble(), img.height.toDouble());
      final dst = Rect.fromCenter(
          center: Offset(bossX, bossY),
          width: cfg.renderSize,
          height: cfg.renderSize);
      canvas.save();
      canvas.translate(bossX, bossY);
      canvas.rotate(pi);
      canvas.translate(-bossX, -bossY);
      canvas.drawImageRect(img, src, dst, Paint());
      canvas.restore();
    }
  }

  void _drawExplosion(
      Canvas canvas, double cx, double cy, int frame, double size) {
    if (explosionSheet == null) return;
    final idx = frame.clamp(0, 15);
    final col = idx % 4;
    final row = idx ~/ 4;
    const fs  = 128.0;
    final src = Rect.fromLTWH(col * fs, row * fs, fs, fs);
    final dst =
        Rect.fromCenter(center: Offset(cx, cy), width: size, height: size);
    canvas.drawImageRect(explosionSheet!, src, dst, Paint());
  }

  void _drawPlayer(Canvas canvas) {
    // Jet rendered at 72×72; hitbox is 40×40 (handled in state)
    final img = jetImage!;
    final src = Rect.fromLTWH(
        0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = Rect.fromCenter(
        center: Offset(playerX, playerY), width: 72, height: 72);
    // Ghost mode: 50% opacity to signal invulnerability
    final paint = ghostActive
        ? (Paint()..color = Colors.white.withValues(alpha: 0.50))
        : Paint();
    canvas.drawImageRect(img, src, dst, paint);
  }

  void _drawFloatTexts(Canvas canvas) {
    for (final t in floatTexts) {
      // Hold full opacity for the first holdFraction of the life, then
      // ease-out fade to 0 across the remainder. Default holdFraction is
      // 0.0 which gives the old linear-fade behaviour.
      final progress = t.frame / t.life;
      final double alpha;
      if (progress <= t.holdFraction) {
        alpha = 1.0;
      } else {
        final fadeP = (progress - t.holdFraction) / (1.0 - t.holdFraction);
        alpha = (1.0 - fadeP).clamp(0.0, 1.0);
      }

      // When glowBlur > 0, render a hard dark outline (4 zero-blur shadows
      // at unit offsets) plus a soft black drop shadow. This guarantees
      // legibility against the busy biome backdrop — a same-color halo
      // would just blur the letterforms.
      final outlineAlpha = alpha * 0.95;
      final style = TextStyle(
        color: t.color.withValues(alpha: alpha),
        fontSize: t.fontSize,
        fontWeight: t.bold ? FontWeight.bold : FontWeight.normal,
        shadows: t.glowBlur > 0
            ? [
                Shadow(color: Colors.black.withValues(alpha: outlineAlpha), offset: const Offset(-1.2, -1.2)),
                Shadow(color: Colors.black.withValues(alpha: outlineAlpha), offset: const Offset( 1.2, -1.2)),
                Shadow(color: Colors.black.withValues(alpha: outlineAlpha), offset: const Offset(-1.2,  1.2)),
                Shadow(color: Colors.black.withValues(alpha: outlineAlpha), offset: const Offset( 1.2,  1.2)),
                Shadow(color: Colors.black.withValues(alpha: alpha * 0.55), blurRadius: t.glowBlur),
              ]
            : null,
      );
      final tp = TextPainter(
        text: TextSpan(text: t.text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(t.x - tp.width / 2, t.y));
    }
  }

  @override
  bool shouldRepaint(_GamePainter old) =>
      old.frame != frame || old.phase != phase || old.ghostActive != ghostActive;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tray slot data
// ─────────────────────────────────────────────────────────────────────────────

class _TraySlot {
  int count;
  bool isActive = false;
  _TraySlot({required this.count});
}

// ─────────────────────────────────────────────────────────────────────────────
// Power-up tray widget
// ─────────────────────────────────────────────────────────────────────────────

class _PowerUpTray extends StatefulWidget {
  final Map<PowerUpType, ui.Image?> slotImages;
  final void Function(PowerUpType) onActivate;

  const _PowerUpTray({
    super.key,
    required this.slotImages,
    required this.onActivate,
  });

  @override
  State<_PowerUpTray> createState() => _PowerUpTrayState();
}

class _PowerUpTrayState extends State<_PowerUpTray>
    with TickerProviderStateMixin {

  late final Map<PowerUpType, _TraySlot> _slots;
  final Map<PowerUpType, AnimationController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _slots = {
      for (final type in kCollectibleSlots) type: _TraySlot(count: 0),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  // Called by parent when a collectible orb is picked up
  void addCharge(PowerUpType type) {
    if (!mounted) return;
    if (_slots[type]!.count >= 3) return;
    setState(() => _slots[type]!.count++);
  }

  // Called by parent on full game reset
  void reset() {
    if (!mounted) return;
    for (final c in _controllers.values) { c.dispose(); }
    _controllers.clear();
    setState(() {
      for (final type in kCollectibleSlots) {
        _slots[type]!.count = 0;
        _slots[type]!.isActive = false;
      }
    });
  }

  void _startController(PowerUpType type, double from) {
    final ms = type.durationFrames * 1000 ~/ 60;
    final ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _onTimerComplete(type);
    });
    _controllers[type] = ctrl;
    ctrl.forward(from: from);
  }

  void _onTapSlot(PowerUpType type) {
    final slot = _slots[type]!;
    if (slot.count == 0 || slot.isActive) return;
    setState(() {
      slot.count--;
      slot.isActive = true;
    });
    widget.onActivate(type);
    _controllers[type]?.dispose();
    _controllers.remove(type);
    _startController(type, 0.0);
  }

  void _onTimerComplete(PowerUpType type) {
    if (!mounted) return;
    _controllers[type]?.dispose();
    _controllers.remove(type);
    setState(() => _slots[type]!.isActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: kCollectibleSlots.map(_buildSlot).toList(),
    );
  }

  Widget _buildSlot(PowerUpType type) {
    final slot   = _slots[type]!;
    final isEmpty = slot.count == 0 && !slot.isActive;

    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Opacity(
          opacity: 0.28,
          child: SizedBox(
            width: 52, height: 52,
            child: CustomPaint(
              painter: const _DashedBorderPainter(
                color: Color(0x3396C459),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF20F230F),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isActive  = slot.isActive;
    final bgColor   = isActive
        ? const Color(0xE61B4A0A)
        : const Color(0xF20F230F);
    final borderColor = isActive
        ? const Color(0xFF97C459)
        : const Color(0x4097C459);
    final borderWidth = isActive ? 1.5 : 1.0;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: isActive ? null : () => _onTapSlot(type),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Stack(
                children: [
                  Center(child: _buildIcon(type)),
                  if (isActive && _controllers.containsKey(type))
                    _buildTimerBar(type),
                ],
              ),
            ),
            if (slot.count >= 2)
              Positioned(
                top: -5, right: -5,
                child: _buildBadge(slot.count),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(PowerUpType type) {
    final img = widget.slotImages[type];
    if (img != null) {
      return SizedBox(
        width: 34, height: 34,
        child: RawImage(image: img, fit: BoxFit.contain),
      );
    }
    return Container(
      width: 34, height: 34,
      color: type.accentColor,
      alignment: Alignment.center,
      child: Text(
        type.displayName,
        style: const TextStyle(
          color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTimerBar(PowerUpType type) {
    return AnimatedBuilder(
      animation: _controllers[type]!,
      builder: (context, _) {
        final remaining = (1.0 - _controllers[type]!.value).clamp(0.0, 1.0);
        return Positioned(
          bottom: 0, left: 0, right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(9),
              bottomRight: Radius.circular(9),
            ),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(height: 4, color: Colors.white.withValues(alpha: 0.1)),
                  FractionallySizedBox(
                    widthFactor: remaining,
                    child: Container(height: 4, color: const Color(0xFF97C459)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(int count) {
    final label  = count >= 10 ? '9+' : '$count';
    final isPill = count >= 10;
    return Container(
      width:   isPill ? null : 16,
      height:  16,
      padding: isPill ? const EdgeInsets.symmetric(horizontal: 4) : null,
      decoration: BoxDecoration(
        color: const Color(0xFFEF9F27),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0a1a0a), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF412402),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed border painter (used for EMPTY slot state)
// ─────────────────────────────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  static const double _stroke = 1.0;
  static const double _radius = 10.0;
  static const double _dash   = 4.0;
  static const double _gap    = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(_stroke / 2, _stroke / 2,
            size.width - _stroke, size.height - _stroke),
        const Radius.circular(_radius),
      ));

    canvas.drawPath(_dashPath(path), paint);
  }

  Path _dashPath(Path source) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? _dash : _gap;
        if (draw) {
          result.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
