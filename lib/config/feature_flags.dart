/// Stub feature-flag surface used by the shop slice.
///
/// In Tier 2 this is replaced by a Firebase Remote Config-backed
/// implementation. For now every flag returns its compile-time default so
/// the app behaves deterministically.
class FeatureFlags {
  /// Whether the new bundle-driven shop is enabled. When false, callers
  /// should fall back to the legacy [shop_screen.dart].
  final bool shopBundleEnabled;

  /// Whether to show the debug overlay (long-press gem chip) for testers.
  final bool shopDebugOverlayEnabled;

  /// Maximum bundles to feature in the hero carousel.
  final int featuredCarouselSlots;

  const FeatureFlags({
    this.shopBundleEnabled = true,
    this.shopDebugOverlayEnabled = false,
    this.featuredCarouselSlots = 3,
  });

  /// Default flag set used when no remote config is wired up yet. The
  /// debug overlay defaults OFF so a release build doesn't expose the
  /// long-press gem-chip dev menu to end users.
  static const FeatureFlags defaults = FeatureFlags();
}
