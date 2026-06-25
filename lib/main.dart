import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/remote_config_service.dart';
import 'economy/services/ads_service.dart' show AdsService;
import 'economy/services/economy_api.dart';
import 'economy/services/economy_config.dart';
import 'economy/services/economy_persistence.dart';
import 'economy/services/google_mobile_ads_economy_service.dart';
import 'economy/services/iap_service.dart' show IapService;
import 'economy/services/mock_ads_service.dart';
import 'economy/services/mock_iap_service.dart';
import 'economy/services/remote_economy_config_source.dart';
import 'economy/services/store_iap_service.dart';
import 'economy/state/economy_state.dart';
import 'economy/ui/daily_reward_screen.dart';
import 'screens/game_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';
import 'shared/widgets/reward_celebration_host.dart';
import 'services/ads/ads_service.dart' as platform_ads;
import 'services/ads/consent_manager.dart';
import 'shop/services/bundle_cache.dart';
import 'shop/services/bundle_service.dart';
import 'shop/services/bundle_validator.dart';
import 'shop/services/mock_bundle_repository.dart';
import 'shop/services/segment_evaluator.dart';
import 'shop/state/shop_state.dart';
import 'shop/ui/shop_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  // Firebase + Remote Config. Failures here must not block the app — a
  // missing platform plist or a flaky network should still launch the game
  // with bundled defaults.
  try {
    await Firebase.initializeApp();
    await RemoteConfigService.I.initialize();
    // Route Flutter framework + isolate errors to Crashlytics. Disabled
    // in non-release builds so developer stack traces still show in the
    // console without being duplicated to the dashboard.
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // Pessimistic defaults pre-UMP: every data-collecting SDK starts in
    // a denied state. Once consent resolves we re-apply the real values.
    await FirebaseAnalytics.instance.setConsent(
      adStorageConsentGranted: false,
      analyticsStorageConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
      adUserDataConsentGranted: false,
    );
  } catch (e, st) {
    debugPrint('[FIREBASE_INIT_FAIL] $e\n$st');
  }

  // Hook the live economy config so calculators see RC tuning. If
  // Firebase init above failed, the source still returns null for
  // every key and the calculators fall back to EconomyConstants — so
  // a broken Firebase project never silently zeros out the economy.
  EconomyConfig.setSource(RemoteEconomyConfigSource());

  // Real billing + ads only in release builds. Debug / profile builds
  // keep the mocks so QA can grant/test without hitting stores or
  // burning AdMob fill. The selection happens here at construction —
  // no runtime flag, no `if (kDebugMode) { … }` sprinkled in callers.
  final IapService iap;
  final AdsService ads;
  if (kReleaseMode) {
    final storeIap = StoreIapService();
    // Best-effort init — if the platform store is unavailable, the
    // service returns `productUnknown` for every purchase rather than
    // crash. Surface the failure in logs so QA notices.
    //
    // RemoteConfigService is already initialized above, so the shop-pack
    // and monetization-offer SKUs it carries are passed in here — without
    // this the store never queries them and every purchase of an
    // RC-driven product fails with `productUnknown`.
    unawaited(storeIap
        .initialize(extraProductIds: _collectStoreProductIds())
        .catchError((Object e, StackTrace st) {
      debugPrint('[IAP_INIT_FAIL] $e\n$st');
    }));
    iap = storeIap;
    // The consent → ATT → MobileAds chain is deferred until the splash
    // screen dismisses — the iOS ATT system prompt should land on an
    // interactive screen, not over the still-loading splash artwork.
    // See `_bootAdStack` and the `/splash` route below. `preloadRewarded`
    // gates on `isReady`, so any preload call from gameplay safely waits
    // for the chain to resolve.
    ads = GoogleMobileAdsEconomyService();
  } else {
    iap = MockIapService();
    ads = MockAdsService();
  }

  // Build a single EconomyState at app startup. ChangeNotifierProvider.value
  // hands the same instance to every screen that needs it.
  final economy = EconomyState(
    persistence: EconomyPersistence(),
    api: EconomyApi(),
    iap: iap,
    ads: ads,
  );
  // initialize() can fail on a corrupted prefs store. Defaults still
  // give us a usable app — log and proceed rather than crash before
  // runApp.
  try {
    await economy.initialize();
  } catch (e, st) {
    debugPrint('[ECONOMY_INIT_FAIL] $e\n$st');
  }

  runApp(SkyStrikeApp(economy: economy));
}

/// Collects every store SKU declared in Remote Config — shop coin/gem pack
/// `iap_product_id`s and monetization offer `product_id`s — so
/// [StoreIapService.initialize] can query them all. A SKU missing from this
/// set can't be purchased ([IapPurchaseResult.productUnknown]). Reads the
/// already-initialized [RemoteConfigService] singleton.
Set<String> _collectStoreProductIds() {
  final rc = RemoteConfigService.I;
  final ids = <String>{};
  for (final p in rc.shop.coinPacks) {
    final id = p.iapProductId;
    if (id != null && id.isNotEmpty) ids.add(id);
  }
  for (final p in rc.shop.gemPacks) {
    final id = p.iapProductId;
    if (id != null && id.isNotEmpty) ids.add(id);
  }
  for (final c in rc.monetization.configs) {
    final id = c.productId;
    if (id != null && id.isNotEmpty) ids.add(id);
  }
  return ids;
}

