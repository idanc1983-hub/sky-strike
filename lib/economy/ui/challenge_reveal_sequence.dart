import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../constants/ace_dialogue_catalog.dart';
import '../state/challenge_state.dart';

/// One-time Stage 3 challenge reveal cinematic (GDD §4.4). Cannot be
/// skipped on first show. Returns when the player taps LET'S GO.
///
/// The host opens this via [show] and awaits the future. On resolution
/// the host should mark the reveal flag (already done by
/// [EconomyState.markChallengeRevealed]) and start the first cycle.
class ChallengeRevealSequence extends StatefulWidget {
  final ChallengeType challengeType;

  const ChallengeRevealSequence({super.key, required this.challengeType});

  /// Convenience helper. Shows the sequence as a fullscreen dialog. The
  /// returned future resolves when the player taps LET'S GO.
  static Future<void> show(BuildContext context, ChallengeType type) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (_) => ChallengeRevealSequence(challengeType: type),
    );
  }

  @override
  State<ChallengeRevealSequence> createState() =>
      _ChallengeRevealSequenceState();
}

enum _RevealStage {
  initialPause, // 0-5s: nothing visible (dim overlay only)
  hudOverlay, // 5s: HUD frame slides up
  acePortrait, // 5.5s: Ace portrait slides in
  aceBubble, // 6s: Ace bubble appears + tap-to-continue
  alertFlash, // tap → red alert flash
  bigBanner, // 9s: 'OPERATION UNLOCKED'
  subtitle, // 10s: 'Hunter — 72 HOURS'
  description, // 11s: brief description
  rewards, // 12.5s: 'REACH 50% → CHEST | REACH 100% → CHEST'
  letsGo, // 14s: LET'S GO button visible
}

class _ChallengeRevealSequenceState extends State<ChallengeRevealSequence> {
  _RevealStage _stage = _RevealStage.initialPause;
  Timer? _scheduler;

  @override
  void initState() {
    super.initState();
    _scheduleStage(_RevealStage.hudOverlay,
        const Duration(milliseconds: 500));
    _scheduleStage(_RevealStage.acePortrait,
        const Duration(milliseconds: 1000));
    _scheduleStage(_RevealStage.aceBubble,
        const Duration(milliseconds: 1500));
  }

  void _scheduleStage(_RevealStage next, Duration delay) {
    Timer(delay, () {
      if (!mounted) return;
      setState(() => _stage = next);
    });
  }

  @override
  void dispose() {
    _scheduler?.cancel();
    super.dispose();
  }

  void _onTapToContinue() {
    if (_stage != _RevealStage.aceBubble) return;
    setState(() => _stage = _RevealStage.alertFlash);
    Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _stage = _RevealStage.bigBanner);
    });
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _stage = _RevealStage.subtitle);
    });
    Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() => _stage = _RevealStage.description);
    });
    Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() => _stage = _RevealStage.rewards);
    });
    Timer(const Duration(milliseconds: 4700), () {
      if (!mounted) return;
      setState(() => _stage = _RevealStage.letsGo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.challengeType;
    final beyondAlert = _stage.index >= _RevealStage.alertFlash.index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTapToContinue,
      child: Stack(
        children: [
          // HUD frame overlay
          if (_stage.index >= _RevealStage.hudOverlay.index)
            const Positioned.fill(
              child: AssetPlaceholderHudOverlay(visible: true),
            ),
          // Alert flash (one frame)
          if (_stage == _RevealStage.alertFlash)
            const Positioned.fill(
              child: ColoredBox(color: Color(0xCCFF1A1A)),
            ),
          // Ace portrait (slides in from left)
          if (_stage.index >= _RevealStage.acePortrait.index &&
              !beyondAlert)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height * 0.35,
              child: SizedBox(
                width: 140,
                height: 140,
                child: Image.asset(
                  AceExpression.excited.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: AssetPlaceholder.image(
                    color: AppColors.amber,
                    label: 'ace_excited',
                    borderRadius: 12,
                  ),
                ),
              ),
            ),
          // Ace bubble — pre-alert phase
          if (_stage == _RevealStage.aceBubble)
            Positioned(
              left: 170,
              top: MediaQuery.of(context).size.height * 0.38,
              right: 16,
              child: const _AceBubble(
                text: 'Hold up rookie — incoming transmission!',
              ),
            ),
          if (_stage == _RevealStage.aceBubble)
            const Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: _PulsingHint(text: 'TAP TO CONTINUE'),
              ),
            ),
          // Post-alert content
          if (_stage.index >= _RevealStage.bigBanner.index) ...[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_stage.index >= _RevealStage.bigBanner.index)
                      const _RevealBanner(text: 'OPERATION UNLOCKED'),
                    const SizedBox(height: 12),
                    if (_stage.index >= _RevealStage.subtitle.index)
                      Text(
                        '${type.displayName} — 72 HOURS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_stage.index >= _RevealStage.description.index)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          type.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.greenPale,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_stage.index >= _RevealStage.rewards.index)
                      const Text(
                        'REACH 50% → CHEST | REACH 100% → CHEST',
                        style: TextStyle(
                          color: AppColors.amberLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    const SizedBox(height: 36),
                    if (_stage == _RevealStage.letsGo)
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "LET'S GO!",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AssetPlaceholderHudOverlay extends StatelessWidget {
  // ignore: avoid_unused_constructor_parameters
  final bool visible;
  const AssetPlaceholderHudOverlay({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/ui/reveal_overlay_hud_frame.png',
      fit: BoxFit.cover,
      errorBuilder: AssetPlaceholder.image(
        color: Colors.black87,
        label: 'reveal_hud',
        borderRadius: 0,
      ),
    );
  }
}

class _RevealBanner extends StatelessWidget {
  final String text;
  const _RevealBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 320,
          height: 80,
          child: Image.asset(
            'assets/ui/reveal_banner_operation_unlocked.png',
            fit: BoxFit.contain,
            errorBuilder: AssetPlaceholder.image(
              color: AppColors.amber,
              label: 'reveal_banner',
              borderRadius: 8,
            ),
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
            shadows: [
              Shadow(blurRadius: 8, color: Colors.black87),
            ],
          ),
        ),
      ],
    );
  }
}

class _AceBubble extends StatelessWidget {
  final String text;
  const _AceBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber, width: 0.8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.greenPale,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _PulsingHint extends StatefulWidget {
  final String text;
  const _PulsingHint({required this.text});

  @override
  State<_PulsingHint> createState() => _PulsingHintState();
}

class _PulsingHintState extends State<_PulsingHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        return Opacity(
          opacity: 0.4 + 0.6 * _ctrl.value,
          child: Text(
            widget.text,
            style: const TextStyle(
              color: AppColors.amberLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        );
      },
    );
  }
}
