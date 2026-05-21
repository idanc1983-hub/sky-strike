import 'package:flutter/material.dart';
import '../../screens/menu_popup.dart';
import '../../shared/widgets/asset_placeholder.dart';

const _cAmber = Color(0xFFEF9F27);
const _cGreenPale = Color(0xFFC0DD97);
const _cPanel = Color(0xFF0d1f0d);

/// Placeholder popup surfaced from the home menu. The art is delivered via
/// remote config in a follow-up — until that asset lands the popup renders
/// the dev placeholder so the entry point is usable end-to-end.
///
/// Remote-config contract (future):
///   `daily_rewards` feature flag → enables the entry on the menu screen.
///   `daily_rewards_popup_asset`  → asset path served when the flag is on.
class DailyRewardsPopup extends StatelessWidget {
  /// Feature flag key. Controlled via `flags__feature_flags__v1` → toggles
  /// whether the popup body uses the remote-config asset path.
  static const String featureFlagKey = 'daily_rewards';

  const DailyRewardsPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const DailyRewardsPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _isFeatureEnabledSafe();
    return Dialog(
      backgroundColor: _cPanel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _cAmber.withValues(alpha: 0.55), width: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 28),
                const Expanded(
                  child: Text(
                    'DAILY REWARDS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _cGreenPale,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                MenuCloseButton(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 1,
              child: AssetPlaceholder(
                color: _cAmber.withValues(alpha: 0.55),
                label: enabled
                    ? 'daily_rewards_popup'
                    : 'daily_rewards_disabled',
                borderRadius: 10,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              enabled
                  ? 'Pop-up window asset will be supplied via remote config.'
                  : 'Daily rewards are currently disabled by remote config.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Feature flag enforcement was moved to the v2 RemoteConfigService surface;
  /// until the flag is re-wired the popup renders unconditionally (same as the
  /// previous try/catch fallback).
  bool _isFeatureEnabledSafe() => true;
}