/// Boots the platform ads stack: UMP consent → iOS ATT prompt →
/// MobileAds SDK init. Fired from the splash screen the moment it
/// dismisses, so the ATT system dialog lands on an interactive surface
/// rather than over the still-loading splash artwork.
///
/// Idempotent — `AdsService.initialize()` caches its in-flight future,
/// so repeated calls (hot reload, splash re-entry) are no-ops. Errors
/// are logged and swallowed; a consent or network failure must not
/// block gameplay.
void _bootAdStack() {
  unawaited(platform_ads.AdsService.instance.initialize().then((_) {
    _applyConsentToAnalytics();
  }).catchError((Object e, StackTrace st) {
    debugPrint('[ADS_INIT_FAIL] $e\n$st');
  }));
}

/// Applies the resolved UMP / ATT state to every data-collecting SDK.
/// Called once the ad init chain has finished; safe to call again if
/// the user later re-opens the privacy options form from Settings.
///
/// The principle from the compliance task: every data SDK reads the
/// same consent state, and no SDK collects ahead of consent in
/// regulated regions. `canRequestAds` is UMP's authoritative answer to
/// "is this user OK with personalised data flows here?" — outside the
/// EEA/UK it returns true by default (no consent required), inside
/// regulated regions it returns true only after the user accepts.
Future<void> _applyConsentToAnalytics() async {
  final consent = ConsentManager.lastResult;
  final granted = consent.canRequestAds;
  try {
    await FirebaseAnalytics.instance.setConsent(
      adStorageConsentGranted: granted,
      analyticsStorageConsentGranted: granted,
      adPersonalizationSignalsConsentGranted: granted,
      adUserDataConsentGranted: granted,
    );
  } catch (e, st) {
    debugPrint('[ANALYTICS_CONSENT_FAIL] $e\n$st');
  }
  // Amplitude only starts collecting when consent is granted. If the
  // user later withdraws, we don't have a way to scrub already-sent
  // events server-side, but we stop sending new ones (the Amplitude
  // singleton stays uninitialised for this app launch).
  if (granted) {
    final key = RemoteConfigService.I.rawString('amplitude_api_key');
    if (key.isNotEmpty) {
      try {
        final amplitude = Amplitude(Configuration(apiKey: key));
        // amplitude_flutter 4.x kicks off init in the constructor and
        // exposes the resulting future as `isBuilt` (no public init()).
        await amplitude.isBuilt;
        debugPrint('[analytics] amplitude initialised');
      } catch (e, st) {
        debugPrint('[AMPLITUDE_INIT_FAIL] $e\n$st');
      }
    } else {
      debugPrint(
        '[analytics] amplitude_api_key not in Remote Config — skipping',
      );
    }
  } else {
    debugPrint(
      '[analytics] consent not granted (status=${consent.status.name}) '
      '— amplitude skipped, firebase consent set to denied',
    );
  }
}

class SkyStrikeApp extends StatefulWidget {
  final EconomyState economy;
  const SkyStrikeApp({super.key, required this.economy});

  @override
  State<SkyStrikeApp> createState() => _SkyStrikeAppState();
}

class _SkyStrikeAppState extends State<SkyStrikeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Background / kill — flush in-memory mutations to disk so the
        // last frame of progress isn't lost if the OS evicts us.
        widget.economy.persist();
        break;
      case AppLifecycleState.resumed:
        // Re-evaluate streak windows and challenge expiry now that
        // wall-clock time may have advanced.
        widget.economy.onAppForeground();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EconomyState>.value(
      value: widget.economy,
      child: MaterialApp(
        title: 'SkyStrike',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFF0a1a0a),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B6D11),
            brightness: Brightness.dark,
          ),
        ),
        initialRoute: '/splash',
        navigatorObservers: [rewardRouteObserver],
        routes: {
          // Release-only callback: debug/profile builds use MockAdsService
          // and the platform stack is never wired in.
          '/splash': (_) => const SplashScreen(
                onDismiss: kReleaseMode ? _bootAdStack : null,
              ),
          // Menu screens are wrapped so won/bought rewards celebrate here.
          '/home': (_) => const RewardCelebrationHost(child: MainShell()),
          '/game': (_) => const GameScreen(),
          '/daily-rewards': (_) => const DailyRewardScreen(),
          '/shop': (_) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<BundleService>(
                    create: (_) => BundleService(
                      repository: MockBundleRepository(),
                      validator: BundleValidator(),
                      evaluator: SegmentEvaluator(),
                      cache: BundleCache(),
                    )..initialize(),
                  ),
                  ChangeNotifierProvider<ShopState>(
                    create: (_) => ShopState(),
                  ),
                ],
                child: const RewardCelebrationHost(child: ShopShell()),
              ),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/loading') {
            // Be lenient on the argument shape — a typo at any call
            // site shouldn't crash the route, since the only legal way
            // a player reaches this code path is via an in-app push.
            final raw = settings.arguments;
            int? world;
            int? stage;
            if (raw is Map) {
              final w = raw['world'];
              final s = raw['stage'];
              if (w is int) world = w;
              if (s is int) stage = s;
            }
            return MaterialPageRoute(
              builder: (_) => LoadingScreen(
                world: world ?? 1,
                stage: stage ?? 1,
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
