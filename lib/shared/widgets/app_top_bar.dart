import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../economy/state/economy_state.dart';
import '../../screens/menu_popup.dart';
import '../theme/app_colors.dart';
import 'asset_placeholder.dart';
import 'currency_anchors.dart';

/// Shared top bar used across every screen in the redesign.
///
/// Three variants:
/// - [AppTopBar.full]      — ☰ menu + Lv + coins + gems        (Home, Shop, Jets,
///                                                              Social, Pause,
///                                                              Mission Failed,
///                                                              Stage Complete,
///                                                              Biome Complete)
/// - [AppTopBar.close]     — X close + Lv + coins + gems       (Daily Reward)
/// - [AppTopBar.titleOnly] — X close + centered title          (Settings)
class AppTopBar extends StatelessWidget {
  final _Variant _variant;
  final String? _title;
  final VoidCallback? _onClose;

  /// In full/close variants, hides the coin chip when the player is
  /// pre-FTUE (no stage 1 clear yet). Defaults to honoring
  /// [EconomyState.showHomeBalance]; set true to force-show on screens
  /// where the FTUE rule doesn't apply (pause/result overlays).
  final bool _forceShowCoin;

  /// Optional long-press handler wired to the whole title word. Used by
  /// Settings to surface the debug-only Dev Tools sheet without a visible
  /// affordance.
  final VoidCallback? _onTitleSecretHold;

  const AppTopBar.full({
    super.key,
    bool forceShowCoin = true,
  })  : _variant = _Variant.full,
        _title = null,
        _onClose = null,
        _onTitleSecretHold = null,
        _forceShowCoin = forceShowCoin;

  const AppTopBar.close({
    super.key,
    required VoidCallback onClose,
    bool forceShowCoin = true,
  })  : _variant = _Variant.close,
        _title = null,
        _onClose = onClose,
        _onTitleSecretHold = null,
        _forceShowCoin = forceShowCoin;

  const AppTopBar.titleOnly({
    super.key,
    required String title,
    required VoidCallback onClose,
    VoidCallback? onTitleSecretHold,
  })  : _variant = _Variant.titleOnly,
        _title = title,
        _onClose = onClose,
        _onTitleSecretHold = onTitleSecretHold,
        _forceShowCoin = false;

  @override
  Widget build(BuildContext context) {
    if (_variant == _Variant.titleOnly) {
      return _buildTitleOnly(context);
    }
    final economy = context.watch<EconomyState>();
    return _buildWithChips(context, economy);
  }

  Widget _buildTitleOnly(BuildContext context) {
    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 6,
    );
    final secretHold = _onTitleSecretHold;
    final titleChild = secretHold == null
        ? Text(_title!, textAlign: TextAlign.center, style: titleStyle)
        : _SecretHoldTitle(
            title: _title!,
            style: titleStyle,
            onSecretHold: secretHold,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          _CloseButton(onTap: _onClose!),
          Expanded(child: titleChild),
          // Mirror the close-button footprint on the right so the title
          // ends up visually centred in the full bar width.
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildWithChips(BuildContext context, EconomyState economy) {
    final showCoin = _forceShowCoin || economy.showHomeBalance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          // Left cluster: menu/close + Lv chip
          if (_variant == _Variant.full)
            _MenuButton(onTap: () => MenuPopup.show(context))
          else
            _CloseButton(onTap: _onClose!),
          const SizedBox(width: 8),
          // Lv. is a global linear stage count across biomes
          // (10 stages per biome → World 2 Stage 1 = Lv. 11).
          _LvChip(level: (economy.currentWorld - 1) * 10 + economy.currentStage),
          const Spacer(),
          // Right cluster: currencies. Shows the *display* balance, which
          // trails the real balance while a reward celebration flies in.
          if (showCoin) ...[
            _CurrencyChip(
              kind: _CurrencyKind.coin,
              amount: economy.displayCoins,
              asset: 'assets/ui/icon_coin.png',
              placeholderLabel: 'coin',
              placeholderColor: AppColors.amber,
            ),
            const SizedBox(width: 8),
          ],
          _CurrencyChip(
            kind: _CurrencyKind.gem,
            amount: economy.displayGems,
            asset: 'assets/ui/icon_gem.png',
            placeholderLabel: 'gem',
            placeholderColor: const Color(0xFF7BB8FF),
          ),
        ],
      ),
    );
  }
}

