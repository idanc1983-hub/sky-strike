import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../economy/state/economy_state.dart';
import '../../screens/menu_popup.dart';
import '../theme/app_colors.dart';
import 'asset_placeholder.dart';

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

  /// Optional 5-second long-press handler wired to a single hidden letter
  /// inside the title (the first 'G'). Used by Settings to surface the
  /// debug-only Dev Tools sheet without a visible affordance.
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
          // Right cluster: currencies
          if (showCoin) ...[
            _CurrencyChip(
              amount: economy.coins,
              asset: 'assets/ui/icon_coin.png',
              placeholderLabel: 'coin',
              placeholderColor: AppColors.amber,
            ),
            const SizedBox(width: 8),
          ],
          _CurrencyChip(
            amount: economy.gems,
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

class _CurrencyChip extends StatelessWidget {
  final int amount;
  final String asset;
  final String placeholderLabel;
  final Color placeholderColor;

  const _CurrencyChip({
    required this.amount,
    required this.asset,
    required this.placeholderLabel,
    required this.placeholderColor,
  });

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$amount',
            style: const TextStyle(
              color: AppColors.amber,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 18,
            height: 18,
            child: Image.asset(
              asset,
              errorBuilder: AssetPlaceholder.image(
                color: placeholderColor,
                label: placeholderLabel,
                borderRadius: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the title as a RichText with a 5-second long-press recognizer
/// attached to the first 'G'. The hit target is intentionally a single
/// glyph — this is a dev-only hook, not a discoverable UI affordance.
class _SecretHoldTitle extends StatefulWidget {
  final String title;
  final TextStyle style;
  final VoidCallback onSecretHold;

  const _SecretHoldTitle({
    required this.title,
    required this.style,
    required this.onSecretHold,
  });

  @override
  State<_SecretHoldTitle> createState() => _SecretHoldTitleState();
}

class _SecretHoldTitleState extends State<_SecretHoldTitle> {
  late final LongPressGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = LongPressGestureRecognizer(
      duration: const Duration(seconds: 5),
    )..onLongPress = widget.onSecretHold;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secretIndex = widget.title.indexOf('G');
    if (secretIndex < 0) {
      return Text(widget.title, textAlign: TextAlign.center, style: widget.style);
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: widget.title.substring(0, secretIndex)),
          TextSpan(text: widget.title[secretIndex], recognizer: _recognizer),
          TextSpan(text: widget.title.substring(secretIndex + 1)),
        ],
      ),
    );
  }
}

/// Common chip shell: dark fill, thin amber border, ~32 tall, optional tap.
class _ChipShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const _ChipShell({
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
