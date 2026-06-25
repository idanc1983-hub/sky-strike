import 'package:flutter/material.dart';

import '../shared/widgets/asset_placeholder.dart';

/// Boot splash shown before the home screen. Displays the
/// `Splash_screen.jpg` artwork full-bleed with a fake-loading progress bar
/// pinned to the bottom. Auto-advances to `/home` when the bar fills.
///
/// The fake-loading duration is intentionally short and the animation
/// runs in real time — once real boot work exists (asset preload,
/// remote config fetch, etc.) the controller can be driven by those
/// futures instead of a fixed Duration.
class SplashScreen extends StatefulWidget {
  /// Where to navigate after the bar fills. Defaults to `/home`.
  final String nextRoute;

  /// How long the fake-loading bar takes to fill.
  final Duration duration;

  /// Fires once, right before navigating to [nextRoute]. Used to boot
  /// flows that must wait until the app is interactive — e.g. the iOS
  /// ATT prompt, which we defer past the splash so the system dialog
  /// doesn't land on a still-loading screen.
  final VoidCallback? onDismiss;

  const SplashScreen({
    super.key,
    this.nextRoute = '/home',
    this.duration = const Duration(milliseconds: 2400),
    this.onDismiss,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_advanced) {
          _advanced = true;
          // Wait one frame so the bar visually settles at 100% before
          // we navigate away.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onDismiss?.call();
            Navigator.of(context).pushReplacementNamed(widget.nextRoute);
          });
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1a0a),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed splash artwork. The image is preloaded by
          // `didChangeDependencies` on the home screen later, but for
          // the splash itself a cold decode is acceptable — the
          // placeholder shows for a couple of frames at worst.
          Image.asset(
            'assets/backgrounds/Splash_screen.jpg',
            fit: BoxFit.cover,
            errorBuilder: AssetPlaceholder.image(
              color: const Color(0xFF0a1a0a),
              label: 'Splash_screen',
              borderRadius: 0,
            ),
          ),
          // Subtle gradient at the bottom for bar legibility on bright
          // splash art. Top → fully transparent; bottom → 65% black.
          const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0xA6000000),
                    ],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
          // Loading bar pinned to the bottom safe-area inset.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(40, 0, 40, 40),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (ctx, _) {
                    final pct = _controller.value.clamp(0.0, 1.0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'LOADING',
                              style: TextStyle(
                                color: Color(0xFFC0DD97),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.0,
                              ),
                            ),
                            Text(
                              '${(pct * 100).floor()}%',
                              style: const TextStyle(
                                color: Color(0xFFC0DD97),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1a2a1a),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: const Color(0xFF1e3d1e),
                              width: 0.5,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: pct,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF3B6D11),
                                      Color(0xFF97C459),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF97C459)
                                          .withValues(alpha: 0.55),
                                      blurRadius: 6,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
