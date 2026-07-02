import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_top_bar.dart';

/// Shared scaffold for the four end-of-run overlays: Pause, Mission
/// Failed, Stage Complete, Biome Complete.
///
/// These render INSIDE the game screen's existing Stack — the frozen
/// gameplay scene already paints below us, so this widget only adds the
/// chrome: optional colour wash, a darken layer, the shared top bar, an
/// optional star row, title + stats, an optional reward/unlock row, and
/// the button stack.
///
/// Render with:
/// ```dart
/// Stack(children: [
///   ...gameplay,
///   if (_phase == _Phase.paused) ResultOverlay(...),
/// ])
/// ```
class ResultOverlay extends StatelessWidget {
  /// Optional state colour wash painted between the gameplay (rendered by
  /// the caller below this widget) and the chrome.
  final ResultWash wash;

  /// Star count earned, 0..3. When null, the star row is hidden (Pause,
  /// Mission Failed). When 0..3, the row renders with that many filled.
  final int? stars;

  /// Title text. Use `\n` to split across two lines (e.g.
  /// `'STAGE 1\nCOMPLETE'`).
  final String title;

  /// Single-line stats subtitle (`'Wave 1/10 · 11 pts · 100% HP'`).
  /// Pass null to hide.
  final String? subtitle;

  /// Optional widget inserted between subtitle and buttons. Used for the
  /// Stage Complete reward row and the Biome Complete unlock row.
  final Widget? extraContent;

  /// Stack of action buttons, top → bottom. Use [AppButton] variants.
  final List<Widget> buttons;

  const ResultOverlay({
    super.key,
    required this.title,
    required this.buttons,
    this.wash = ResultWash.none,
    this.stars,
    this.subtitle,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (wash != ResultWash.none)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: _washColor(wash)),
            ),
          ),
        const Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: Color(0x66000000)),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              // In-game chrome — don't publish currency anchors, or the
              // bar's (different) position would mis-aim the post-clear
              // reward fly once the player is back on a menu screen.
              const AppTopBar.full(forceShowCoin: true, publishAnchor: false),
              const Spacer(),
              if (stars != null) ...[
                _StarsRow(filled: stars!),
                const SizedBox(height: 16),
              ],
              _Title(title: title),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD8E6C0),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (extraContent != null) ...[
                const SizedBox(height: 16),
                extraContent!,
              ],
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      buttons[i],
                    ],
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }

  Color _washColor(ResultWash w) {
    switch (w) {
      case ResultWash.red:
        return const Color(0xFFD23B3B).withValues(alpha: 0.55);
      case ResultWash.green:
        return AppColors.green.withValues(alpha: 0.45);
      case ResultWash.none:
        return Colors.transparent;
    }
  }
}

/// State-colour wash painted over the gameplay scene.
enum ResultWash {
  /// No wash — used for Pause.
  none,

  /// Crimson wash — used for Mission Failed.
  red,

  /// Green wash — used for Stage Complete + Biome Complete (success).
  green,
}

class _Title extends StatelessWidget {
  final String title;
  const _Title({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 36,
        fontWeight: FontWeight.w500,
        letterSpacing: 6,
        height: 1.15,
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  final int filled;
  const _StarsRow({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Icon(
            i < filled ? Icons.star : Icons.star_border,
            color: i < filled ? AppColors.amber : Colors.white,
            size: 36,
          ),
        ],
      ],
    );
  }
}
