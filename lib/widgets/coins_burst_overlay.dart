import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Full-screen coin-burst test overlay.
///
/// Replays the motion from a Lottie/Bodymovin export (the uploaded
/// `Arrows.json`, copied verbatim to
/// `assets/animations/coins_burst_motion.json`) but swaps each arrow
/// glyph for the game coin sprite. Only the per-particle position and
/// opacity keyframes are read from the JSON — the rendered glyph is the
/// coin, so the *motion* is preserved while the *art* changes.
///
/// Surfaced from the dev tools sheet. Dims the screen so the background
/// is barely visible, then loops the burst until tapped.
class CoinsBurstOverlay extends StatelessWidget {
  const CoinsBurstOverlay({super.key});

  /// Pushes the overlay as a dark, dismiss-on-tap dialog over whatever
  /// screen is currently showing.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Coins burst',
      // Barely-there background: 88% black so the screen behind is just
      // a hint of shape.
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const CoinsBurstOverlay(),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: const Stack(
          alignment: Alignment.center,
          children: [
            // The animation is sized to a square that fits the screen.
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.85,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _CoinsBurstView(
                    motionAsset:
                        'assets/animations/coins_burst_motion.json',
                    coinAsset: 'assets/ui/icon_coin.png',
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 48,
              child: Text(
                'tap anywhere to close',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinsBurstView extends StatefulWidget {
  final String motionAsset;
  final String coinAsset;

  const _CoinsBurstView({
    required this.motionAsset,
    required this.coinAsset,
  });

  @override
  State<_CoinsBurstView> createState() => _CoinsBurstViewState();
}

class _CoinsBurstViewState extends State<_CoinsBurstView>
    with SingleTickerProviderStateMixin {
  _Motion? _motion;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString(widget.motionAsset);
    final motion = _Motion.parse(jsonDecode(raw) as Map<String, dynamic>);
    if (!mounted) return;
    setState(() => _motion = motion);
    _controller.duration = Duration(
      milliseconds: (motion.durationFrames / motion.fps * 1000).round(),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motion;
    if (motion == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / motion.compWidth;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final frame = _controller.value * motion.durationFrames;
            return Stack(
              children: [
                for (final p in motion.particles)
                  _buildCoin(p, frame, scale),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCoin(_Particle particle, double frame, double scale) {
    final opacity = particle.opacityAt(frame).clamp(0.0, 1.0);
    if (opacity <= 0.001) return const SizedBox.shrink();
    final pos = particle.positionAt(frame);
    final size = particle.size * scale;
    return Positioned(
      left: pos.dx * scale - size / 2,
      top: pos.dy * scale - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(widget.coinAsset, filterQuality: FilterQuality.medium),
      ),
    );
  }
}

// =============================================================================
// Lottie motion parsing (specialised to the shape-group structure of the
// uploaded Arrows.json: a single shape layer whose children are groups,
// each with an animated `tr` transform). We pull each group's centroid +
// position keyframes + opacity keyframes and bake them into [_Particle]s.
// =============================================================================

class _Motion {
  final double compWidth;
  final double compHeight;
  final double fps;
  final double durationFrames;
  final List<_Particle> particles;

  _Motion({
    required this.compWidth,
    required this.compHeight,
    required this.fps,
    required this.durationFrames,
    required this.particles,
  });

  static _Motion parse(Map<String, dynamic> json) {
    final compWidth = (json['w'] as num).toDouble();
    final compHeight = (json['h'] as num).toDouble();
    final fps = (json['fr'] as num).toDouble();
    final op = (json['op'] as num).toDouble();
    final layers = json['layers'] as List<dynamic>;
    final particles = <_Particle>[];

    for (final layerRaw in layers) {
      final layer = layerRaw as Map<String, dynamic>;
      if (layer['ty'] != 4) continue; // shape layer only
      final ks = layer['ks'] as Map<String, dynamic>;
      final layerPos = _staticVec(ks['p']);
      final layerAnchor = _staticVec(ks['a']);
      final shapes = layer['shapes'] as List<dynamic>? ?? const [];
      for (final shapeRaw in shapes) {
        final group = shapeRaw as Map<String, dynamic>;
        if (group['ty'] != 'gr') continue;
        final items = group['it'] as List<dynamic>;
        Offset? centroid;
        Map<String, dynamic>? tr;
        for (final itemRaw in items) {
          final item = itemRaw as Map<String, dynamic>;
          final ty = item['ty'];
          if (ty == 'sh') {
            centroid = _shapeCentroid(item);
          } else if (ty == 'tr') {
            tr = item;
          }
        }
        if (tr == null) continue;
        particles.add(_Particle(
          centroid: centroid ?? Offset.zero,
          layerPos: layerPos,
          layerAnchor: layerAnchor,
          position: _Keyframed.fromProp(tr['p']),
          opacity: _Keyframed.fromProp(tr['o']),
        ));
      }
    }

    return _Motion(
      compWidth: compWidth,
      compHeight: compHeight,
      fps: fps,
      durationFrames: op,
      particles: particles,
    );
  }
}

class _Particle {
  final Offset centroid;
  final Offset layerPos;
  final Offset layerAnchor;
  final _Keyframed position;
  final _Keyframed opacity;

  /// Coin draw size in composition units. The source arrows span ~40 comp
  /// units; coins read a touch larger so the sprite is legible.
  final double size = 56;

  _Particle({
    required this.centroid,
    required this.layerPos,
    required this.layerAnchor,
    required this.position,
    required this.opacity,
  });

  /// Screen-space (composition-space) centre of the coin at [frame],
  /// composing the group transform with the parent layer transform.
  Offset positionAt(double frame) {
    final p = position.value(frame);
    final local = centroid + Offset(p[0], p[1]);
    return layerPos + (local - layerAnchor);
  }

  double opacityAt(double frame) => opacity.value(frame)[0] / 100.0;
}

/// A scalar- or vector-valued animated property, possibly static.
class _Keyframed {
  final bool animated;
  final List<double> staticValue;
  final List<_Keyframe> keyframes;

  _Keyframed.static(this.staticValue)
      : animated = false,
        keyframes = const [];

  _Keyframed.animated(this.keyframes)
      : animated = true,
        staticValue = const [];

  static _Keyframed fromProp(dynamic prop) {
    final map = prop as Map<String, dynamic>;
    final isAnimated = map['a'] == 1;
    if (!isAnimated) {
      return _Keyframed.static(_asList(map['k']));
    }
    final frames = (map['k'] as List<dynamic>)
        .map((e) => _Keyframe.parse(e as Map<String, dynamic>))
        .toList();
    return _Keyframed.animated(frames);
  }

  List<double> value(double frame) {
    if (!animated) return staticValue;
    if (keyframes.isEmpty) return const [0];
    if (frame <= keyframes.first.t) return keyframes.first.s;
    if (frame >= keyframes.last.t) return keyframes.last.s;
    for (var i = 0; i < keyframes.length - 1; i++) {
      final k0 = keyframes[i];
      final k1 = keyframes[i + 1];
      if (frame >= k0.t && frame < k1.t) {
        final localT = (frame - k0.t) / (k1.t - k0.t);
        final eased = _cubicBezier(localT, k0.ox, k0.oy, k0.ix, k0.iy);
        final out = <double>[];
        final n = math.min(k0.s.length, k1.s.length);
        for (var j = 0; j < n; j++) {
          out.add(k0.s[j] + (k1.s[j] - k0.s[j]) * eased);
        }
        return out;
      }
    }
    return keyframes.last.s;
  }
}

class _Keyframe {
  final double t;
  final List<double> s;
  final double ox; // out-tangent x of this keyframe's segment
  final double oy;
  final double ix; // in-tangent x of the next keyframe
  final double iy;

  _Keyframe({
    required this.t,
    required this.s,
    required this.ox,
    required this.oy,
    required this.ix,
    required this.iy,
  });

  static _Keyframe parse(Map<String, dynamic> map) {
    final i = map['i'] as Map<String, dynamic>?;
    final o = map['o'] as Map<String, dynamic>?;
    return _Keyframe(
      t: (map['t'] as num).toDouble(),
      s: _asList(map['s'] ?? const [0]),
      ox: o == null ? 0.167 : _firstNum(o['x']),
      oy: o == null ? 0.167 : _firstNum(o['y']),
      ix: i == null ? 0.833 : _firstNum(i['x']),
      iy: i == null ? 0.833 : _firstNum(i['y']),
    );
  }
}

// ------------------------------ helpers --------------------------------

List<double> _asList(dynamic v) {
  if (v is num) return [v.toDouble()];
  if (v is List) return v.map((e) => (e as num).toDouble()).toList();
  return const [0];
}

double _firstNum(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is List && v.isNotEmpty) return (v.first as num).toDouble();
  return 0;
}

Offset _staticVec(dynamic prop) {
  final k = (prop as Map<String, dynamic>)['k'];
  final list = _asList(k);
  return Offset(list[0], list.length > 1 ? list[1] : 0);
}

Offset _shapeCentroid(Map<String, dynamic> shape) {
  final ks = shape['ks'] as Map<String, dynamic>;
  final k = ks['k'] as Map<String, dynamic>;
  final verts = k['v'] as List<dynamic>;
  var sx = 0.0, sy = 0.0;
  for (final vRaw in verts) {
    final v = vRaw as List<dynamic>;
    sx += (v[0] as num).toDouble();
    sy += (v[1] as num).toDouble();
  }
  final n = verts.length;
  return n == 0 ? Offset.zero : Offset(sx / n, sy / n);
}

/// Cubic-bezier easing through (0,0),(x1,y1),(x2,y2),(1,1). Given the
/// normalised time [t] (the x axis), solve for the bezier parameter and
/// return the eased y. Matches Lottie/After-Effects keyframe interpolation.
double _cubicBezier(double t, double x1, double y1, double x2, double y2) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  double sampleX(double u) {
    final mu = 1 - u;
    return 3 * mu * mu * u * x1 + 3 * mu * u * u * x2 + u * u * u;
  }

  double sampleY(double u) {
    final mu = 1 - u;
    return 3 * mu * mu * u * y1 + 3 * mu * u * u * y2 + u * u * u;
  }

  // Bisection on u so sampleX(u) == t.
  var lo = 0.0, hi = 1.0, u = t;
  for (var i = 0; i < 24; i++) {
    u = (lo + hi) / 2;
    final x = sampleX(u);
    if ((x - t).abs() < 1e-5) break;
    if (x < t) {
      lo = u;
    } else {
      hi = u;
    }
  }
  return sampleY(u);
}
