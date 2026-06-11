import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../config/enemy_glow_config.dart';

/// Draws a soft, shape-following glow behind an enemy sprite.
/// Call this BEFORE drawing the enemy sprite itself.
///
/// [sprite]          the enemy's loaded ui.Image
/// [dst]             the exact destination rect the sprite is drawn into
/// [cfg]             cached EnemyGlowConfig
/// [world]           current world index (1..6) -> picks the glow colour
/// [elapsedSeconds]  monotonic animation time (game clock, or frameCount/60)
/// [phaseOffset]     per-enemy phase so they don't pulse in unison (seconds)
void paintEnemyGlow(
  Canvas canvas,
  ui.Image sprite,
  Rect dst,
  EnemyGlowConfig cfg,
  int world,
  double elapsedSeconds, {
  double phaseOffset = 0.0,
}) {
  if (!cfg.enabled || cfg.baseOpacity <= 0.0) return;

  final double periodSec = (cfg.pulsePeriodMs / 1000.0);
  final double pulse = periodSec <= 0
      ? 0.0
      : cfg.pulseAmplitude *
          math.sin(2 * math.pi * (elapsedSeconds + phaseOffset) / periodSec);
  final double opacity = (cfg.baseOpacity + pulse).clamp(0.0, 1.0);
  if (opacity <= 0.0) return;

  final Color glow = cfg.colorForWorld(world).withValues(alpha: opacity);

  final Paint glowPaint = Paint()
    ..colorFilter = ColorFilter.mode(glow, BlendMode.srcIn)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, cfg.blurSigma)
    ..isAntiAlias = true;

  final Rect src =
      Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble());
  canvas.drawImageRect(sprite, src, dst, glowPaint);
}
