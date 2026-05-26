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

  const AppTopBar.full({
    super.key,
    bool forceShowCoin = false,
  })  : _variant = _Variant.full,
        _title = null,
        _onClose = null,
        _forceShowCoin = forceShowCoin;

  const AppTopBar.close({
    super.key,
    required VoidCallback onClose,
    bool forceShowCoin = false,
  })  : _variant = _Variant.close,
        _title = null,
        _onClose = onClose,
        _forceShowCoin = forceShowCoin;

  const AppTopBar.titleOnly({
    super.key,
    required String title,
    required VoidCallback onClose,
  })  : _variant = _Variant.titleOnly,
        _title = title,
        _onClose = onClose,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _CloseButton(onTap: _onClose!),
          ),
          Text(
            _title!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 6,
            ),
          ),
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
          _LvChip(level: economy.level),
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
            color: AppColors.greenPale,
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
              color: AppColors.greenPale,
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
