import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';

/// Small red "!" badge pinned to the top-right of a chest icon.
///
/// Project rule (see [ChestContentsPopup]): every chest icon in the game
/// is tappable and opens its contents preview. This badge is the visual
/// affordance that tells the player the chest is interactive — without it
/// the tap target is undiscoverable. Wrap any tappable chest icon with
/// [ChestInfoBadge.wrap] so the cue stays identical across screens.
class ChestInfoBadge extends StatelessWidget {
  /// Outer diameter of the badge dot in logical pixels.
  final double diameter;

  const ChestInfoBadge({super.key, this.diameter = 16});

  /// Overlays a [ChestInfoBadge] on the top-right corner of [icon].
  ///
  /// The badge overhangs the icon slightly, so the returned Stack uses
  /// [Clip.none]; ensure no ancestor clips the corner. [diameter] sizes
  /// the badge — scale it down for small (≤28px) icons.
  static Widget wrap(Widget icon, {double diameter = 16}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -diameter * 0.25,
          right: -diameter * 0.25,
          child: ChestInfoBadge(diameter: diameter),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.danger,
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        '!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: diameter * 0.72,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}
