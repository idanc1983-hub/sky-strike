import 'package:flutter/foundation.dart';

/// Categories shown in the shop's tab strip. Each tab filters
/// `BundleService.visibleBundles` to a relevant subset.
enum ShopTab { bundles, gems, powerups, jets }

extension ShopTabLabel on ShopTab {
  String get label {
    switch (this) {
      case ShopTab.bundles:
        return 'Bundles';
      case ShopTab.gems:
        return 'Gems';
      case ShopTab.powerups:
        return 'Power-ups';
      case ShopTab.jets:
        return 'Jets';
    }
  }
}

/// Lightweight UI-only state — what tab is selected, which carousel page
/// is visible. The bundle data itself lives on [BundleService].
class ShopState extends ChangeNotifier {
  ShopTab _selectedTab = ShopTab.bundles;
  int _carouselPage = 0;

  ShopTab get selectedTab => _selectedTab;
  int get carouselPage => _carouselPage;

  /// Switches the active category tab. No-op if already selected.
  void selectTab(ShopTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    notifyListeners();
  }

  /// Updates the visible carousel page index. Called from the [PageView]
  /// listener.
  void setCarouselPage(int page) {
    if (_carouselPage == page) return;
    _carouselPage = page;
    notifyListeners();
  }
}
