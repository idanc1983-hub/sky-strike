import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_units.dart';
import 'ads_state.dart';
import 'consent_manager.dart';

class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const MethodChannel _attChannel =
      MethodChannel('skystrike/ads_att');

  static const String _kLastShownAtKey = 'ads_last_shown_at';
  static const String _kAttStatusKey = 'ads_att_status';
  static const Duration _cooldown = Duration(seconds: 60);
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 30);

  bool _initialized = false;
  bool _isShowing = false;
  Future<void>? _initFuture;
  int _attStatus = 0;

  /// True once UMP + (iOS) ATT + Mobile Ads init have all resolved. Ad
  /// loads are gated on this so a fast preload call from gameplay can't
  /// race the boot sequence.
  bool get isReady => _initialized;

  /// Raw ATTrackingManager status value captured during init. iOS
  /// values: 0=notDetermined, 1=restricted, 2=denied, 3=authorized.
  /// Always 3 on non-iOS / pre-iOS 14.
  int get attStatus => _attStatus;

  final Map<RewardedPlacement, RewardedAd?> _rewardedAds = {
    for (final p in RewardedPlacement.values) p: null,
  };
  final Map<RewardedPlacement, Timer?> _retryTimers = {
    for (final p in RewardedPlacement.values) p: null,
  };
  final Map<RewardedPlacement, int> _retryAttempts = {
    for (final p in RewardedPlacement.values) p: 0,
  };
  final Map<RewardedPlacement, bool> _isLoading = {
    for (final p in RewardedPlacement.values) p: false,
  };

  Map<RewardedPlacement, ValueNotifier<bool>> get rewardedAdLoaded =>
      AdsState.instance.rewardedAdLoaded;

  /// Boots the ad stack in the order required by Google's EU User
  /// Consent Policy and Apple's ATT rules:
  ///
  ///   1. UMP — fetch consent info, show the consent form if required.
  ///   2. iOS only — request ATT (UMP coordinates the explainer; the
  ///      actual prompt is fired here so AdMob's IDFA usage is gated
  ///      on the user's ATT choice).
  ///   3. Apply the global `RequestConfiguration` (child flags, max
  ///      content rating) before any ad request.
  ///   4. Initialize the Mobile Ads SDK.
  ///
  /// Idempotent — concurrent or repeat calls share the same future.
  /// Errors are logged, never thrown: a consent failure must not block
  /// gameplay.
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    // 1. UMP consent.
    await ConsentManager.requestConsentIfNeeded();

    // 2. iOS ATT — must run AFTER UMP so the consent form can prep the
    //    user for the system prompt.
    if (Platform.isIOS) {
      await _requestATT();
    }

    // 3. Global request configuration (child flags + content rating
    //    cap). Set BEFORE MobileAds.initialize so the very first ad
    //    request inherits it.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment:
            TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );

    // 4. Mobile Ads SDK init.
    final status = await MobileAds.instance.initialize();
    if (kDebugMode) {
      for (final entry in status.adapterStatuses.entries) {
        debugPrint(
          '[ads] adapter ${entry.key} '
          'state=${entry.value.state} '
          'desc=${entry.value.description}',
        );
      }
    }

    _initialized = true;
    debugPrint('[ads] MobileAds initialized');
  }

  Future<void> _requestATT() async {
    try {
      final raw = await _attChannel.invokeMethod<int>('requestATT');
      final status = raw ?? 0;
      _attStatus = status;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kAttStatusKey, status);
      debugPrint('[ads] ATT status=$status');
    } catch (e) {
      debugPrint('[ads] ATT request failed: $e');
    }
  }

  void preloadRewarded(RewardedPlacement placement) {
    if (_isLoading[placement]! || _rewardedAds[placement] != null) {
      return;
    }
    // Gate on the consent + ATT + MobileAds init chain. A preload call
    // that races boot (e.g. from the splash screen warming up the first
    // rewarded ad) must not hit AdMob before consent is resolved.
    if (!_initialized) {
      _isLoading[placement] = true;
      rewardedAdLoaded[placement]!.value = false;
      initialize().then((_) {
        _isLoading[placement] = false;
        preloadRewarded(placement);
      });
      return;
    }
    _isLoading[placement] = true;
    rewardedAdLoaded[placement]!.value = false;
    final unit = AdUnits.rewardedFor(placement);
    debugPrint('[ads] preloading ${placement.name} unit=$unit');

    RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _isLoading[placement] = false;
          _retryAttempts[placement] = 0;
          _rewardedAds[placement] = ad;
          rewardedAdLoaded[placement]!.value = true;
          debugPrint('[ads] ${placement.name} loaded');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isLoading[placement] = false;
          _rewardedAds[placement] = null;
          rewardedAdLoaded[placement]!.value = false;
          debugPrint(
            '[ads] ${placement.name} load failed: '
            'code=${error.code} domain=${error.domain} '
            'message=${error.message}',
          );
          _scheduleRetry(placement);
        },
      ),
    );
  }

  void _scheduleRetry(RewardedPlacement placement) {
    final attempt = _retryAttempts[placement]!;
    if (attempt >= _maxRetries) {
      debugPrint('[ads] ${placement.name} max retries reached');
      return;
    }
    final next = attempt + 1;
    _retryAttempts[placement] = next;
    final delay = _baseRetryDelay * (1 << (next - 1));
    debugPrint(
      '[ads] ${placement.name} retry $next/$_maxRetries '
      'in ${delay.inSeconds}s',
    );
    _retryTimers[placement]?.cancel();
    _retryTimers[placement] = Timer(delay, () {
      _retryTimers[placement] = null;
      preloadRewarded(placement);
    });
  }

  Future<bool> showReviveAd() => _show(RewardedPlacement.revive);
  Future<bool> showWaveCompleteAd() => _show(RewardedPlacement.waveComplete);
  Future<bool> showDailyGiftAd() => _show(RewardedPlacement.dailyGift);

  Future<bool> _show(RewardedPlacement placement) async {
    final tag = placement.name;
    if (_isShowing) {
      debugPrint('[ads] show($tag) blocked: another ad in flight');
      return false;
    }

    final ad = _rewardedAds[placement];
    if (ad == null || !rewardedAdLoaded[placement]!.value) {
      debugPrint('[ads] show($tag) skipped: no ad loaded');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt(_kLastShownAtKey) ?? 0;
    final elapsedMs =
        DateTime.now().millisecondsSinceEpoch - lastShown;
    if (lastShown > 0 && elapsedMs < _cooldown.inMilliseconds) {
      final remaining =
          ((_cooldown.inMilliseconds - elapsedMs) / 1000).ceil();
      debugPrint(
        '[ads] show($tag) blocked: cooldown ${remaining}s remaining',
      );
      return false;
    }

    _isShowing = true;
    _rewardedAds[placement] = null;
    rewardedAdLoaded[placement]!.value = false;

    final completer = Completer<bool>();
    var rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd _) {
        debugPrint('[ads] show($tag) impression');
      },
      onAdFailedToShowFullScreenContent:
          (RewardedAd shown, AdError error) async {
        debugPrint(
          '[ads] show($tag) failed: '
          'code=${error.code} message=${error.message}',
        );
        shown.dispose();
        _isShowing = false;
        preloadRewarded(placement);
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdDismissedFullScreenContent: (RewardedAd shown) async {
        debugPrint(
          '[ads] show($tag) dismissed rewardEarned=$rewardEarned',
        );
        shown.dispose();
        await prefs.setInt(
          _kLastShownAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        _isShowing = false;
        preloadRewarded(placement);
        if (!completer.isCompleted) completer.complete(rewardEarned);
      },
    );

    debugPrint('[ads] show($tag) presenting');
    await ad.show(
      onUserEarnedReward: (AdWithoutView _, RewardItem reward) {
        rewardEarned = true;
        debugPrint(
          '[ads] show($tag) reward earned '
          'amount=${reward.amount} type=${reward.type}',
        );
      },
    );

    return completer.future;
  }

  void dispose() {
    for (final p in RewardedPlacement.values) {
      _retryTimers[p]?.cancel();
      _retryTimers[p] = null;
      _rewardedAds[p]?.dispose();
      _rewardedAds[p] = null;
      _isLoading[p] = false;
      _retryAttempts[p] = 0;
      rewardedAdLoaded[p]!.value = false;
    }
    _isShowing = false;
  }
}