enum _Variant { full, close, titleOnly }

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      onTap: onTap,
      child: const Icon(Icons.menu, color: AppColors.greenPale, size: 20),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      onTap: onTap,
      child: const Icon(Icons.close, color: AppColors.greenPale, size: 20),
    );
  }
}

class _LvChip extends StatelessWidget {
  final int level;
  const _LvChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Lv. $level',
          style: const TextStyle(
            color: AppColors.amber,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

enum _CurrencyKind { coin, gem }

class _CurrencyChip extends StatefulWidget {
  final _CurrencyKind kind;
  final int amount;
  final String asset;
  final String placeholderLabel;
  final Color placeholderColor;

  const _CurrencyChip({
    required this.kind,
    required this.amount,
    required this.asset,
    required this.placeholderLabel,
    required this.placeholderColor,
  });

  @override
  State<_CurrencyChip> createState() => _CurrencyChipState();
}

class _CurrencyChipState extends State<_CurrencyChip> {
  final GlobalKey _key = GlobalKey();
  // Value the rolling count animates *from* — the last value we displayed.
  late int _shownAmount = widget.amount;

  @override
  void initState() {
    super.initState();
    CurrencyAnchors.refresh.addListener(_reportAnchor);
    _reportAnchor();
  }

  @override
  void didUpdateWidget(_CurrencyChip old) {
    super.didUpdateWidget(old);
    _reportAnchor();
  }

  @override
  void dispose() {
    CurrencyAnchors.refresh.removeListener(_reportAnchor);
    super.dispose();
  }

  /// Publishes this chip's on-screen centre so reward-fly overlays can aim
  /// at the real holder. Runs after layout each build, and again whenever a
  /// refresh is requested. Only the bar on the *current* route publishes —
  /// covered routes and off-screen [IndexedStack] tabs must not overwrite
  /// the anchor with a stale position.
  void _reportAnchor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final center =
          box.localToGlobal(box.size.center(Offset.zero));
      switch (widget.kind) {
        case _CurrencyKind.coin:
          CurrencyAnchors.coin = center;
          break;
        case _CurrencyKind.gem:
          CurrencyAnchors.gem = center;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final from = _shownAmount;
    _shownAmount = widget.amount;
    return _ChipShell(
      key: _key,
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rolling count-up so the holder visibly ticks up as coins land.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: from.toDouble(),
              end: widget.amount.toDouble(),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (_, value, __) => Text(
              '${value.round()}',
              style: const TextStyle(
                color: AppColors.amber,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 18,
            height: 18,
            child: Image.asset(
              widget.asset,
              errorBuilder: AssetPlaceholder.image(
                color: widget.placeholderColor,
                label: widget.placeholderLabel,
                borderRadius: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the title with a long-press recognizer covering the whole
/// word. There's no visible affordance — this is a dev-only hook, so the
/// hit target is just the title text itself.
class _SecretHoldTitle extends StatelessWidget {
  final String title;
  final TextStyle style;
  final VoidCallback onSecretHold;

  const _SecretHoldTitle({
    required this.title,
    required this.style,
    required this.onSecretHold,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onSecretHold,
      child: Text(title, textAlign: TextAlign.center, style: style),
    );
  }
}

/// Common chip shell: dark fill, thin amber border, ~32 tall, optional tap.
class _ChipShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const _ChipShell({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      height: 32,
      constraints: const BoxConstraints(minWidth: 36),
      alignment: Alignment.center,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1606).withValues(alpha: 0.92),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: child,
    );
    if (onTap == null) return inner;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: inner,
    );
  }
}
