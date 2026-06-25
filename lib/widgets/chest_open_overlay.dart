import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../economy/state/economy_state.dart';
import '../shared/theme/app_colors.dart';
import '../shared/widgets/currency_anchors.dart';

/// Full-screen chest-reward presentation.
///
/// Surfaced whenever the player wins or buys a chest. The flow:
///   1. Screen darkens; the chest drops in from the top and settles in
///      the centre with a little bounce.
///   2. The chest wiggles invitingly and a "Tap to open" prompt appears
///      underneath it.
///   3. On tap, the close→open1..4 frame sequence plays.
///   4. Once open, each tap hops one currency out to a centred row; the
///      final tap flies them all to the top-right holder.
///
/// The [coins]/[gems] passed in have *already* been credited to the wallet
/// — the holder value is withheld (display-lag) until the flying coins
/// land, at which point [EconomyState.releaseCelebration] lets it tick up.
class ChestOpenOverlay extends StatelessWidget {
  final int coins;
  final int gems;

  const ChestOpenOverlay({super.key, this.coins = 0, this.gems = 0});

  /// Pushes the overlay over whatever screen is currently showing. The
  /// barrier itself is fully opaque-ish black so the screen behind reads
  /// as "darkened".
  static Future<void> show(
    BuildContext context, {
    required int coins,
    required int gems,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Chest open',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => ChestOpenOverlay(coins: coins, gems: gems),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: _ChestOpenView(coins: coins, gems: gems),
    );
  }
}

/// One reward to fly. [icon] is an asset path, [amount] the number drawn
/// beneath it, [isCoin] picks which holder it flies to.
class _Reward {
  final String icon;
  final int amount;
  final bool isCoin;
  const _Reward(this.icon, this.amount, this.isCoin);
}

/// Builds the (≤2) reward chips that fly, from a coins/gems grant.
List<_Reward> _rewardsFrom(int coins, int gems) => <_Reward>[
      if (coins > 0) _Reward('assets/ui/icon_coin.png', coins, true),
      if (gems > 0) _Reward('assets/ui/icon_gem.png', gems, false),
    ];

/// On-screen target for a flying currency: the real holder centre if a top
/// bar has reported it, else a geometric estimate near the top-right.
Offset _holderTarget({
  required bool isCoin,
  required Size size,
  required double topPad,
}) {
  final anchor = isCoin ? CurrencyAnchors.coin : CurrencyAnchors.gem;
  if (anchor != null) return anchor;
  return Offset(
    size.width - (isCoin ? _kCoinHolderRightInset : _kGemHolderRightInset),
    topPad + _kHolderTopInset,
  );
}

/// Computed transform for a currency mid-flight from [rest] to [target].
class _FlyState {
  final Offset pos;
  final double scale;
  final double opacity;
  const _FlyState(this.pos, this.scale, this.opacity);
}

/// Shared fly motion (used by the chest collect *and* the plain fly
/// overlay): rest, wind up away from the vault, then fly in while shrinking
/// to 50% and snapping transparent on arrival. [v] is 0..1 fly progress.
_FlyState _computeFly({
  required double v,
  required Offset rest,
  required Offset target,
}) {
  final toVault = target - rest;
  final dist = toVault.distance;
  final dir = dist == 0 ? Offset.zero : toVault / dist;
  final antiPoint = rest - dir * _kAnticipationPx;

  const total = _kHoldFrames + _kAntiFrames + _kFlightFrames;
  final f = v * total;

  if (f <= _kHoldFrames) {
    return _FlyState(rest, 1, 1);
  }
  if (f <= _kHoldFrames + _kAntiFrames) {
    final local = (f - _kHoldFrames) / _kAntiFrames;
    return _FlyState(
      Offset.lerp(rest, antiPoint, Curves.easeOut.transform(local))!,
      1,
      1,
    );
  }
  final local =
      ((f - _kHoldFrames - _kAntiFrames) / _kFlightFrames).clamp(0.0, 1.0);
  final pos = Offset.lerp(antiPoint, target, Curves.easeIn.transform(local))!;
  final scale = _lerp(1.0, 0.5, local);
  var opacity = 1.0;
  const fadeStart = (_kFlightFrames - 1) / _kFlightFrames;
  if (local > fadeStart) {
    opacity = (1 - (local - fadeStart) / (1 - fadeStart)).clamp(0.0, 1.0);
  }
  return _FlyState(pos, scale, opacity);
}

