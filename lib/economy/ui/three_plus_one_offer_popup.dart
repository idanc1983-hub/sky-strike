import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';

const String _kPopupBgAsset = 'assets/ui/home/1plus3_popup_iron_skies.png';

// Aspect ratio of the popup background art. Matches the source PNG
// (862 × 1824) so the artwork displays without distortion.
const double _kPopupAspect = 862 / 1824;

// Vertical position of the title ribbon's centre, as a fraction of the
// background image's height. Used to overlay the cycle/sale name.
const double _kRibbonFraction = 0.066;

// Cycle/sale name overlaid on the ribbon. Today this is hardcoded to
// match the bundled Iron Skies artwork; when the cycle plumbing lands,
// read the value from `RemoteConfigService.challengesCyclePlan()`.
const String _kSaleName = 'IRON SKIES';

/// "Last Chance — 1+3" offer popup.
///
/// Layout matches the design reference: a 3-column × 3-row reward grid.
/// Column 1 is the paid pack (single price button). Columns 2 and 3 are
/// the "+3 FREE" bonus packs, locked until the previous pack is claimed.
///
/// Placeholder data lives in this file as `static const` lists. When the
/// offer plumbing reaches remote config, swap them for parsed entries.
class ThreePlusOneOfferPopup extends StatefulWidget {
  const ThreePlusOneOfferPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const ThreePlusOneOfferPopup(),
    );
  }

  @override
  State<ThreePlusOneOfferPopup> createState() =>
      _ThreePlusOneOfferPopupState();
}

class _ThreePlusOneOfferPopupState extends State<ThreePlusOneOfferPopup> {
  Timer? _ticker;
  Duration _remaining = const Duration(hours: 41, minutes: 9, seconds: 36);

  // ---------------------------------------------------------------------------
  // Placeholder data. Real offer comes from remote config.
  // ---------------------------------------------------------------------------
  static const String _priceLabel = '\$9.99';

  /// Index 0 = paid pack, 1 = first free pack, 2 = second free pack.
  static const List<List<_OfferReward>> _columns = [
    [
      _OfferReward(asset: 'assets/ui/icon_chest_rare.png', amount: '250'),
      _OfferReward(asset: 'assets/ui/icon_coin.png', amount: '700K'),
      _OfferReward(asset: 'assets/ui/icon_coin.png', amount: '125M'),
    ],
    [
      _OfferReward(asset: 'assets/ui/icon_chest_basic.png', amount: ''),
      _OfferReward(asset: 'assets/ui/icon_chest_epic.png', amount: ''),
      _OfferReward(asset: 'assets/ui/icon_chest_operation.png', amount: ''),
    ],
    [
      _OfferReward(asset: 'assets/ui/icon_chest_rare.png', amount: ''),
      _OfferReward(asset: 'assets/ui/icon_gem.png', amount: ''),
      _OfferReward(asset: 'assets/ui/icon_coin.png', amount: '1'),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining = _remaining - const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: AspectRatio(
        aspectRatio: _kPopupAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  _kPopupBgAsset,
                  fit: BoxFit.fill,
                  errorBuilder: AssetPlaceholder.image(
                    color: AppColors.cardBg,
                    label: '1plus3_bg',
                    borderRadius: 18,
                  ),
                ),
              ),
              // Sale name overlaid on the ribbon area (top ~7%).
              LayoutBuilder(builder: (ctx, constraints) {
                final ribbonY = constraints.maxHeight * _kRibbonFraction;
                return Positioned(
                  top: ribbonY - 12,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      _kSaleName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.4,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: Color(0xCC000000),
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // Body content sits below the biplane/jet art and above
              // the bottom edge.
              LayoutBuilder(builder: (ctx, constraints) {
                final topPad = constraints.maxHeight * 0.17;
                final bottomPad = constraints.maxHeight * 0.04;
                return Positioned(
                  top: topPad,
                  bottom: bottomPad,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        children: [
                          Text(
                            '1 + 3',
                            style: TextStyle(
                              color: AppColors.amberLight,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: Color(0xCC000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'BUY 1 & GET 3 FREE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              shadows: [
                                Shadow(
                                  color: Color(0xCC000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const _RewardGrid(columns: _columns),
                      Column(
                        children: [
                          const _BuyRow(priceLabel: _priceLabel),
                          const SizedBox(height: 10),
                          _CountdownLabel(remaining: _remaining),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              Positioned(
                top: 8,
                right: 8,
                child: _CloseButton(onTap: () => Navigator.of(context).pop()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferReward {
  final String asset;
  final String amount;
  const _OfferReward({required this.asset, required this.amount});
}

// ---------------------------------------------------------------------------
// 3 × 3 reward grid
// ---------------------------------------------------------------------------
class _RewardGrid extends StatelessWidget {
  final List<List<_OfferReward>> columns;

  const _RewardGrid({required this.columns});

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight resolves the Row's natural height first so that
    // `CrossAxisAlignment.stretch` can match the columns without
    // demanding the parent's unbounded vertical space (we live inside
    // a SingleChildScrollView).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int colIndex = 0; colIndex < columns.length; colIndex++) ...[
            Expanded(
              child: _RewardColumn(
                rewards: columns[colIndex],
                isPaid: colIndex == 0,
              ),
            ),
            if (colIndex < columns.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.add,
                  color: AppColors.amber,
                  size: 18,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RewardColumn extends StatelessWidget {
  final List<_OfferReward> rewards;
  final bool isPaid;

  const _RewardColumn({required this.rewards, required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isPaid
            ? const Color(0xFF173404).withValues(alpha: 0.85)
            : AppColors.surfaceDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPaid ? AppColors.greenLight : AppColors.amber,
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rewards.length; i++) ...[
            _RewardCell(reward: rewards[i]),
            if (i < rewards.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _RewardCell extends StatelessWidget {
  final _OfferReward reward;

  const _RewardCell({required this.reward});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Image.asset(
            reward.asset,
            errorBuilder: AssetPlaceholder.image(
              color: AppColors.amber,
              label: 'reward',
              borderRadius: 4,
            ),
          ),
        ),
        if (reward.amount.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            reward.amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Color(0xCC000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom row of buttons: one price + two FREE+lock placeholders
// ---------------------------------------------------------------------------
class _BuyRow extends StatelessWidget {
  final String priceLabel;

  const _BuyRow({required this.priceLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _PriceButton(label: priceLabel)),
        const SizedBox(width: 6),
        const Expanded(child: _LockedFreeButton()),
        const SizedBox(width: 6),
        const Expanded(child: _LockedFreeButton()),
      ],
    );
  }
}

class _PriceButton extends StatelessWidget {
  final String label;

  const _PriceButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6FAD1F), AppColors.green],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greenLight, width: 0.8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LockedFreeButton extends StatelessWidget {
  const _LockedFreeButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber, width: 0.6),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'FREE',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.lock, color: AppColors.amber, size: 14),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Countdown footer
// ---------------------------------------------------------------------------
class _CountdownLabel extends StatelessWidget {
  final Duration remaining;

  const _CountdownLabel({required this.remaining});

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ends in ${_format(remaining)}',
      style: const TextStyle(
        color: AppColors.greenPale,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top-right close button
// ---------------------------------------------------------------------------
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceDark,
          border: Border.all(color: AppColors.amber, width: 0.8),
        ),
        child: const Icon(
          Icons.close,
          color: AppColors.amberLight,
          size: 16,
        ),
      ),
    );
  }
}
