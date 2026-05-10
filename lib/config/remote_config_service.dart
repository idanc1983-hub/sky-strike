import 'feature_flags.dart';

/// Stub remote-config surface — only the methods the bundle service needs.
///
/// Replace with `firebase_remote_config` later. The shape matches what a
/// real implementation would expose: `flags`, `bundleEndpoint`, and
/// `playerSegmentsEndpoint`. Keep this thin so the swap is mechanical.
class RemoteConfigService {
  /// Active feature flags. Today: compile-time defaults.
  FeatureFlags get flags => FeatureFlags.defaults;

  /// CDN/endpoint URL for the active bundles list. Mock backend uses an
  /// asset path; a real backend would return an HTTPS URL.
  String get bundleEndpoint => 'assets/mock_backend/bundles_active.json';

  /// CDN/endpoint URL for the current player's segment record.
  String get playerSegmentsEndpoint =>
      'assets/mock_backend/player_segments.json';

  /// CDN/endpoint URL for the theme asset manifest.
  String get assetManifestEndpoint =>
      'assets/mock_backend/asset_manifest.json';

  /// No-op for the mock implementation. A real implementation fetches and
  /// activates the latest config from Firebase.
  Future<void> initialize() async {}
}
