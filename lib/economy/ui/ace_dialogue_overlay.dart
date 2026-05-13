import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../constants/ace_dialogue_catalog.dart';
import '../services/ftue_triggers.dart';
import '../state/economy_state.dart';
import 'ace_animated_portrait.dart';

/// Listener widget that watches `EconomyState.pendingAceLine` and shows
/// the bubble whenever a line is queued. Mount once near the top of the
/// widget tree (e.g. inside `MainShell`'s body) so it's available
/// across the home / shop / settings tabs.
class AceDialogueListener extends StatefulWidget {
  final Widget child;
  const AceDialogueListener({super.key, required this.child});

  @override
  State<AceDialogueListener> createState() => _AceDialogueListenerState();
}

class _AceDialogueListenerState extends State<AceDialogueListener> {
  String? _showingKey;

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    final pending = economy.pendingAceLine;
    if (pending != null && _showingKey == null) {
      _showingKey = pending;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _present(context, pending);
      });
    }
    return widget.child;
  }

  Future<void> _present(BuildContext context, String key) async {
    final line = AceDialogueCatalog.line(key);
    if (line == null) {
      // Unknown key; just consume so we don't loop.
      _showingKey = null;
      // ignore: use_build_context_synchronously
      context.read<EconomyState>().consumePendingAceLine();
      return;
    }
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.0),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => _AceBubbleDialog(line: line),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
    _showingKey = null;
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    context.read<EconomyState>().consumePendingAceLine();
  }
}

class _AceBubbleDialog extends StatelessWidget {
  final AceLine line;
  const _AceBubbleDialog({required this.line});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          right: 12,
          bottom: 80,
          child: Material(
            color: Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: AceAnimatedPortrait(expression: line.expression),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.amber,
                          width: 0.8,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: Text(line.text,
                                style: AppTypography.bodyPale
                                    .copyWith(fontSize: 13)),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () =>
                                  _onSkipPressed(context),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDark,
                                  border: Border.all(
                                    color: AppColors.greenLabel,
                                    width: 0.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.greenLabel,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSkipPressed(BuildContext context) async {
    final economy = context.read<EconomyState>();
    final navigator = Navigator.of(context);
    if (economy.isFtueTriggerFired(FtueTriggers.aceMasterSkipPrompted)) {
      navigator.pop();
      return;
    }
    economy.markFtueTriggerFired(FtueTriggers.aceMasterSkipPrompted);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text("Skip Ace's lines?",
            style: AppTypography.title),
        content: const Text(
          'You can re-enable in Settings.',
          style: AppTypography.bodyPale,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (yes == true) {
      economy.setAceDialogueEnabled(false);
    }
    navigator.pop();
  }
}
