import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../economy/constants/ace_dialogue_catalog.dart';
import '../economy/services/ftue_triggers.dart';
import '../economy/state/economy_state.dart';
import '../economy/ui/ace_dialogue_overlay.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
import 'jets_screen.dart';
import 'settings_screen.dart';

const _cGreen = Color(0xFF3B6D11);
const _cGreenMid = Color(0xFF639922);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _shopIndex = 1;
  int _index = 0;

  void _onTabSelected(int newIndex) {
    setState(() => _index = newIndex);
    // FTUE: first time the player opens the Shop tab AFTER clearing
    // Stage 1, Ace nudges them to take a peek. One-shot via the
    // `ftue_*` prefix in the catalog.
    if (newIndex == _shopIndex) {
      final economy = context.read<EconomyState>();
      if (economy.isFtueTriggerFired(FtueTriggers.stage1Completed)) {
        economy.requestAceLine(AceLineKeys.ftueShopIntro);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AceDialogueListener(
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            ShopScreen(),
            JetsScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0a1a0a),
        indicatorColor: _cGreen,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _index,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(icon: _HomeIcon(), label: 'Home'),
          NavigationDestination(icon: _ShopIcon(), label: 'Shop'),
          NavigationDestination(icon: _JetIcon(), label: 'Jets'),
          NavigationDestination(icon: _SettingsIcon(), label: 'Settings'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav icon painters
// ---------------------------------------------------------------------------
class _HomeIcon extends StatelessWidget {
  const _HomeIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(24, 24), painter: _HomePainter());
}

class _HomePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cGreenMid
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    // House silhouette
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.48)
      ..lineTo(w * 0.82, h * 0.48)
      ..lineTo(w * 0.82, h * 0.95)
      ..lineTo(w * 0.18, h * 0.95)
      ..lineTo(w * 0.18, h * 0.48)
      ..lineTo(0, h * 0.48)
      ..close();
    canvas.drawPath(path, paint);
    // Door cutout
    canvas.drawRect(
      Rect.fromLTWH(w * 0.37, h * 0.6, w * 0.26, h * 0.35),
      Paint()..color = const Color(0xFF0a1a0a),
    );
  }

  @override
  bool shouldRepaint(_HomePainter old) => false;
}

class _ShopIcon extends StatelessWidget {
  const _ShopIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(24, 24), painter: _ShopPainter());
}

class _ShopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cGreenMid
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.1, h * 0.35, w * 0.8, h * 0.6),
          const Radius.circular(3)),
      paint,
    );
    final handlePaint = Paint()
      ..color = _cGreenMid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.28, h * 0.08, w * 0.44, h * 0.35),
      3.14,
      3.14,
      false,
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(_ShopPainter old) => false;
}

class _JetIcon extends StatelessWidget {
  const _JetIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(24, 24), painter: _JetPainter());
}

class _JetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cGreenMid
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.6, h * 0.4)
      ..lineTo(w, h * 0.55)
      ..lineTo(w * 0.65, h * 0.65)
      ..lineTo(w * 0.6, h)
      ..lineTo(w * 0.5, h * 0.8)
      ..lineTo(w * 0.4, h)
      ..lineTo(w * 0.35, h * 0.65)
      ..lineTo(0, h * 0.55)
      ..lineTo(w * 0.4, h * 0.4)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_JetPainter old) => false;
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(24, 24), painter: _SettingsPainter());
}

class _SettingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cGreenMid
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    for (int i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(i * 3.14159 / 4);
      canvas.drawRect(Rect.fromLTWH(-2, -h * 0.48, 4, h * 0.22), paint);
      canvas.restore();
    }
    canvas.drawCircle(Offset(cx, cy), w * 0.32, paint);
    canvas.drawCircle(Offset(cx, cy), w * 0.16,
        Paint()..color = const Color(0xFF0a1a0a));
  }

  @override
  bool shouldRepaint(_SettingsPainter old) => false;
}
