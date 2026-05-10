/// Discriminator for the four ad placements defined by the GDD §2.11.
enum AdPlacement {
  /// Mid-stage rewarded video. Free revive, capped 3 per stage.
  reviveMidStage,

  /// End-of-biome rewarded video. 2× coin & gem reward from this run.
  /// No cap.
  doubleBiomeEnd,

  /// Daily "extra gems" rewarded video. 1-2 gems, capped 5 per day.
  extraGemsDaily,

  /// Operation chest boost. +25% coins from chest, once per chest.
  chestBoost,
}

/// Static metadata about each placement: stable id, display label, base
/// reward range, cap rule. UI uses this to render the rewarded-video
/// preview popup before the player opts in.
class AdPlacementCatalog {
  AdPlacementCatalog._();

  /// Stable id used for analytics, persistence, and SDK ad-unit lookup.
  static const Map<AdPlacement, String> stableId = <AdPlacement, String>{
    AdPlacement.reviveMidStage: 'ad_revive_midstage',
    AdPlacement.doubleBiomeEnd: 'ad_double_biome_end',
    AdPlacement.extraGemsDaily: 'ad_extra_gems_daily',
    AdPlacement.chestBoost: 'ad_chest_boost',
  };

  /// Player-facing label shown on the preview popup before the ad starts.
  static const Map<AdPlacement, String> displayLabel = <AdPlacement, String>{
    AdPlacement.reviveMidStage: 'Watch a 30s ad to revive — free',
    AdPlacement.doubleBiomeEnd: 'Watch a 30s ad to double your biome reward',
    AdPlacement.extraGemsDaily: 'Watch a 30s ad for free gems',
    AdPlacement.chestBoost: 'Watch a 30s ad for +25% coins from this chest',
  };

  /// Min/max gem reward for [AdPlacement.extraGemsDaily]. Random within
  /// the inclusive range.
  static const int extraGemsMin = 1;
  static const int extraGemsMax = 2;
}
