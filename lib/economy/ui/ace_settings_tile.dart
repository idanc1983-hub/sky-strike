import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../state/economy_state.dart';

/// Settings switch — "Show Ace's tutorial dialogue".
/// Default ON, persisted via [EconomyState.aceDialogueEnabled].
class AceSettingsTile extends StatelessWidget {
  const AceSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    return SwitchListTile(
      tileColor: AppColors.cardBg,
      activeThumbColor: AppColors.green,
      value: economy.aceDialogueEnabled,
      onChanged: (next) =>
          context.read<EconomyState>().setAceDialogueEnabled(next),
      title: const Text(
        "Show Ace's tutorial dialogue",
        style: AppTypography.bodyPale,
      ),
      subtitle: const Text(
        'Helpful tips from your wingman during the early flights.',
        style: AppTypography.label,
      ),
    );
  }
}
