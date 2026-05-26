import 'package:flutter/material.dart';

import '../shared/theme/app_colors.dart';
import '../shared/widgets/app_top_bar.dart';

/// Social tab — placeholder screen surfacing the unreleased Clans / Wars /
/// Tournaments feature set. Per redesign mock (May 2026): shared top bar,
/// "Coming soon" eyebrow, hero title + tagline, then three feature cards.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.greenDeep,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar.full(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ComingSoonLabel(),
                    SizedBox(height: 14),
                    _Title(),
                    SizedBox(height: 12),
                    _Tagline(),
                    SizedBox(height: 22),
                    _FeatureCard(
                      title: 'Leaderboards',
                      icon: Icons.leaderboard,
                      description:
                          'Global and friends ranking. Prove you are the best pilot.',
                    ),
                    SizedBox(height: 10),
                    _FeatureCard(
                      title: 'Clan Wars',
                      icon: Icons.groups,
                      description:
                          'Form a squad and crush rival clans in 24-hour battles.',
                    ),
                    SizedBox(height: 10),
                    _FeatureCard(
                      title: 'Tournaments',
                      icon: Icons.workspace_premium,
                      description:
                          'Weekly ranked events with exclusive jet rewards.',
                    ),
                    SizedBox(height: 22),
                    // Second "Coming soon" is intentional per mock — sits
                    // below the feature cards as a soft repeat reminder.
                    _ComingSoonLabel(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Coming soon" eyebrow / footer label — amber, centered, slightly tracked.
// ---------------------------------------------------------------------------
class _ComingSoonLabel extends StatelessWidget {
  const _ComingSoonLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Coming soon',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.amber,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — title + tagline
// ---------------------------------------------------------------------------
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'CLANS WAR &\nTOURNAMENTS',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        letterSpacing: 4,
        height: 1.2,
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Complete. Dominate. Claim glory.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature card — name + per-event icon header, amber description below.
// Icon picks: leaderboard ranking, group-of-people for clans, crown-emblem
// for tournaments. Coloured amber to match the card accents.
// ---------------------------------------------------------------------------
class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack.withValues(alpha: 0.94),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 0.7,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: AppColors.amber.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
