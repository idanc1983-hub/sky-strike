import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/remote_config_service.dart';
import '../../game/models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../social/invite_state.dart';
import '../../widgets/chest_open_overlay.dart';
import '../../widgets/coins_burst_overlay.dart';
import '../state/economy_state.dart';
import 'generic_offer_popup.dart';
import 'snake_offer_popup.dart';
import 'three_plus_one_offer_popup.dart';

/// Each biome ships with this many levels. Wave counts per level come
/// from Remote Config (`difficulty__wave_curves__v1`), so this is just
/// the picker upper-bound, not a gameplay constant.
const int _kLevelsPerBiome = 10;

/// Soft gate against accidental opens. Stored in source for dev
/// convenience — this is **not** real security; anyone with the binary
/// can decompile and find this string. It's a friction layer, not a
/// secret-keeping device.
const _devToolsPasscode = 'Nala';

/// Session-only unlock flag. Set to true after a successful passcode
/// entry; reset on app kill or hot-restart. Keeping it static (rather
/// than persisted) means the gate re-asserts itself across full app
/// relaunches without bothering the dev between bottom-sheet opens.
bool _sessionUnlocked = false;

/// Hidden developer-only bottom sheet. Surfaced by long-pressing the
/// version string at the bottom of the Settings screen. Wrapped in
/// [kDebugMode] so it never appears in release builds.
///
/// Gated by a passcode on first open per app session. Once the correct
/// code is entered, subsequent opens skip the prompt until the next
/// full launch.
class DevToolsSheet extends StatelessWidget {
  const DevToolsSheet({super.key});

  /// Shows the sheet. In release builds this is a no-op. In debug
  /// builds the user is prompted for the passcode unless already
  /// unlocked this session.
  static Future<void> show(BuildContext context) async {
    if (!kDebugMode) return;
    if (!_sessionUnlocked) {
      final granted = await _DevPasscodePrompt.show(context);
      if (!granted) return;
      _sessionUnlocked = true;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      builder: (_) => const DevToolsSheet(),
    );
  }