/// Total duration of one fly animation.
Duration _flyDuration() => Duration(
      milliseconds:
          (1000 * (_kHoldFrames + _kAntiFrames + _kFlightFrames) / _kFlyFps)
              .round(),
    );

/// Chest frame sequence, in play order.
const _kChestFrames = <String>[
  'assets/animations/chest/basic_chest_close.png',
  'assets/animations/chest/basic_chest_open1.png',
  'assets/animations/chest/basic_chest_open2.png',
  'assets/animations/chest/basic_chest_open3.png',
  'assets/animations/chest/basic_chest_open4.png',
];

// ---------------------------------------------------------------------------
// Fly-to-vault motion for collected rewards (test values — tune freely).
//
// The reward appears at centre (where it leaves the chest), rests in place,
// winds up a little *away* from the vault, then flies to the top-right
// currency holder while shrinking, and snaps invisible as it lands. Frame
// counts below are interpreted at [_kFlyFps].
// ---------------------------------------------------------------------------
const int _kFlyFps = 30;
const int _kHoldFrames = 5; // rest in place after appearing
const int _kAntiFrames = 3; // wind-up opposite the vault (ease-out)
const int _kFlightFrames = 10; // travel to the vault (ease-in at the start)
const double _kAnticipationPx = 30; // "5 steps" backward from the vault

// Reveal hop: each currency leaps out of the chest and settles into a
// centred row. The final tap then flies the whole row to the holders.
const Duration _kJumpDuration = Duration(milliseconds: 450);
const double _kRestRowAboveChest = 0.55; // row height above chest centre (×chestSize)

// Approximate screen anchors for the top-right currency holder: inset from
// the right edge, just below the safe-area top. Coins sit left of gems.
const double _kHolderTopInset = 22;
const double _kCoinHolderRightInset = 120;
const double _kGemHolderRightInset = 40;

enum _Phase { dropping, idle, opening, opened }

class _ChestOpenView extends StatefulWidget {
  final int coins;
  final int gems;
  const _ChestOpenView({required this.coins, required this.gems});

  @override
  State<_ChestOpenView> createState() => _ChestOpenViewState();
}

