import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';

/// Live ticking countdown to a target [DateTime]. Cancels its timer on
/// dispose — the build prompt explicitly bans dangling timers.
class BundleCountdown extends StatefulWidget {
  final DateTime endsAt;
  final TextStyle? style;

  const BundleCountdown({
    super.key,
    required this.endsAt,
    this.style,
  });

  @override
  State<BundleCountdown> createState() => _BundleCountdownState();
}

class _BundleCountdownState extends State<BundleCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  void _tick(Timer _) {
    if (!mounted) return;
    final next = _computeRemaining();
    if (next == Duration.zero) {
      _timer?.cancel();
      _timer = null;
    }
    setState(() => _remaining = next);
  }

  Duration _computeRemaining() {
    final diff = widget.endsAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  String _format(Duration d) {
    if (d == Duration.zero) return 'ended';
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  Color _color() {
    if (_remaining.inHours < 1) return AppColors.danger;
    if (_remaining.inHours < 24) return AppColors.amber;
    return AppColors.amberLight;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? AppTypography.countdown;
    return Text(_format(_remaining), style: base.copyWith(color: _color()));
  }
}
