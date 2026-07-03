import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/notification_badge_controller.dart';
import '../ui/widgets/notification_badge.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
import 'jets_screen.dart';
import 'social_screen.dart';

const _cNavBg          = Color(0xFF0a1a0a);
const _cNavIndicator   = Color(0x403B6D11);
const _cNavInactive    = Color(0xFF639922);
const _cNavActive      = Color(0xFF97C459);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _onTabSelected(int newIndex) {
    setState(() => _index = newIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Red dot on the Social tab when a free invite reward is available.
    final showSocialBadge =
        context.watch<NotificationBadgeController>().showSocialBadge;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(active: _index == 0),
          const ShopScreen(),
          const JetsScreen(),
          const SocialScreen(),
        ],
      ),
      bottomNavigationBar: ColoredBox(
        color: _cNavBg,
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: NavigationBar(
        backgroundColor: _cNavBg,
        indicatorColor: _cNavIndicator,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 60,
        selectedIndex: _index,
        onDestinationSelected: _onTabSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined, color: _cNavInactive),
            selectedIcon: Icon(Icons.home_outlined, color: _cNavActive),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined, color: _cNavInactive),
            selectedIcon: Icon(Icons.shopping_bag_outlined, color: _cNavActive),
            label: 'Shop',
          ),
          const NavigationDestination(
            icon: _JetNavIcon(color: _cNavInactive),
            selectedIcon: _JetNavIcon(color: _cNavActive),
            label: 'Jets',
          ),
          // Social tab carries the invite-reward badge on both icon states so
          // the dot stays visible whether or not the tab is selected. Active
          // indicator (#3B6D11) and label (#639922) are preserved.
          NavigationDestination(
            icon: NotificationBadge(
              show: showSocialBadge,
              child: const Icon(Icons.emoji_events_outlined,
                  color: _cNavInactive),
            ),
            selectedIcon: NotificationBadge(
              show: showSocialBadge,
              child:
                  const Icon(Icons.emoji_events_outlined, color: _cNavActive),
            ),
            label: 'Social',
          ),
        ],
      ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Jets nav icon — top-down jet silhouette drawn in code (spec mandates a
// CustomPainter here, no Material substitute).
// ---------------------------------------------------------------------------
class _JetNavIcon extends StatelessWidget {
  final Color color;
  const _JetNavIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: JetIconPainter(color)),
    );
  }
}

class JetIconPainter extends CustomPainter {
  final Color color;
  JetIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    // Fuselage — narrow vertical body
    final fuselage = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.58, h * 0.65)
      ..lineTo(w * 0.5, h * 0.75)
      ..lineTo(w * 0.42, h * 0.65)
      ..close();

    // Left wing
    final leftWing = Path()
      ..moveTo(w * 0.44, h * 0.38)
      ..lineTo(0, h * 0.72)
      ..lineTo(w * 0.38, h * 0.60)
      ..close();

    // Right wing
    final rightWing = Path()
      ..moveTo(w * 0.56, h * 0.38)
      ..lineTo(w, h * 0.72)
      ..lineTo(w * 0.62, h * 0.60)
      ..close();

    // Rear stabilisers
    final leftStab = Path()
      ..moveTo(w * 0.46, h * 0.70)
      ..lineTo(w * 0.28, h * 0.90)
      ..lineTo(w * 0.44, h * 0.82)
      ..close();

    final rightStab = Path()
      ..moveTo(w * 0.54, h * 0.70)
      ..lineTo(w * 0.72, h * 0.90)
      ..lineTo(w * 0.56, h * 0.82)
      ..close();

    canvas.drawPath(fuselage, paint);
    canvas.drawPath(leftWing, paint);
    canvas.drawPath(rightWing, paint);
    canvas.drawPath(leftStab, paint);
    canvas.drawPath(rightStab, paint);
  }

  @override
  bool shouldRepaint(JetIconPainter old) => old.color != color;
}
