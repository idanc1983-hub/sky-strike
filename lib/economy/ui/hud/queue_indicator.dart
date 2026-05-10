import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/asset_placeholder.dart';

/// Small inbox/stack icon next to the in-game tray (top-right of HUD).
/// Hidden when [queueSize] is 0; shows the current count otherwise.
class QueueIndicator extends StatelessWidget {
  final int queueSize;
  const QueueIndicator({super.key, required this.queueSize});

  @override
  Widget build(BuildContext context) {
    if (queueSize <= 0) return const SizedBox.shrink();
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.amber, width: 0.8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/ui/hud_queue_icon.png',
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amberDark,
                label: 'queue',
                borderRadius: 4,
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$queueSize',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
