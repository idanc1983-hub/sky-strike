import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/asset_placeholder.dart';
import '../../models/bundle_price.dart';

/// Pill-shaped CTA showing the bundle's cost. Tapping fires [onTap].
///
/// Internally manages its own loading-spinner / shake-on-error state
/// (driven by an [AnimationController]) so the parent card stays simple.
class BundlePriceButton extends StatefulWidget {
  final BundlePrice price;
  final Color accent;
  final Future<bool> Function() onTap;

  const BundlePriceButton({
    super.key,
    required this.price,
    required this.accent,
    required this.onTap,
  });

  @override
  State<BundlePriceButton> createState() => _BundlePriceButtonState();
}

class _BundlePriceButtonState extends State<BundlePriceButton>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _justSucceeded = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.onTap();
    } catch (_) {
      // A throwing onTap callback would otherwise leave the button
      // permanently busy. Treat as a failed purchase.
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      setState(() {
        _busy = false;
        _justSucceeded = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _justSucceeded = false);
    } else {
      _shake.forward(from: 0);
      setState(() => _busy = false);
    }
  }

  String _label() {
    final p = widget.price;
    if (p.type == BundlePriceType.gems) {
      return '${p.gemCost ?? 0}';
    }
    final usd = p.usdEquivalent;
    return usd == null ? 'Buy' : '\$${usd.toStringAsFixed(2)}';
  }

  Widget _icon() {
    if (widget.price.type == BundlePriceType.gems) {
      return SizedBox(
        width: 16,
        height: 16,
        child: Image.asset(
          'assets/ui/icon_gem.png',
          fit: BoxFit.contain,
          errorBuilder: AssetPlaceholder.image(
            color: AppColors.amber,
            label: 'gem',
            borderRadius: 3,
          ),
        ),
      );
    }
    return const SizedBox(width: 0, height: 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.price;
    final hasCompare = p.hasCompare;
    return AnimatedBuilder(
      animation: _shake,
      builder: (ctx, child) {
        final dx = _shake.value == 0
            ? 0.0
            : 6.0 * (_shake.value < 0.5 ? _shake.value * 2 : (1 - _shake.value) * 2) *
                ((_shake.value * 8).floor().isEven ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.accent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else if (_justSucceeded)
                const Icon(Icons.check, color: Colors.white, size: 16)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasCompare) ...[
                      Text(
                        p.type == BundlePriceType.gems
                            ? '${p.compareGems}'
                            : '\$${p.compareUsd!.toStringAsFixed(2)}',
                        style: AppTypography.compareText.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _icon(),
                    if (p.type == BundlePriceType.gems) const SizedBox(width: 4),
                    Text(_label(), style: AppTypography.priceText),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
