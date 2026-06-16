/// Static metadata for the seven IAP products defined by the GDD §2.10:
/// four main shop packs + three contextual coin packs.
///
/// `productId` strings match the App Store Connect / Play Console IDs
/// — the SDK swap later only needs to wire [IapService.requestPurchase]
/// to the platform billing client.
class IapCatalog {
  IapCatalog._();

  /// Stable id of the four main shop packs in display order.
  static const List<String> mainPackIds = <String>[
    'starter_pack',
    'pilot_bundle',
    'squadron_bundle',
    'whale_pack',
  ];

  /// Stable id of the three contextual coin packs (NOT shown in the main
  /// shop — only triggered by the insufficient-coins event).
  static const List<String> contextualCoinPackIds = <String>[
    'coin_stockup',
    'coin_surge',
    'coin_tycoon',
  ];

  /// One-shot "full experience" contextual offer fired by the shop when
  /// the player can't afford a purchase. Sized at 10k coins to match a
  /// realistic mid-game spend (epic chest + a couple of power-ups).
  static const String fullExperienceCoinPackId = 'coin_essentials';

  /// Combined product id list — the IAP SDK queries platform stores using
  /// this whole set on app launch.
  static List<String> allIds() =>
      [...mainPackIds, ...contextualCoinPackIds, fullExperienceCoinPackId];

  /// Customer-facing USD price for each pack. Localized via the platform
  /// store layer in production; this value is shown unlocalized in dev.
  static const Map<String, double> usdPrice = <String, double>{
    'starter_pack': 0.99,
    'pilot_bundle': 4.99,
    'squadron_bundle': 9.99,
    'whale_pack': 49.99,
    'coin_stockup': 0.99,
    'coin_surge': 2.99,
    'coin_tycoon': 4.99,
    'coin_essentials': 0.99,
  };

  /// Player-facing display name.
  static const Map<String, String> displayName = <String, String>{
    'starter_pack': 'Starter Pack',
    'pilot_bundle': 'Pilot Bundle',
    'squadron_bundle': 'Squadron Bundle',
    'whale_pack': 'Whale Pack',
    'coin_stockup': 'Coin Stock-Up',
    'coin_surge': 'Coin Surge',
    'coin_tycoon': 'Coin Tycoon',
    'coin_essentials': 'Coin Essentials',
  };

  // ---------------------------------------------------------------------------
  // Pack contents (granted by [EconomyState.applyIapReward] on success).
  // ---------------------------------------------------------------------------

  /// Gem grant for the four main packs.
  static const Map<String, int> mainPackGems = <String, int>{
    'starter_pack': 12,
    'pilot_bundle': 80,
    'squadron_bundle': 180,
    'whale_pack': 1000,
  };

  /// "% off the next jet purchase" flag attached to mid-tier packs. Stored
  /// on EconomyState as a discount that consumes on next jet purchase.
  static const Map<String, double> mainPackNextJetDiscount = <String, double>{
    'pilot_bundle': 0.25,
    'squadron_bundle': 0.50,
  };

  /// Number of free jets granted by the whale pack (player picks at
  /// purchase confirm).
  static const int whalePackFreeJets = 2;

  /// Coins granted by each contextual coin pack.
  static const Map<String, int> coinPackCoins = <String, int>{
    'coin_stockup': 2000,
    'coin_surge': 7500,
    'coin_tycoon': 15000,
    'coin_essentials': 10000,
  };

  /// Random power-up grants per coin pack.
  static const Map<String, int> coinPackPowerUps = <String, int>{
    'coin_stockup': 2,
    'coin_surge': 5,
    'coin_tycoon': 10,
    'coin_essentials': 3,
  };

  /// Gems bundled with the larger coin packs.
  static const Map<String, int> coinPackGems = <String, int>{
    'coin_stockup': 0,
    'coin_surge': 10,
    'coin_tycoon': 25,
    'coin_essentials': 5,
  };

  // ---------------------------------------------------------------------------
  // Display flag rules — GDD §2.10
  // ---------------------------------------------------------------------------

  /// "BEST FIRST DEAL" badge stays on Starter Pack for this long after
  /// install.
  static const Duration starterBestDealWindow = Duration(days: 7);

  /// "MOST POPULAR" badge always sticks to the Whale Pack as the
  /// psychological anchor.
  static const String mostPopularPackId = 'whale_pack';

  // ---------------------------------------------------------------------------
  // Remove-Ads IAP — GDD §2.11
  // ---------------------------------------------------------------------------
  static const String removeAdsProductId = 'remove_ads';
  static const double removeAdsUsdPrice = 4.99;
}
