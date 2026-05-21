/// Maps `popup_bg` keys from `monetization__configurations__v1` to bundled
/// Flutter asset paths. See /Remote Config/CLIENT_RUNTIME_SPEC.md
/// Runtime 3 for the full spec.
///
/// Returns `null` for unregistered keys — caller should fall back to
/// `DevPopupBgPlaceholder` so popups stay testable while art is pending.
class PopupBgRegistry {
  PopupBgRegistry._();

  /// Registered key → bundled asset path. Add an entry here when a real
  /// asset lands at the canonical path. Until then, the key stays
  /// unregistered and consumers render the dev placeholder.
  ///
  /// To "activate" art for a key after upload, change `null` to the asset
  /// path string. Track upload status in /Remote Config/POPUP_BG_ASSETS.md.
  static const Map<String, String?> _registry = {
    'bg_welcome_jungle':    null, // pending — assets/ui/popups/bg_welcome_jungle.png
    'bg_first_purchase':    null, // pending — assets/ui/popups/bg_first_purchase.png
    'bg_ironsky_metal':     null, // pending — assets/ui/popups/bg_ironsky_metal.png
    'bg_laststand_storm':   null, // pending — assets/ui/popups/bg_laststand_storm.png
    'bg_goldensky_sunset':  null, // pending — assets/ui/popups/bg_goldensky_sunset.png
    'bg_starascent_cosmos': null, // pending — assets/ui/popups/bg_starascent_cosmos.png
  };

  /// Returns the asset path for a popup_bg key, or `null` if the key is
  /// unregistered or art has not yet been uploaded for it.
  static String? lookup(String? popupBgKey) {
    if (popupBgKey == null) return null;
    return _registry[popupBgKey];
  }

  /// True if [popupBgKey] is known to the registry — useful for analytics
  /// (we want to know about typos in remote config, not just missing art).
  static bool isKnown(String? popupBgKey) =>
      popupBgKey != null && _registry.containsKey(popupBgKey);
}
