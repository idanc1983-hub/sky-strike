import 'package:flutter/material.dart';
import '../economy/ui/daily_reward_screen.dart';
import 'settings_screen.dart';
import 'world_map_screen.dart';

const _cGreen = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenMid = Color(0xFF639922);
const _cAmber = Color(0xFFEF9F27);
const _cPanel = Color(0xFF0d1f0d);

/// Modal launched from the home-screen menu icon. Surfaces the three
/// menu sections (Settings, World Map, Daily Rewards) and routes the
/// player into the matching screen / popup. Closes itself before opening
/// the destination so the menu does not stack behind every push.
class MenuPopup extends StatelessWidget {
  const MenuPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const MenuPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Capture the navigator once — referencing `context` after the
    // dialog has been popped is fragile because the dialog element
    // begins deactivating in the same frame.
    final nav = Navigator.of(context);

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
            _Header(onClose: nav.pop),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () {
                nav.pop();
                nav.push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.public_rounded,
              label: 'World Map',
              onTap: () {
                nav.pop();
                nav.push(
                  MaterialPageRoute(builder: (_) => const WorldMapScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.card_giftcard_rounded,
              label: 'Daily Rewards',
              onTap: () {
                nav.pop();
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => const DailyRewardScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 28),
        const Expanded(
          child: Text(
            'MENU',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _cGreenPale,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
        ),
        MenuCloseButton(onTap: onClose),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1606).withValues(alpha: 0.92),
          border: Border.all(color: _cGreen, width: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _cGreen.withValues(alpha: 0.3),
                border: Border.all(color: _cGreenMid, width: 0.5),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: _cGreenLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _cGreenPale,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _cGreenMid, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Top-right X used to dismiss the menu and any sub-screen / popup that
/// the menu opens. Exposed so [SettingsScreen], [WorldMapScreen], and
/// [DailyRewardsPopup] share the same hit-target and styling.
class MenuCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const MenuCloseButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0A1606).withValues(alpha: 0.92),
          border: Border.all(color: _cAmber.withValues(alpha: 0.55), width: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.close_rounded, color: _cGreenPale, size: 18),
      ),
    );
  }
}