class _ChestOpenViewState extends State<_ChestOpenView>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.dropping;

  /// Wallet reference captured up-front so the celebration can be released
  /// safely (incl. from [dispose] if the overlay is torn down early).
  EconomyState? _economy;
  bool _released = false;
  late final List<_Reward> _rewards = _rewardsFrom(widget.coins, widget.gems);

  /// Drives the drop-from-top entrance (0 = off-screen top, 1 = settled).
  late final AnimationController _drop;

  /// One wiggle burst while idle. Plays, then pauses 0.5s, then replays.
  late final AnimationController _wiggle;

  /// Drives the close→open frame sequence. Its value maps onto the frame
  /// index while [_phase] is opening.
  late final AnimationController _open;

  /// Fade-in for the "Tap to open" prompt.
  late final AnimationController _prompt;

  /// Continuous loop driving the light beams (rotation + travelling light)
  /// once the chest is open enough to show its glow.
  late final AnimationController _glow;

  /// One-shot fade-in for the glow intensity as the lid clears.
  late final AnimationController _glowIn;

  int _frame = 0;
  int _rewardsRevealed = 0;
  bool _glowStarted = false;
  bool _flying = false;
  final List<_RewardPop> _pops = [];

  /// The glow is shown from [basic_chest_open3] onward (frame index 3) and
  /// stays up through the opened state.
  bool get _glowActive =>
      _phase == _Phase.opened ||
      (_phase == _Phase.opening && _frame >= 3);

  @override
  void initState() {
    super.initState();

    _drop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _phase = _Phase.idle);
          _wiggle.forward(from: 0);
          _prompt.forward();
        }
      });

    // One wiggle burst is ~466ms (2× faster than the previous 933ms),
    // followed by a 0.5s rest before the next burst — see the status
    // listener below.
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 466),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && _phase == _Phase.idle) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _phase == _Phase.idle) _wiggle.forward(from: 0);
          });
        }
      });

    _prompt = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _open = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 110 * (_kChestFrames.length - 1)),
    )
      ..addListener(() {
        final idx = (_open.value * (_kChestFrames.length - 1))
            .round()
            .clamp(0, _kChestFrames.length - 1);
        if (idx != _frame) setState(() => _frame = idx);
        // Bloom the glow in the moment the lid reaches open3.
        if (idx >= 3 && !_glowStarted) {
          _glowStarted = true;
          _glow.repeat();
          _glowIn.forward();
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _phase = _Phase.opened);
        }
      });

    _drop.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _economy ??= context.read<EconomyState>();
  }

  /// Lets the withheld holder value tick up. Safe to call more than once.
  void _release() {
    if (_released) return;
    _released = true;
    _economy?.releaseCelebration(coins: widget.coins, gems: widget.gems);
  }

  @override
  void dispose() {
    // Guarantee the holder catches up even if the overlay is dismissed
    // before the coins finish flying.
    _release();
    _drop.dispose();
    _wiggle.dispose();
    _open.dispose();
    _prompt.dispose();
    _glow.dispose();
    _glowIn.dispose();
    for (final p in _pops) {
      p.jump.dispose();
      p.fly?.dispose();
    }
    super.dispose();
  }

  void _onTap() {
    switch (_phase) {
      case _Phase.dropping:
        // Let the entrance finish on its own; ignore early taps.
        break;
      case _Phase.idle:
        _wiggle.stop();
        _prompt.reverse();
        setState(() => _phase = _Phase.opening);
        _open.forward(from: 0);
        break;
      case _Phase.opening:
        // Mid-open: ignore.
        break;
      case _Phase.opened:
        if (_rewardsRevealed < _rewards.length) {
          // Each tap hops one currency out to the centred row.
          _revealReward(_rewards[_rewardsRevealed], _rewardsRevealed);
          setState(() => _rewardsRevealed++);
        } else if (_flying) {
          // Mid-flight: ignore (auto-closes when the coins land).
        } else if (_pops.isNotEmpty) {
          // All currencies are centred — the last tap flies them home.
          _flyAll();
        } else {
          // Nothing to collect (e.g. a jet-only chest) — just close.
          Navigator.of(context).pop();
        }
        break;
    }
  }

  /// Hops one currency out of the chest into the centred row.
  void _revealReward(_Reward reward, int slot) {
    final jump = AnimationController(vsync: this, duration: _kJumpDuration);
    final pop = _RewardPop(reward: reward, slot: slot, jump: jump);
    _pops.add(pop);
    jump.forward();
    setState(() {});
  }

  /// Flies every centred currency to its holder, then closes the overlay
  /// once the last one lands.
  void _flyAll() {
    final flyDuration = _flyDuration();
    setState(() => _flying = true);
    for (final pop in _pops) {
      pop.fly = AnimationController(vsync: this, duration: flyDuration)
        ..forward();
    }
    // When the last currency lands, let the holder tick up and close.
    _pops.last.fly!.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _release();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    // Chest art roughly square; size it to a comfortable share of width.
    final chestSize = math.min(size.width * 0.62, 320.0);
    final centerY = size.height * 0.5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Stack(
        children: [
          // Light beams behind the chest, from open3 onward.
          if (_glowActive)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_glow, _glowIn]),
                builder: (_, __) => CustomPaint(
                  painter: _GlowPainter(
                    center: Offset(
                        size.width / 2, centerY - chestSize * 0.12),
                    travel: _glow.value,
                    intensity: Curves.easeOut.transform(_glowIn.value),
                    radius: chestSize * 1.05,
                  ),
                ),
              ),
            ),

          // The chest itself.
          AnimatedBuilder(
            animation: Listenable.merge([_drop, _wiggle, _open]),
            builder: (_, __) {
              final dropT = Curves.easeOutBack.transform(_drop.value);
              // Start fully above the screen, settle at centre.
              final top = _lerp(
                -chestSize,
                centerY - chestSize / 2,
                dropT,
              );
              final wiggleAngle = _phase == _Phase.idle
                  ? math.sin(_wiggle.value * math.pi * 2) * 0.06
                  : 0.0;
              return Positioned(
                left: (size.width - chestSize) / 2,
                top: top,
                width: chestSize,
                height: chestSize,
                child: Transform.rotate(
                  angle: wiggleAngle,
                  child: Image.asset(
                    _kChestFrames[_frame],
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              );
            },
          ),

          // Currencies: hop to a centred row, then fly to the holders.
          for (final pop in _pops)
            AnimatedBuilder(
              animation: Listenable.merge([pop.jump, pop.fly]),
              builder: (_, __) =>
                  _buildRewardPop(pop, size, centerY, chestSize, topPad),
            ),

          // "Tap to open" prompt under the chest.
          if (_phase == _Phase.idle)
            Positioned(
              left: 0,
              right: 0,
              top: centerY + chestSize / 2 + 16,
              child: FadeTransition(
                opacity: _prompt,
                child: const _PulsingPrompt(text: 'Tap to open'),
              ),
            ),

          // Hint once open: reveal each currency, then collect the row.
          if (_phase == _Phase.opened && !_flying)
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: Center(
                child: Text(
                  _rewardsRevealed < _rewards.length
                      ? 'Tap to reveal reward'
                      : 'Tap to collect',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRewardPop(
    _RewardPop pop,
    Size size,
    double centerY,
    double chestSize,
    double topPad,
  ) {
    final iconSize = chestSize * 0.26;
    final isCoin = pop.reward.isCoin;
    final n = _rewards.length;

    // Where it leaves the chest, and its slot in the centred row.
    final chestMouth = Offset(size.width / 2, centerY - chestSize * 0.1);
    final rowSpacing = iconSize * 1.5;
    final rest = Offset(
      size.width / 2 + (pop.slot - (n - 1) / 2) * rowSpacing,
      centerY - chestSize * _kRestRowAboveChest,
    );

    Offset pos;
    double scale = 1.0;
    double opacity = 1.0;

    final fly = pop.fly;
    if (fly == null) {
      // Stage 1 — hop from the chest into the centred row, settling with a
      // little overshoot and an upward arc.
      final t = pop.jump.value;
      final eased = Curves.easeOutBack.transform(t);
      final arc = math.sin(t.clamp(0.0, 1.0) * math.pi) * (chestSize * 0.2);
      pos = Offset.lerp(chestMouth, rest, eased)! - Offset(0, arc);
    } else {
      // Stage 2 — fly from the row to the real holder.
      final target = _holderTarget(isCoin: isCoin, size: size, topPad: topPad);
      final s = _computeFly(v: fly.value, rest: rest, target: target);
      pos = s.pos;
      scale = s.scale;
      opacity = s.opacity;
    }

    return Positioned(
      left: pos.dx - iconSize / 2,
      top: pos.dy - iconSize / 2,
      width: iconSize,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                pop.reward.icon,
                width: iconSize,
                height: iconSize,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 2),
              Text(
                '${pop.reward.amount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 4),
                    Shadow(color: Colors.black, blurRadius: 8),
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

/// One currency in flight: [jump] hops it from the chest to its slot in the
/// centred row; [fly] (created on the final tap) carries it to the holder.
class _RewardPop {
  final _Reward reward;
  final int slot;
  final AnimationController jump;
  AnimationController? fly;
  _RewardPop({required this.reward, required this.slot, required this.jump});
}

// ===========================================================================
// Plain currency-fly overlay (no chest) — for challenge coin/gem wins and
// purchases. Currencies appear centred over the dark background with a
// "tap to collect" prompt; the tap flies them to the holders.
// ===========================================================================

/// Full-screen "tap to collect" overlay that flies coins/gems to the
/// top-right holder. Like [ChestOpenOverlay] the [coins]/[gems] are already
/// credited; the holder ticks up on landing via
/// [EconomyState.releaseCelebration].
class RewardFlyOverlay extends StatelessWidget {
  final int coins;
  final int gems;

  const RewardFlyOverlay({super.key, this.coins = 0, this.gems = 0});

  static Future<void> show(
    BuildContext context, {
    required int coins,
    required int gems,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Reward',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => RewardFlyOverlay(coins: coins, gems: gems),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: _RewardFlyView(coins: coins, gems: gems),
    );
  }
}

class _RewardFlyView extends StatefulWidget {
  final int coins;
  final int gems;
  const _RewardFlyView({required this.coins, required this.gems});

  @override
  State<_RewardFlyView> createState() => _RewardFlyViewState();
}

class _RewardFlyViewState extends State<_RewardFlyView>
    with TickerProviderStateMixin {
  EconomyState? _economy;
  bool _released = false;
  bool _flying = false;
  late final List<_Reward> _rewards = _rewardsFrom(widget.coins, widget.gems);
  late final List<AnimationController?> _flies =
      List<AnimationController?>.filled(_rewards.length, null);

  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _economy ??= context.read<EconomyState>();
  }

  void _release() {
    if (_released) return;
    _released = true;
    _economy?.releaseCelebration(coins: widget.coins, gems: widget.gems);
  }

  @override
  void dispose() {
    _release();
    _appear.dispose();
    for (final c in _flies) {
      c?.dispose();
    }
    super.dispose();
  }

  void _onTap() {
    if (_flying) return;
    if (_rewards.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final flyDuration = _flyDuration();
    setState(() => _flying = true);
    for (var i = 0; i < _flies.length; i++) {
      _flies[i] = AnimationController(vsync: this, duration: flyDuration)
        ..forward();
    }
    _flies.last!.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _release();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final iconSize = math.min(size.width * 0.2, 88.0);
    final n = _rewards.length;
    final rowSpacing = iconSize * 1.6;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Stack(
        children: [
          for (var i = 0; i < n; i++)
            AnimatedBuilder(
              animation: Listenable.merge([_appear, _flies[i]]),
              builder: (_, __) => _buildItem(
                i, size, topPad, iconSize, rowSpacing, n),
            ),
          if (!_flying)
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: Center(
                child: _PulsingPrompt(
                  text: n == 0 ? 'Tap to close' : 'Tap to collect',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(
    int i,
    Size size,
    double topPad,
    double iconSize,
    double rowSpacing,
    int n,
  ) {
    final reward = _rewards[i];
    final rest = Offset(
      size.width / 2 + (i - (n - 1) / 2) * rowSpacing,
      size.height * 0.5,
    );

    Offset pos;
    double scale;
    double opacity;
    final fly = _flies[i];
    if (fly == null) {
      // Pop in at centre.
      pos = rest;
      scale = Curves.easeOutBack.transform(_appear.value);
      opacity = _appear.value.clamp(0.0, 1.0);
    } else {
      final target =
          _holderTarget(isCoin: reward.isCoin, size: size, topPad: topPad);
      final s = _computeFly(v: fly.value, rest: rest, target: target);
      pos = s.pos;
      scale = s.scale;
      opacity = s.opacity;
    }

    return Positioned(
      left: pos.dx - iconSize / 2,
      top: pos.dy - iconSize / 2,
      width: iconSize,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                reward.icon,
                width: iconSize,
                height: iconSize,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 2),
              Text(
                '${reward.amount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 4),
                    Shadow(color: Colors.black, blurRadius: 8),
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

/// Gently pulsing "Tap to open" call-to-action.
class _PulsingPrompt extends StatefulWidget {
  final String text;
  const _PulsingPrompt({required this.text});

  @override
  State<_PulsingPrompt> createState() => _PulsingPromptState();
}

class _PulsingPromptState extends State<_PulsingPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.scale(
        scale: _lerp(0.94, 1.06, _c.value),
        child: child,
      ),
      child: Center(
        child: Text(
          widget.text,
          style: const TextStyle(
            color: AppColors.amberLight,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 6),
              Shadow(color: AppColors.amberDark, blurRadius: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated light beams + travelling light radiating from the open chest.
///
/// [travel] loops 0→1 and drives a gentle rotation of the beam fan plus a
/// bright pulse of light that runs outward along each beam — the beams are
/// phase-staggered so the light appears to flow out in sequence.
/// [intensity] fades the whole effect in as the lid clears.
class _GlowPainter extends CustomPainter {
  final Offset center;
  final double travel;
  final double intensity;
  final double radius;

  _GlowPainter({
    required this.center,
    required this.travel,
    required this.intensity,
    required this.radius,
  });

  static const int _beams = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final a = intensity.clamp(0.0, 1.0);
    if (a <= 0.001) return;

    // The whole glow breathes gently.
    final breathe = 0.96 + 0.04 * math.sin(travel * math.pi * 2);
    final r = radius * breathe;

    // --- Core bloom at the chest mouth ---
    final core = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95 * a),
          AppColors.amberLight.withValues(alpha: 0.5 * a),
          AppColors.amber.withValues(alpha: 0.12 * a),
          AppColors.amber.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.22, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, core);

    final rot = travel * (2 * math.pi / _beams);
    for (var i = 0; i < _beams; i++) {
      final ang = rot + i * (2 * math.pi / _beams);
      _drawBeam(canvas, ang, r, a);
      _drawTravellingLight(canvas, ang, r, a, i);
    }
  }

  /// A soft static wedge for beam [ang], bright at the mouth and fading to
  /// nothing at the rim.
  void _drawBeam(Canvas canvas, double ang, double r, double a) {
    final dir = Offset(math.cos(ang), math.sin(ang));
    final perp = Offset(-dir.dy, dir.dx);
    final tip = center + dir * r;
    final halfW = r * 0.05;

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(tip.dx - perp.dx * halfW, tip.dy - perp.dy * halfW)
      ..lineTo(tip.dx + perp.dx * halfW, tip.dy + perp.dy * halfW)
      ..close();

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        center,
        tip,
        [
          AppColors.amberLight.withValues(alpha: 0.35 * a),
          AppColors.amber.withValues(alpha: 0.12 * a),
          AppColors.amber.withValues(alpha: 0.0),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawPath(path, paint);
  }

  /// A bright blob that travels outward along beam [ang], phase-shifted by
  /// the beam index [i] so successive beams light up in turn.
  void _drawTravellingLight(
      Canvas canvas, double ang, double r, double a, int i) {
    final dir = Offset(math.cos(ang), math.sin(ang));
    final p = (travel + i / _beams) % 1.0;
    final env = math.sin(p * math.pi); // dim at both ends, bright mid-run
    if (env <= 0.01) return;
    final pos = center + dir * (p * r);
    final blobR = r * 0.13;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9 * env * a),
          AppColors.amberLight.withValues(alpha: 0.35 * env * a),
          AppColors.amber.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: pos, radius: blobR));
    canvas.drawCircle(pos, blobR, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.travel != travel ||
      old.intensity != intensity ||
      old.center != center ||
      old.radius != radius;
}

/// Local linear-interpolation helper for scalar tweens.
double _lerp(num a, num b, double t) => a + (b - a) * t;
