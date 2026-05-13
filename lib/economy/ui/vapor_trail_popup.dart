import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/asset_placeholder.dart';

/// "Vapor Trail" progression-pass offer popup. The player accumulates
/// trail tokens by playing missions and unlocks a chain of rewards.
///
/// Layout: header banner + timer, progress bar (tokens collected vs.
/// next tier), and six reward tiles laid out in a 2-column zigzag.
/// One premium tile uses a paid price button; the rest are FREE behind
/// trail-token costs.
///
/// All numbers + asset paths are placeholders — wire to remote config
/// later. The tile container art is intentionally a coloured rectangle
/// today; swap to `Image.asset(...)` once the user drops in the
/// rewards container PNG.
class VaporTrailPopup extends StatefulWidget {
  const VaporTrailPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const VaporTrailPopup(),
    );
  }

  @override
  State<VaporTrailPopup> createState() => _VaporTrailPopupState();
}

class _VaporTrailPopupState extends State<VaporTrailPopup> {
  Timer? _ticker;
  Duration _remaining = const Duration(hours: 5, minutes: 9, seconds: 4);

  // ---------------------------------------------------------------------------
  // Placeholder offer data
  // ---------------------------------------------------------------------------

  /// The trail-token currency icon. Reuses an existing asset until we
  /// ship a custom token. Real value comes from remote config.
  static const String _tokenAsset = 'assets/ui/icon_gem.png';
  static const int _tokensCollected = 0;
  static const int _tokensToNextTier = 50;

  /// Final tier reward (right end of progress bar — the milestone the
  /// progress fills toward).
  static const _TrailReward _tierReward = _TrailReward(
    asset: 'assets/ui/icon_chest_operation.png',
    amount: '20',
  );

