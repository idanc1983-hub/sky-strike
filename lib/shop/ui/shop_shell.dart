import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../economy/state/economy_state.dart';
import '../../shared/widgets/asset_placeholder.dart';
import '../models/bundle_content.dart';
import '../models/player_segment.dart';
import '../models/shop_bundle.dart';
import '../services/bundle_service.dart';
import '../services/mock_bundle_repository.dart';
import '../state/shop_state.dart';
import 'widgets/bundle_compact_card.dart';
import 'widgets/bundle_contents_grid.dart';
import 'widgets/bundle_hero_card.dart';

/// Top-level shop screen. Renders cached bundles instantly, fetches in
/// background, and surfaces an amber banner when a fetch fails.
class ShopShell extends StatefulWidget {
  const ShopShell({super.key});

  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  PageController? _pageController;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    _pageController?.dispose();
    _pageController = null;
    super.dispose();
  }

  void _ensureCarouselTimer(int featuredCount) {
    if (featuredCount <= 1) {
      _carouselTimer?.cancel();
      _carouselTimer = null;
      return;
    }
    if (_carouselTimer != null) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _pageController == null || !_pageController!.hasClients) {
        return;
      }
      final state = context.read<ShopState>();
      final next = (state.carouselPage + 1) % featuredCount;
      _pageController!.animateToPage(
        next,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<ShopBundle> _filteredForTab(List<ShopBundle> all, ShopTab tab) {
    switch (tab) {
      case ShopTab.bundles:
        return all;
      case ShopTab.gems:
        return all
            .where((b) => b.contents
                .any((c) => c.type == BundleContentType.gems))
            .toList();
      case ShopTab.powerups:
        return all
            .where((b) => b.contents
                .any((c) => c.type == BundleContentType.powerup))
            .toList();
      case ShopTab.jets:
        return all
            .where((b) => b.contents.any((c) =>
                c.type == BundleContentType.jet ||
                c.type == BundleContentType.jetSkin))
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<BundleService>();
    final shopState = context.watch<ShopState>();
    final all = service.visibleBundles;
    final tabFiltered = _filteredForTab(all, shopState.selectedTab);
    final featured = tabFiltered.take(3).toList();
    final compactList =
        tabFiltered.length > featured.length ? tabFiltered.sublist(featured.length) : <ShopBundle>[];

    _ensureCarouselTimer(featured.length);

    return Scaffold(
      backgroundColor: AppColors.greenDeep,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(player: service.player),
            if (service.lastError != null && all.isNotEmpty)
              _StaleCacheBanner(onTap: () => service.refresh()),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.green,
                backgroundColor: AppColors.cardBg,
                onRefresh: () => service.refresh(),
                child: _Body(
                  isLoading: service.isLoading && all.isEmpty,
                  emptyAndErrored:
                      all.isEmpty && service.lastError != null && !service.isLoading,
                  empty: all.isEmpty && !service.isLoading,
                  featured: featured,
                  compact: compactList,
                  pageController: _pageController!,
                  onPurchase: (id) async {
                    return service.attemptPurchase(id);
                  },
                  onCarouselPage: (i) =>
                      context.read<ShopState>().setCarouselPage(i),
                  onRefresh: () => service.refresh(),
                ),
              ),
            ),
            _CategoryTabs(
              selected: shopState.selectedTab,
              onSelect: (t) => context.read<ShopState>().selectTab(t),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final PlayerSegmentData player;
  const _TopBar({required this.player});

  @override
  Widget build(BuildContext context) {
    final segments = player.segments;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.greenLight),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Center(
              child: Text('Shop', style: AppTypography.title),
            ),
          ),
          GestureDetector(
            onLongPress: () => _showDebugSheet(context, segments),
            child: const _GemChip(),
          ),
        ],
      ),
    );
  }

  void _showDebugSheet(BuildContext context, List<String> currentSegments) {
    final service = context.read<BundleService>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Shop debug overlay', style: AppTypography.title),
              const SizedBox(height: 8),
              Text(
                'Active segments: ${currentSegments.join(", ")}',
                style: AppTypography.bodyPale,
              ),
              Text(
                'Visible bundles: ${service.visibleBundles.length}',
                style: AppTypography.bodyPale,
              ),
              if (service.lastError != null)
                Text(
                  'lastError: ${service.lastError}',
                  style: AppTypography.errorBanner,
                ),
              const Divider(color: AppColors.greenTrack),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SegmentChip(
                    label: 'new_player',
                    onTap: () {
                      service.debugSetSegments(['new_player', 'world_1_active']);
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                  _SegmentChip(
                    label: 'whales',
                    onTap: () {
                      service.debugSetSegments(['whales']);
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                  _SegmentChip(
                    label: 'lapsed_7d',
                    onTap: () {
                      service.debugSetSegments(['lapsed_7d']);
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                  _SegmentChip(
                    label: 'force fetch failure',
                    onTap: () {
                      final repo = service.repository;
                      if (repo is MockBundleRepository) {
                        repo.setFailureMode(true);
                      }
                      service.refresh();
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                  _SegmentChip(
                    label: 'recover',
                    onTap: () {
                      final repo = service.repository;
                      if (repo is MockBundleRepository) {
                        repo.setFailureMode(false);
                      }
                      service.refresh();
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SegmentChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.surfaceDark,
      labelStyle: AppTypography.bodyPale,
      side: const BorderSide(color: AppColors.green, width: 0.5),
      onPressed: onTap,
    );
  }
}

class _GemChip extends StatelessWidget {
  const _GemChip();

  @override
  Widget build(BuildContext context) {
    // Read EconomyState if it's available — the shop is reachable both
    // from inside the app (where EconomyState is in scope) and from the
    // /shop route which is itself rooted under the app's MultiProvider.
    final economy = context.watch<EconomyState?>();
    final gemBalance = economy?.gems ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF412402).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Image.asset(
              'assets/ui/icon_gem.png',
              fit: BoxFit.contain,
              errorBuilder: AssetPlaceholder.image(
                color: AppColors.amber,
                label: 'gem',
                borderRadius: 3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('$gemBalance',
              style: const TextStyle(color: AppColors.amber, fontSize: 11)),
        ],
      ),
    );
  }
}

class _StaleCacheBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _StaleCacheBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: AppColors.amber.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: const Text(
          'Showing cached deals — pull to refresh',
          style: AppTypography.errorBanner,
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final ShopTab selected;
  final ValueChanged<ShopTab> onSelect;

  const _CategoryTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          top: BorderSide(color: AppColors.greenTrack, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final t in ShopTab.values)
            _TabButton(tab: t, selected: selected == t, onTap: () => onSelect(t)),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final ShopTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: AppTypography.bodyPale.copyWith(
                color: selected ? AppColors.greenLight : AppColors.greenLabel,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 2,
              width: 28,
              color: selected ? AppColors.greenLight : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final bool isLoading;
  final bool empty;
  final bool emptyAndErrored;
  final List<ShopBundle> featured;
  final List<ShopBundle> compact;
  final PageController pageController;
  final Future<bool> Function(String) onPurchase;
  final ValueChanged<int> onCarouselPage;
  final VoidCallback onRefresh;

  const _Body({
    required this.isLoading,
    required this.empty,
    required this.emptyAndErrored,
    required this.featured,
    required this.compact,
    required this.pageController,
    required this.onPurchase,
    required this.onCarouselPage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _SkeletonState();
    if (emptyAndErrored) return _EmptyErrored(onRetry: onRefresh);
    if (empty) return _EmptyState(onRetry: onRefresh);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        if (featured.isNotEmpty) ...[
          SizedBox(
            height: 192,
            child: PageView.builder(
              controller: pageController,
              itemCount: featured.length,
              onPageChanged: onCarouselPage,
              itemBuilder: (ctx, i) {
                final b = featured[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: BundleHeroCard(
                    bundle: b,
                    onPurchase: onPurchase,
                    onTap: () => _showDetailSheet(ctx, b, onPurchase),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          _CarouselDots(count: featured.length, controller: pageController),
        ],
        const SizedBox(height: 8),
        if (compact.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: compact.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (ctx, i) {
                final b = compact[i];
                return BundleCompactCard(
                  bundle: b,
                  onPurchase: onPurchase,
                  onTap: () => _showDetailSheet(ctx, b, onPurchase),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showDetailSheet(
    BuildContext context,
    ShopBundle bundle,
    Future<bool> Function(String) onPurchase,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bundle.localizationKey, style: AppTypography.title),
              const SizedBox(height: 4),
              Text(bundle.contentSummary(), style: AppTypography.bodyPale),
              const SizedBox(height: 12),
              BundleContentsGrid(
                contents: bundle.contents,
                accent: AppColors.fromHex(bundle.theme.accentColorHex),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _CarouselDots extends StatefulWidget {
  final int count;
  final PageController controller;
  const _CarouselDots({required this.count, required this.controller});

  @override
  State<_CarouselDots> createState() => _CarouselDotsState();
}

class _CarouselDotsState extends State<_CarouselDots> {
  int _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final page = widget.controller.page?.round() ?? 0;
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: active ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? AppColors.greenLight : AppColors.greenTrack,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _SkeletonState extends StatelessWidget {
  const _SkeletonState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (int j = 0; j < 2; j++) ...[
                  Expanded(
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (j == 0) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        const Center(
          child: Text(
            'No deals right now — check back soon!',
            style: AppTypography.bodyPale,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Refresh'),
          ),
        ),
      ],
    );
  }
}

class _EmptyErrored extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyErrored({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        const Center(
          child: Text(
            "Couldn't load shop deals.",
            style: AppTypography.errorBanner,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
