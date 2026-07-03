import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/theme/app_colors.dart';
import 'invite_state.dart';

/// The single live, actionable element on the otherwise "coming soon" Social
/// screen. Renders below the bottom "Coming soon" label and matches the amber
/// feature-card look above it, with a deliberately green Share CTA to signal
/// the one tappable action.
///
/// Reads the app-lifetime [InviteState] provided at the root (so the Social
/// nav badge can observe the same instance before this card is ever built).
/// Renders nothing at all when the feature is disabled via `invite__enabled__v1`.
class InviteCard extends StatelessWidget {
  const InviteCard({super.key});

  // Disabled Share CTA colours — not part of the shared palette.
  static const _disabledBg = Color(0xFF14210E);
  static const _disabledFg = Color(0xFF5A6B4A);

  @override
  Widget build(BuildContext context) {
    // Rebuilds on every InviteState notification (share, cooldown tick, reset).
    final state = context.watch<InviteState>();
    if (!state.enabled) return const SizedBox.shrink();

    return Padding(
      // Leading gap matches the section rhythm above; rendered only when the
      // card is present, so a disabled feature leaves no empty space.
      padding: const EdgeInsets.only(top: 22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceBlack.withValues(alpha: 0.94),
          border: Border.all(
            color: AppColors.amber.withValues(alpha: 0.55),
            width: 0.7,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(),
            const SizedBox(height: 4),
            _rewardLine(state),
            const SizedBox(height: 12),
            _shareButton(state),
            const SizedBox(height: 8),
            _statusLine(state),
          ],
        ),
      ),
    );
  }

  // Row 1 — heading.
  Widget _heading() {
    return const Row(
      children: [
        Icon(Icons.ios_share, color: AppColors.amber, size: 18),
        SizedBox(width: 8),
        Text(
          'Invite Friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Row 2 — reward line (values pulled live from state). Uses the same gem /
  // coin art as the top-bar holders, inlined at text size.
  Widget _rewardLine(InviteState state) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Earn ${state.rewardGems} '),
          _iconSpan('assets/ui/icon_gem.png', 'gem'),
          const TextSpan(text: '  +  '),
          TextSpan(text: '${state.rewardCoins} '),
          _iconSpan('assets/ui/icon_coin.png', 'coin'),
          const TextSpan(text: '  per invite'),
        ],
      ),
      style: const TextStyle(
        color: AppColors.amberLight,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // A currency glyph sized to sit inline with the 13px reward text.
  static WidgetSpan _iconSpan(String asset, String label) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Image.asset(
          asset,
          width: 15,
          height: 15,
          errorBuilder: (_, __, ___) =>
              const SizedBox(width: 15, height: 15),
        ),
      ),
    );
  }

  // Row 3 — Share CTA. Green when live, dark/greyed when on cooldown or
  // in-flight. Enablement is bound to InviteState.canShare.
  Widget _shareButton(InviteState state) {
    final enabled = state.canShare;
    final fg = enabled ? AppColors.greenPale : _disabledFg;
    return SizedBox(
      height: 44,
      child: Material(
        color: enabled ? AppColors.green : _disabledBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? state.onSharePressed : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ios_share, color: fg, size: 18),
              const SizedBox(width: 8),
              Text(
                'Share',
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Row 4 — status line: availability count, or a live cooldown countdown.
  Widget _statusLine(InviteState state) {
    final String text;
    final Color color;
    if (state.isOnCooldown) {
      text = _formatCooldown(state.cooldownLeft);
      color = AppColors.amber;
    } else {
      text = '${state.remaining}/${state.cap} available';
      color = AppColors.greenLight;
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// "⏱ Renews in 23h 04m" while >= 1 hour remains, "⏱ Renews in 9m 58s"
  /// below that. The largest shown unit drops its leading zero; smaller units
  /// are zero-padded to two digits.
  static String _formatCooldown(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (total >= 3600) {
      return '⏱ Renews in ${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '⏱ Renews in ${m}m ${s.toString().padLeft(2, '0')}s';
  }
}
