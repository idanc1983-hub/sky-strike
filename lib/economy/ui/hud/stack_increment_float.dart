import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Brief "+1" float that rises from a tray slot when a pickup stacks
/// onto an existing power-up. Self-disposing — fades out after 800ms.
class StackIncrementFloat extends StatefulWidget {
  final String text;
  final Color? color;
  final VoidCallback? onComplete;

  const StackIncrementFloat({
    super.key,
    this.text = '+1',
    this.color,
    this.onComplete,
  });

  @override
  State<StackIncrementFloat> createState() => _StackIncrementFloatState();
}

class _StackIncrementFloatState extends State<StackIncrementFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.greenLight;
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) {
        final t = _controller.value;
        final opacity = (1 - t).clamp(0.0, 1.0);
        final dy = -16.0 * t;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Text(
              widget.text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                shadows: const [
                  Shadow(blurRadius: 2, color: Colors.black54),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
