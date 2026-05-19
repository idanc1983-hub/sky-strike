import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../economy/state/economy_state.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const _cBg          = Color(0xFF071507);
const _cGreen       = Color(0xFF3B6D11);
const _cGreenLight  = Color(0xFF97C459);
const _cGreenPale   = Color(0xFFC0DD97);
const _cAmber       = Color(0xFFEF9F27);
const _cAmberLight  = Color(0xFFFAC775);
const _cGemBg       = Color(0xFF412402);
const _cDivider     = Color(0xFF1f3a1f);
const _cCard        = Color(0xEB0D1A0D); // rgba(13,26,13,0.92)
const _cTrophyBg    = Color(0xFF1F0D00);
const _cSnackBg     = Color(0xFF0d2a0d);

/// Stable single-screen destination for the Social tab. Sells the feature
/// set behind the unreleased Clans/Tournament/Leaderboard/Gifts loop and
/// captures a "notify me when live" opt-in. The opt-in flag persists via
/// SharedPreferences so the player only sees the CTA once.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  static const String _prefsKey = 'social_notify_opt_in';

  bool _notifyOptedIn = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadNotifyState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.forward());
  }

  Future<void> _loadNotifyState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifyOptedIn = prefs.getBool(_prefsKey) ?? false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double start, double end) => CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      );

  Future<void> _onNotifyTap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    if (!mounted) return;
    setState(() => _notifyOptedIn = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "You'll be the first to know!",
          style: TextStyle(color: _cGreenLight, fontSize: 12),
        ),
        backgroundColor: _cSnackBg,
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 2500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gems = context.watch<EconomyState>().gems;

    return Scaffold(
      backgroundColor: _cBg,
      body: SafeArea(
        child: Column(
          children: [
            _HeaderBar(gems: gems),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _staggered(_stagger(0.00, 0.38), const _Eyebrow()),
                    const SizedBox(height: 12),
                    _staggered(_stagger(0.12, 0.50), const _TrophyIcon()),
                    const SizedBox(height: 14),
                    _staggered(_stagger(0.22, 0.58), const _Title()),
                    const SizedBox(height: 6),
                    _staggered(_stagger(0.30, 0.65), const _Tagline()),
                    const SizedBox(height: 18),
                    _staggered(_stagger(0.38, 0.68), const _SectionDivider()),
                    const SizedBox(height: 18),
                    _staggered(_stagger(0.45, 0.80), const _FeatureGrid()),
                    const SizedBox(height: 20),
                    _staggered(
                      _stagger(0.57, 0.90),
                      _NotifySection(
                        optedIn: _notifyOptedIn,
                        onNotify: _onNotifyTap,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _staggered(Animation<double> anim, Widget child) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(anim);
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ─── Header bar ─────────────────────────────────────────────────────────────
class _HeaderBar extends StatelessWidget {
  final int gems;
  const _HeaderBar({required this.gems});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const Border(
        bottom: BorderSide(color: _cDivider, width: 0.5),
      ).toDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SOCIAL',
            style: TextStyle(
              color: _cGreenLight,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.04, // ~0.08em at 13px
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _cGemBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '\u{1F48E} ',
                  style: TextStyle(fontSize: 11),
                ),
                Text(
                  '$gems',
                  style: const TextStyle(
                    color: _cAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _BorderToDecoration on Border {
  Decoration toDecoration() => BoxDecoration(border: this);
}

// ─── Hero pieces ────────────────────────────────────────────────────────────
class _Eyebrow extends StatelessWidget {
  const _Eyebrow();
  @override
  Widget build(BuildContext context) => const Text(
        'COMING SOON',
        style: TextStyle(
          color: _cAmber,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.6, // ~0.16em at 10px
        ),
      );
}

class _TrophyIcon extends StatelessWidget {
  const _TrophyIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: _cTrophyBg,
        border: Border.all(color: _cAmber, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.emoji_events_outlined,
        size: 34,
        color: _cAmber,
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Clans War & Tournaments',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _cAmberLight,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.22, // ~0.01em
          ),
        ),
      );
}

class _Tagline extends StatelessWidget {
  const _Tagline();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Compete. Dominate. Claim glory.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _cGreenPale.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) => Container(
        height: 0.5,
        width: double.infinity,
        color: _cDivider,
      );
}

// ─── Feature grid ───────────────────────────────────────────────────────────
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _FeatureCard(
            icon: SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(
                painter: CrossedSwordsIconPainter(_cAmber),
              ),
            ),
            name: 'Clan Wars',
            description:
                'Form a squad and crush rival clans in 24-hour battles.',
          ),
          _FeatureCard(
            icon: Icon(Icons.military_tech_outlined,
                size: 22, color: _cAmber),
            name: 'Tournaments',
            description: 'Weekly ranked events with exclusive jet rewards.',
          ),
          _FeatureCard(
            icon: Icon(Icons.leaderboard_outlined,
                size: 22, color: _cAmber),
            name: 'Leaderboards',
            description:
                'Global and friends rankings. Prove you are the best pilot.',
          ),
          _FeatureCard(
            icon: Icon(Icons.card_giftcard_outlined,
                size: 22, color: _cAmber),
            name: 'Clan Gifts',
            description: 'Share power-ups and rewards with your crew.',
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final Widget icon;
  final String name;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cCard,
        border: Border.all(color: _cDivider, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              color: _cGreenPale,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: _cGreenLight.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notify button ──────────────────────────────────────────────────────────
class _NotifySection extends StatelessWidget {
  final bool optedIn;
  final VoidCallback onNotify;

  const _NotifySection({required this.optedIn, required this.onNotify});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (optedIn)
            const _OptedInRow()
          else
            _NotifyButton(onTap: onNotify),
          const SizedBox(height: 10),
          Text(
            "We'll alert you the moment it launches",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _cGreenLight.withValues(alpha: 0.3),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: _cGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_outlined, size: 18, color: _cGreenPale),
            SizedBox(width: 8),
            Text(
              "Notify me when it's live",
              style: TextStyle(
                color: _cGreenPale,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptedInRow extends StatelessWidget {
  const _OptedInRow();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: _cGreenLight),
          SizedBox(width: 8),
          Text(
            "You're on the list",
            style: TextStyle(
              color: _cGreenLight,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Crossed swords painter ─────────────────────────────────────────────────
class CrossedSwordsIconPainter extends CustomPainter {
  final Color color;
  const CrossedSwordsIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(
      Offset(w * 0.15, h * 0.15),
      Offset(w * 0.85, h * 0.85),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.32, h * 0.42),
      Offset(w * 0.58, h * 0.18),
      paint,
    );

    canvas.drawLine(
      Offset(w * 0.85, h * 0.15),
      Offset(w * 0.15, h * 0.85),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.68, h * 0.42),
      Offset(w * 0.42, h * 0.18),
      paint,
    );
  }

  @override
  bool shouldRepaint(CrossedSwordsIconPainter old) => old.color != color;
}