  /// Tiles in the trail. Index 0 = first/cheapest, index 5 = furthest.
  /// `priceLabel` non-null = paid tile; null = FREE behind tokens.
  static const List<_TrailTile> _tiles = [
    _TrailTile(
      asset: 'assets/ui/icon_chest_rare.png',
      amount: '300',
      priceLabel: '\$9.99',
      tokenCost: 15,
    ),
    _TrailTile(
      asset: 'assets/ui/icon_coin.png',
      amount: '4',
      priceLabel: null,
      tokenCost: 3,
    ),
    _TrailTile(
      asset: 'assets/ui/icon_coin.png',
      amount: '4',
      priceLabel: null,
      tokenCost: 3,
    ),
    _TrailTile(
      asset: 'assets/ui/icon_chest_basic.png',
      amount: '4',
      priceLabel: null,
      tokenCost: 3,
    ),
    _TrailTile(
      asset: 'assets/ui/icon_coin.png',
      amount: '4',
      priceLabel: null,
      tokenCost: 3,
    ),
    _TrailTile(
      asset: 'assets/ui/icon_chest_epic.png',
      amount: '4',
      priceLabel: null,
      tokenCost: 3,
    ),
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

  String _formatRemaining(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Transparent popup — tiles, title banner, and progress bar float
    // independently on top of the dimmed barrier (matches the design
    // reference where the offer has no opaque outer window).
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ends in ${_formatRemaining(_remaining)}',
                    style: const TextStyle(
                      color: AppColors.amberLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Color(0xCC000000),
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _TitleBanner(title: 'VAPOR TRAIL'),
                  const SizedBox(height: 14),
                  const _TierProgressBar(
                    tokenAsset: _tokenAsset,
                    tokensCollected: _tokensCollected,
                    tokensToNextTier: _tokensToNextTier,
                    tierReward: _tierReward,
                  ),
                  const SizedBox(height: 18),
                  const _TrailGrid(tiles: _tiles, tokenAsset: _tokenAsset),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _CloseButton(onTap: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }
}

class _TrailTile {
  final String asset;
  final String amount;

  /// When non-null, this tile is the premium IAP slot. Null = FREE
  /// gated by trail tokens.
  final String? priceLabel;
  final int tokenCost;

  const _TrailTile({
    required this.asset,
    required this.amount,
    required this.priceLabel,
    required this.tokenCost,
  });
}

class _TrailReward {
  final String asset;
  final String amount;
  const _TrailReward({required this.asset, required this.amount});
}

// ---------------------------------------------------------------------------
// Title banner
// ---------------------------------------------------------------------------
class _TitleBanner extends StatelessWidget {
  final String title;

  const _TitleBanner({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.amber, width: 1),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.amber,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.0,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar — current tokens vs. next-tier threshold, with tier
// reward icon hanging off the right end (matches the challenge card's
// prize-overlay pattern).
// ---------------------------------------------------------------------------
class _TierProgressBar extends StatelessWidget {
  static const double _barHeight = 18;
  static const double _iconSize = 30;
  static const double _overlapFraction = 0.10;

  final String tokenAsset;
  final int tokensCollected;
  final int tokensToNextTier;
  final _TrailReward tierReward;

  const _TierProgressBar({
    required this.tokenAsset,
    required this.tokensCollected,
    required this.tokensToNextTier,
    required this.tierReward,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = tokensToNextTier > 0
        ? (tokensCollected / tokensToNextTier).clamp(0.0, 1.0).toDouble()
        : 0.0;
    const barRightInset = _iconSize * (1 - _overlapFraction);

    return SizedBox(
      height: _iconSize,
      child: LayoutBuilder(builder: (ctx, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Token icon on the left
            Positioned(
              left: 0,
              top: 0,
              width: _iconSize,
              height: _iconSize,
              child: Image.asset(
                tokenAsset,
                errorBuilder: AssetPlaceholder.image(
                  color: AppColors.amber,
                  label: 'token',
                  borderRadius: 4,
                ),
              ),
            ),
            // Bar (between icons)
            Positioned(
              left: _iconSize + 6,
              right: barRightInset,
              top: (_iconSize - _barHeight) / 2,
              height: _barHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  children: [
                    Container(color: const Color(0xFF0D1A0D)),
                    LayoutBuilder(builder: (ctx, c) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: c.maxWidth * fraction,
                        decoration: const BoxDecoration(color: AppColors.green),
                      );
                    }),
                    Center(
                      child: Text(
                        '$tokensCollected/$tokensToNextTier',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: Color(0xCC000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tier reward icon at the right end (10% overlap on bar)
            Positioned(
              right: 0,
              top: 0,
              width: _iconSize,
              height: _iconSize,
              child: Image.asset(
                tierReward.asset,
                errorBuilder: AssetPlaceholder.image(
                  color: AppColors.amber,
                  label: 'tier',
                  borderRadius: 4,
                ),
              ),
            ),
            // Tier amount badge under the icon
            Positioned(
              right: 0,
              bottom: -14,
              width: _iconSize,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.amber, width: 0.6),
                  ),
                  child: Text(
                    tierReward.amount,
                    style: const TextStyle(
                      color: AppColors.greenPale,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile grid (2 columns × 3 rows). Tiles use the cycle-specific container
// artwork as their background; content overlays inside the artwork's
// inner "sky window" via Positioned + percentage insets.
// ---------------------------------------------------------------------------
const String _kTileBgAsset = 'assets/ui/home/snake_offer_iron_skies.png';

// Tile size — matches the source artwork's 2:3 portrait aspect (1024 ×
// 1536 px). On iPhone 17 Pro this lays 2 tiles per row inside the
// dialog inset with a small horizontal gap.
const double _kTileWidth = 140;
const double _kTileHeight = 210;

// The artwork's inner sky-window content area, expressed as fractions of
// the tile bounds. Measured off the source PNG.
const double _kTileInsetH = 0.12;
const double _kTileInsetTop = 0.14;
const double _kTileInsetBottom = 0.10;

class _TrailGrid extends StatelessWidget {
  final List<_TrailTile> tiles;
  final String tokenAsset;

  const _TrailGrid({required this.tiles, required this.tokenAsset});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      final left = tiles[i];
      final right = i + 1 < tiles.length ? tiles[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TrailTileCard(tile: left, tokenAsset: tokenAsset),
              if (right == null)
                const SizedBox(width: _kTileWidth, height: _kTileHeight)
              else
                _TrailTileCard(tile: right, tokenAsset: tokenAsset),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _TrailTileCard extends StatelessWidget {
  final _TrailTile tile;
  final String tokenAsset;

  const _TrailTileCard({required this.tile, required this.tokenAsset});

  @override
  Widget build(BuildContext context) {
    final isPaid = tile.priceLabel != null;
    return SizedBox(
      width: _kTileWidth,
      height: _kTileHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _kTileBgAsset,
              fit: BoxFit.fill,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.surfaceDark,
                label: 'tile',
                borderRadius: 14,
              ),
            ),
          ),
          Positioned(
            top: _kTileHeight * _kTileInsetTop,
            bottom: _kTileHeight * _kTileInsetBottom,
            left: _kTileWidth * _kTileInsetH,
            right: _kTileWidth * _kTileInsetH,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Image.asset(
                        tile.asset,
                        errorBuilder: AssetPlaceholder.image(
                          color: AppColors.amber,
                          label: 'reward',
                          borderRadius: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tile.amount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
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
                ),
                const Text(
                  '1/1 Available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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
                Row(
                  children: [
                    Expanded(
                      child: isPaid
                          ? _PriceButton(label: tile.priceLabel!)
                          : const _FreeLockedButton(),
                    ),
                    const SizedBox(width: 4),
                    _TokenCostChip(tokenAsset: tokenAsset, cost: tile.tokenCost),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  final String label;

  const _PriceButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6FAD1F), AppColors.green],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.greenLight, width: 0.8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FreeLockedButton extends StatelessWidget {
  const _FreeLockedButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.amber, width: 0.6),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'FREE',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(width: 3),
          Icon(Icons.lock, color: AppColors.amber, size: 12),
        ],
      ),
    );
  }
}

class _TokenCostChip extends StatelessWidget {
  final String tokenAsset;
  final int cost;

  const _TokenCostChip({required this.tokenAsset, required this.cost});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.6), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Image.asset(
              tokenAsset,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amber,
                label: 'tok',
                borderRadius: 2,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$cost',
            style: const TextStyle(
              color: AppColors.amberLight,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Close button
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
