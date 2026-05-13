import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/ace_dialogue_catalog.dart';

/// Animated Ace portrait sourced from `assets/ui/ace_spritesheet.png`
/// (1024×1024, 4×4 grid of 256×256 frames). Each [AceExpression] maps to
/// a row in the sheet; the widget cycles through that row's 4 frames in
/// a continuous loop so the tutorial dialog portrait feels alive.
class AceAnimatedPortrait extends StatefulWidget {
  static const String spritesheetAsset = 'assets/ui/ace_spritesheet.png';
  static const int _cols = 4;
  static const double _frameSize = 256;

  /// Mood the portrait should reflect — selects which row of the sheet
  /// is cycled.
  final AceExpression expression;

  /// Frames per second for the cycle. ~5–6 fps reads as "breathing /
  /// shifting weight" rather than twitchy.
  final double fps;

  const AceAnimatedPortrait({
    super.key,
    required this.expression,
    this.fps = 5,
  });

  @override
  State<AceAnimatedPortrait> createState() => _AceAnimatedPortraitState();
}

class _AceAnimatedPortraitState extends State<AceAnimatedPortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.Image? _sheet;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            (AceAnimatedPortrait._cols * 1000 / widget.fps).round(),
      ),
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final image = await _AceSpriteCache.load();
      if (!mounted) return;
      setState(() => _sheet = image);
      _controller.repeat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _row {
    switch (widget.expression) {
      case AceExpression.smirk:
        return 0;
      case AceExpression.concerned:
        return 1;
      case AceExpression.excited:
        return 2;
      case AceExpression.cheer:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    if (sheet == null || _loadError != null) {
      return AssetPlaceholder(
        color: AppColors.amber,
        label: 'ace_${widget.expression.name}',
        borderRadius: 8,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final col = (_controller.value * AceAnimatedPortrait._cols)
            .floor()
            .clamp(0, AceAnimatedPortrait._cols - 1);
        return CustomPaint(
          painter: _SpriteFramePainter(
            sheet: sheet,
            col: col,
            row: _row,
          ),
        );
      },
    );
  }
}

class _SpriteFramePainter extends CustomPainter {
  final ui.Image sheet;
  final int col;
  final int row;

  _SpriteFramePainter({
    required this.sheet,
    required this.col,
    required this.row,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      col * AceAnimatedPortrait._frameSize,
      row * AceAnimatedPortrait._frameSize,
      AceAnimatedPortrait._frameSize,
      AceAnimatedPortrait._frameSize,
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(sheet, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _SpriteFramePainter old) =>
      old.col != col || old.row != row || old.sheet != sheet;
}

/// Decodes the spritesheet once per app session and hands the same
/// [ui.Image] to every portrait instance.
class _AceSpriteCache {
  _AceSpriteCache._();

  static Future<ui.Image>? _future;

  static Future<ui.Image> load() {
    return _future ??= _decode();
  }

  static Future<ui.Image> _decode() async {
    final data =
        await rootBundle.load(AceAnimatedPortrait.spritesheetAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
