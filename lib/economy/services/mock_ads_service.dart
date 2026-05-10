import '../constants/ad_placement_catalog.dart';
import 'ads_service.dart';

/// Local-only ads stub. Resolves instantly without any network call.
///
/// **Swap point for production:** replace [MockAdsService] with a
/// `GoogleMobileAdsService` wherever [AdsService] is constructed. The
/// rest of the economy stack is unchanged.
class MockAdsService implements AdsService {
  bool _adsRemoved;

  /// When true, every `show` call resolves with [AdShowResult.failedToLoad].
  /// Used to test the graceful-failure UI path.
  bool failureMode;

  /// Latency before the simulated reward fires. Default ~30s in the GDD;
  /// 200ms in the mock so devs aren't waiting around.
  Duration latency;

  MockAdsService({
    bool adsRemoved = false,
    this.failureMode = false,
    this.latency = const Duration(milliseconds: 200),
  }) : _adsRemoved = adsRemoved;

  @override
  bool get adsRemoved => _adsRemoved;

  /// Toggles [adsRemoved]. Called by [EconomyState] after the
  /// `remove_ads` IAP completes.
  set adsRemoved(bool value) => _adsRemoved = value;

  @override
  Future<AdShowOutcome> show(AdPlacement placement) async {
    if (_adsRemoved) {
      // Per GDD: when adsRemoved is true, the player still receives the
      // placement's reward (doubled, applied by EconomyState).
      return AdShowOutcome(result: AdShowResult.rewardEarned, placement: placement);
    }
    await Future<void>.delayed(latency);
    if (failureMode) {
      return AdShowOutcome(
        result: AdShowResult.failedToLoad,
        placement: placement,
        errorMessage: 'Mock failure mode active',
      );
    }
    return AdShowOutcome(result: AdShowResult.rewardEarned, placement: placement);
  }

  @override
  void dispose() {
    // No resources to release in the mock.
  }
}