  /// Forcibly relocks the session — exposed for tests or future
  /// "log out" affordance.
  @visibleForTesting
  static void lockForTest() => _sessionUnlocked = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEBUG',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('DEV TOOLS', style: AppTypography.title),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.greenLabel),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'kDebugMode only — never shipped to release. Each action '
                'is confirmation-gated.',
                style: AppTypography.label,
              ),
              const SizedBox(height: 16),
              const _StageLauncher(),
              const SizedBox(height: 10),
              const _MonetizationLauncher(),
              const SizedBox(height: 10),
              const _AnimationLab(),
              const SizedBox(height: 10),
              const _WalletEditor(),
              const SizedBox(height: 16),
              _DevAction(
                title: 'Replay FTUE',
                subtitle:
                    'Clears Stage 3 reveal + Stage 1 completion flag. '
                    'Wallets, level and progression preserved.',
                onConfirmed: (economy) async => economy.debugReplayFtue(),
                confirmLabel: 'REPLAY',
              ),
              const SizedBox(height: 10),
              _DevAction(
                title: 'Reset challenge cycle',
                subtitle:
                    'Wipes the active 72h cycle and re-locks the challenge '
                    'reveal flag so a fresh cycle starts on next reveal.',
                onConfirmed: (economy) async =>
                    economy.debugResetChallengeCycle(),
                confirmLabel: 'RESET',
              ),
              const SizedBox(height: 10),
              _DevAction(
                title: 'Force-activate challenge',
                subtitle:
                    'Reveals + starts a challenge cycle seeded to ~50% so the '
                    'home card shows an unlocked bar. Pair with "WIN CHALLENGE '
                    'PRIZE" to watch the fill + prize collection on the card.',
                onConfirmed: (economy) async =>
                    economy.debugActivateChallengeCycle(),
                confirmLabel: 'ACTIVATE',
              ),
              const SizedBox(height: 10),
              _DevAction(
                title: 'Reset daily streak',
                subtitle:
                    'Sets streak day to 1, week to 0, longest to 0, clears '
                    'lastClaimDate so the next claim starts from Day 1. '
                    'Also makes today claimable, so the MENU badge shows. '
                    'Use to re-test the ladder (including the Day 7 jet).',
                onConfirmed: (economy) async =>
                    economy.debugResetDailyStreak(),
                confirmLabel: 'RESET',
              ),
              const SizedBox(height: 10),
              _DevAction(
                title: 'Force invite reward',
                subtitle:
                    'Refills the invite daily allowance and clears any '
                    'cooldown so the reward is available now — the Social tab '
                    'badge shows and the Share CTA re-enables.',
                onConfirmedCtx: (ctx) async =>
                    ctx.read<InviteState>().debugForceAvailable(),
                confirmLabel: 'FORCE',
              ),
              const SizedBox(height: 10),
              _DevAction(
                title: 'Sim Stage 1 clear',
                subtitle:
                    'Awards a 3★ Stage 1 clear (≈600 coins + 2 gems) and '
                    'reveals the home-screen coin chip.',
                onConfirmed: (economy) async =>
                    economy.debugSimulateStage1Clear(),
                confirmLabel: 'CLEAR',
              ),
              const SizedBox(height: 10),
              _DevAction(
                title: 'Hard reset economy',
                subtitle:
                    'Factory reset: coins, gems, level, streak, loadouts, '
                    'IAP history, FTUE flags — everything goes back to '
                    'first-install defaults.',
                danger: true,
                onConfirmed: (economy) => economy.debugHardReset(),
                confirmLabel: 'WIPE',
              ),
              const SizedBox(height: 16),
              _StateSummary(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevAction extends StatefulWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  final bool danger;

  /// Economy-scoped handler — receives the shared [EconomyState]. Used by the
  /// majority of actions. Exactly one of [onConfirmed] / [onConfirmedCtx] must
  /// be supplied.
  final Future<void> Function(EconomyState economy)? onConfirmed;

  /// Context-scoped handler for actions that touch state other than economy
  /// (e.g. `context.read<InviteState>()`). Reads run synchronously before the
  /// post-action await, so the context is used only while still mounted.
  final Future<void> Function(BuildContext context)? onConfirmedCtx;

  const _DevAction({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    this.onConfirmed,
    this.onConfirmedCtx,
    this.danger = false,
  }) : assert(
          (onConfirmed == null) != (onConfirmedCtx == null),
          'Provide exactly one of onConfirmed / onConfirmedCtx',
        );

  @override
  State<_DevAction> createState() => _DevActionState();
}

class _DevActionState extends State<_DevAction> {
  bool _busy = false;

  Future<void> _run() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(widget.title, style: AppTypography.title),
        content: Text(widget.subtitle, style: AppTypography.bodyPale),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  widget.danger ? AppColors.danger : AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (widget.onConfirmedCtx != null) {
      await widget.onConfirmedCtx!(context);
    } else {
      await widget.onConfirmed!(context.read<EconomyState>());
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(content: Text('${widget.title} — done.')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.danger ? AppColors.danger : AppColors.greenTrack,
          width: 0.6,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: AppTypography.bodyPale.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: widget.danger
                        ? AppColors.danger
                        : AppColors.greenPale,
                  ),
                ),
                const SizedBox(height: 2),
                Text(widget.subtitle, style: AppTypography.label),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  widget.danger ? AppColors.danger : AppColors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            onPressed: _busy ? null : _run,
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

/// Biome + level picker that jumps straight into a stage without going
/// through the home screen. Mirrors the home screen's launch path:
/// sets the current world/stage, primes `beginStage`, then pushes the
/// loading screen.
class _StageLauncher extends StatefulWidget {
  const _StageLauncher();

  @override
  State<_StageLauncher> createState() => _StageLauncherState();
}

class _StageLauncherState extends State<_StageLauncher> {
  int _world = 1;
  int _stage = 1;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final economy = context.read<EconomyState>();
    _world = economy.currentWorld.clamp(1, 6);
    _stage = economy.currentStage.clamp(1, _kLevelsPerBiome);
    _initialized = true;
  }

