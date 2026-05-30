import '../constants/ad_placement_catalog.dart';
import '../../services/ads/ads_service.dart' as platform_ads;
import 'ads_service.dart';

/// Production [AdsService] backed by `services/ads/AdsService` (the
/// google_mobile_ads wrapper). Bridges the economy's placement-typed
/// interface to the platform layer's per-placement methods.
///
/// **Swap point**: replace [MockAdsService] with this class in
/// [main.dart] when running release builds. The platform service
/// pre-loads each rewarded ad on initialize, so first-show latency is
/// already minimised.
class GoogleMobileAdsEconomyService implements AdsService {
  final platform_ads.AdsService _platform;
  bool _adsRemoved;

  GoogleMobileAdsEconomyService({
    platform_ads.AdsService? platform,
    bool adsRemoved = false,
  })  : _platform = platform ?? platform_ads.AdsService.instance,
        _adsRemoved = adsRemoved;

  @override
  bool get adsRemoved => _adsRemoved;

  /// Toggle from [EconomyState] once the `remove_ads` IAP completes.
  /// When true, [show] resolves with [AdShowResult.rewardEarned]
  /// immediately without serving an ad — the caller still grants the
  /// reward (doubled by [EconomyState]).
  set adsRemoved(bool value) => _adsRemoved = value;

  @override
  Future<AdShowOutcome> show(AdPlacement placement) async {
    if (_adsRemoved) {
      return AdShowOutcome(
        result: AdShowResult.rewardEarned,
        placement: placement,
      );
    }

    final ok = await _showFor(placement);
    return AdShowOutcome(
      result: ok ? AdShowResult.rewardEarned : AdShowResult.failedToLoad,
      placement: placement,
    );
  }

  /// Routes the economy [AdPlacement] enum to the platform's
  /// [platform_ads.RewardedPlacement] enum + show call. Two of the four
  /// economy placements (chestBoost, doubleBiomeEnd) map onto
  /// `waveComplete` since that's the only end-of-stage rewarded slot
  /// the platform layer carries today — flag for design review if those
  /// become distinct ad units later.
  Future<bool> _showFor(AdPlacement placement) {
    switch (placement) {
      case AdPlacement.reviveMidStage:
        return _platform.showReviveAd();
      case AdPlacement.extraGemsDaily:
        return _platform.showDailyGiftAd();
      case AdPlacement.doubleBiomeEnd:
      case AdPlacement.chestBoost:
        return _platform.showWaveCompleteAd();
    }
  }

  @override
  void dispose() {
    _platform.dispose();
  }
}