  Future<void> _launch() async {
    final economy = context.read<EconomyState>();
    final navigator = Navigator.of(context);
    economy.setCurrentWorld(_world);
    economy.setCurrentStage(_stage);
    economy.beginStage(_stage);
    // Close the dev tools sheet, then jump to the loading screen.
    navigator.pop();
    await navigator.pushNamed(
      '/loading',
      arguments: {'world': _world, 'stage': _stage},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greenTrack, width: 0.6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Launch stage',
            style: AppTypography.bodyPale.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.greenPale,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pick a biome and level, then jump straight in. Wave counts '
            'come from Remote Config.',
            style: AppTypography.label,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LabeledDropdown<int>(
                  label: 'BIOME',
                  value: _world,
                  items: [
                    for (var w = 1; w <= 6; w++)
                      DropdownMenuItem(
                        value: w,
                        child: Text('$w · ${worldName(w)}'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _world = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledDropdown<int>(
                  label: 'LEVEL',
                  value: _stage,
                  items: [
                    for (var s = 1; s <= _kLevelsPerBiome; s++)
                      DropdownMenuItem(
                        value: s,
                        child: Text('Level $s'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _stage = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _launch,
            child: Text(
              'LAUNCH ${worldName(_world).toUpperCase()} · LV $_stage',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact label + dropdown pair used inside the stage launcher.
class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.greenTrack, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.cardBg,
              iconEnabledColor: AppColors.greenLabel,
              style: AppTypography.bodyPale.copyWith(fontSize: 13),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Direct-edit wallet panel. Lets QA overwrite coins and gems to any
/// absolute value without ladder-walking through grants. Bypasses the
/// usual analytics-sourced [EconomyState.addCoins]/[EconomyState.addGems]
/// path on purpose — see [EconomyState.debugSetCoins].
class _WalletEditor extends StatefulWidget {
  const _WalletEditor();

  @override
  State<_WalletEditor> createState() => _WalletEditorState();
}

class _WalletEditorState extends State<_WalletEditor> {
  final TextEditingController _coinsCtrl = TextEditingController();
  final TextEditingController _gemsCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final economy = context.read<EconomyState>();
    _coinsCtrl.text = economy.coins.toString();
    _gemsCtrl.text = economy.gems.toString();
    _initialized = true;
  }

  @override
  void dispose() {
    _coinsCtrl.dispose();
    _gemsCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final economy = context.read<EconomyState>();
    final newCoins = int.tryParse(_coinsCtrl.text.trim());
    final newGems = int.tryParse(_gemsCtrl.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (newCoins == null && newGems == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter at least one valid integer.')),
      );
      return;
    }
    if (newCoins != null) economy.debugSetCoins(newCoins);
    if (newGems != null) economy.debugSetGems(newGems);
    FocusScope.of(context).unfocus();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Wallet set to ${economy.coins} coins / ${economy.gems} gems.',
        ),
      ),
    );
  }

  void _resyncFromState() {
    final economy = context.read<EconomyState>();
    setState(() {
      _coinsCtrl.text = economy.coins.toString();
      _gemsCtrl.text = economy.gems.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greenTrack, width: 0.6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wallet',
                  style: AppTypography.bodyPale.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.greenPale,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Reload from current balance',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh,
                    color: AppColors.greenLabel, size: 18),
                onPressed: _resyncFromState,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Live: ${economy.coins} coins / ${economy.gems} gems.',
            style: AppTypography.label,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WalletField(
                  label: 'COINS',
                  controller: _coinsCtrl,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WalletField(
                  label: 'GEMS',
                  controller: _gemsCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _apply,
            child: const Text(
              'APPLY',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _WalletField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTypography.bodyPale.copyWith(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.cardBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                  color: AppColors.greenTrack, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: AppColors.amber, width: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small live-summary panel so the dev can see current state at a glance
/// without bouncing back to the home screen.
class _StateSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyState>();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.greenDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greenTrack, width: 0.5),
      ),
      child: DefaultTextStyle.merge(
        style: AppTypography.label.copyWith(fontSize: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CURRENT STATE',
              style: AppTypography.label,
            ),
            const SizedBox(height: 4),
            Text('coins / gems: ${economy.coins} / ${economy.gems}'),
            Text(
              'level: ${economy.level} (xp ${economy.xp}/${economy.xpMax})',
            ),
            Text(
              'world: ${economy.currentWorld} (max reached '
              '${economy.maxWorldReached})',
            ),
            Text(
              'challenge: ${economy.challengeRevealed ? "revealed" : "hidden"}'
              '${economy.activeChallengeType == null ? "" : " · ${economy.activeChallengeType!.name} ${economy.challengeProgress}/${economy.challengeTarget}"}',
            ),
            Text('streak: day ${economy.streakDay} (longest '
                '${economy.longestStreak})'),
            Text('FTUE triggers fired: ${economy.firedFtueTriggers.length}'),
          ],
        ),
      ),
    );
  }
}

/// Passcode prompt shown before the dev tools sheet opens (gating the
/// first open per app session). Resolves to `true` on correct entry,
/// `false` on cancel or wrong code.
class _DevPasscodePrompt extends StatefulWidget {
  const _DevPasscodePrompt();

  static Future<bool> show(BuildContext context) async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DevPasscodePrompt(),
    );
    return granted ?? false;
  }

  @override
  State<_DevPasscodePrompt> createState() => _DevPasscodePromptState();
}

class _DevPasscodePromptState extends State<_DevPasscodePrompt>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _shake;
  String? _error;
  int _wrongAttempts = 0;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Auto-focus the field so the keyboard opens immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text == _devToolsPasscode) {
      Navigator.of(context).pop(true);
      return;
    }
    _wrongAttempts += 1;
    setState(() {
      _error = _wrongAttempts >= 3
          ? 'Nope. Cancel and try again later.'
          : 'Incorrect code.';
    });
    _shake.forward(from: 0);
    HapticFeedback.lightImpact();
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (ctx, child) {
        final v = _shake.value;
        final dx = v == 0
            ? 0.0
            : 8.0 *
                (v < 0.5 ? v * 2 : (1 - v) * 2) *
                ((v * 8).floor().isEven ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.amber, width: 0.6),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DEBUG',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('DEV TOOLS LOCKED', style: AppTypography.title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the developer passcode to continue.',
              style: AppTypography.bodyPale,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                  color: AppColors.greenPale, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Passcode',
                hintStyle: AppTypography.label,
                filled: true,
                fillColor: AppColors.surfaceDark,
                errorText: _error,
                errorStyle: const TextStyle(
                    color: AppColors.danger, fontSize: 11),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                      color: AppColors.greenTrack, width: 0.6),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                      color: AppColors.amber, width: 0.8),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                      color: AppColors.danger, width: 0.8),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                      color: AppColors.danger, width: 0.8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: _submit,
            child: const Text('UNLOCK'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Animation lab — preview in-progress motion/FX over a dimmed screen.
// =============================================================================
class _AnimationLab extends StatelessWidget {
  const _AnimationLab();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Animation lab',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Preview WIP motion over a dimmed screen. Coins burst replays '
            'the uploaded arrows motion with coin sprites. Chest open runs '
            'the full win-a-chest flow. Tap to dismiss.',
            style: AppTypography.label,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              // Close the dev sheet first so the burst plays over the
              // screen behind it, then darken + play.
              final rootNav =
                  Navigator.of(context, rootNavigator: true);
              Navigator.of(context).pop();
              CoinsBurstOverlay.show(rootNav.context);
            },
            child: const Text('PLAY COINS BURST'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              // Close the dev sheet first so the chest plays over the
              // screen behind it, then darken + run the flow. Test grant
              // of 100 coins / 50 gems (already-credited semantics — the
              // overlay only releases the display, a no-op in the lab).
              final rootNav =
                  Navigator.of(context, rootNavigator: true);
              Navigator.of(context).pop();
              ChestOpenOverlay.show(rootNav.context, coins: 100, gems: 50);
            },
            child: const Text('PLAY CHEST OPEN'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final rootNav =
                  Navigator.of(context, rootNavigator: true);
              Navigator.of(context).pop();
              RewardFlyOverlay.show(rootNav.context, coins: 100, gems: 50);
            },
            child: const Text('PLAY CURRENCY FLY'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              // Queue a real challenge prize; the home challenge card fills
              // its bar and flies the prize in place when Home is shown.
              context.read<EconomyState>().debugWinChallengePrize();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Challenge prize queued — open Home to watch.'),
                ),
              );
            },
            child: const Text('WIN CHALLENGE PRIZE'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Monetization launcher — pick any of the 14 popup configs and render it
// with the current remote config data. Background art falls back to the
// dev placeholder when the popup_bg key has no registered asset.
// =============================================================================
class _MonetizationLauncher extends StatefulWidget {
  const _MonetizationLauncher();

  @override
  State<_MonetizationLauncher> createState() => _MonetizationLauncherState();
}

class _MonetizationLauncherState extends State<_MonetizationLauncher> {
  String? _selected;

  /// All known monetization asset IDs across the 3 format files. Kept as
  /// a static list because the popup configs already declare every
  /// active asset by name — this just gives the dropdown its options.
  static const List<_MonetizationEntry> _entries = [
    _MonetizationEntry('fto',                'ThreePlusOne'),
    // first_purchase is an any-purchase bonus (no own SKU) — surfaced via
    // a different flow, intentionally not a launchable offer here.
    _MonetizationEntry('1+2_ironsky',        'ThreePlusOne'),
    _MonetizationEntry('1+2_laststand',      'ThreePlusOne'),
    _MonetizationEntry('1+2_goldensky',      'ThreePlusOne'),
    _MonetizationEntry('1+2_starascent',     'ThreePlusOne'),
    _MonetizationEntry('snake_ironsky',      'Snake'),
    _MonetizationEntry('snake_laststand',    'Snake'),
    _MonetizationEntry('snake_goldensky',    'Snake'),
    _MonetizationEntry('snake_starascent',   'Snake'),
    _MonetizationEntry('generic_ironsky',    'Generic'),
    _MonetizationEntry('generic_laststand',  'Generic'),
    _MonetizationEntry('generic_goldensky',  'Generic'),
    _MonetizationEntry('generic_starascent', 'Generic'),
  ];

  void _show() {
    final id = _selected;
    if (id == null) return;
    final format = _entries.firstWhere((e) => e.assetId == id).format;
    switch (format) {
      case 'ThreePlusOne':
        ThreePlusOneOfferPopup.show(context, assetId: id);
        break;
      case 'Snake':
        SnakeOfferPopup.show(context, assetId: id);
        break;
      case 'Generic':
        GenericOfferPopup.show(context, assetId: id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final config = selected == null
        ? null
        : RemoteConfigService.I.monetization.configByAssetName(selected);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Monetization popup',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Launch any of the 14 configured offers using live Remote Config data. '
            'Missing popup_bg art falls back to the dev placeholder.',
            style: AppTypography.label,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(
              filled: true,
              fillColor: AppColors.cardBg,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            dropdownColor: AppColors.cardBg,
            style: AppTypography.bodyPale,
            hint: const Text('Select asset…', style: AppTypography.bodyPale),
            items: [
              for (final e in _entries)
                DropdownMenuItem(
                  value: e.assetId,
                  child: Text(
                    '${e.assetId}  · ${e.format}',
                    style: AppTypography.bodyPale,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _selected = v),
          ),
          if (config != null) ...[
            const SizedBox(height: 6),
            Text(
              'display_name: ${config.displayName}\n'
              'popup_bg: ${config.popupBg}\n'
              'cycle: ${config.triggerChallengeId}\n'
              'unlock_level: ${config.unlockLevel}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: _selected == null ? null : _show,
            child: const Text('SHOW POPUP'),
          ),
        ],
      ),
    );
  }
}

class _MonetizationEntry {
  final String assetId;
  final String format;
  const _MonetizationEntry(this.assetId, this.format);
}
