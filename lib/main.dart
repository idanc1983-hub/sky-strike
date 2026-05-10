import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'economy/services/economy_api.dart';
import 'economy/services/economy_persistence.dart';
import 'economy/services/mock_ads_service.dart';
import 'economy/services/mock_iap_service.dart';
import 'economy/state/economy_state.dart';
import 'economy/ui/daily_reward_screen.dart';
import 'screens/game_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/main_shell.dart';
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

  // Build a single EconomyState at app startup. ChangeNotifierProvider.value
  // hands the same instance to every screen that needs it.
  final economy = EconomyState(
    persistence: EconomyPersistence(),
    api: EconomyApi(),
    iap: MockIapService(),
    ads: MockAdsService(),
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
        initialRoute: '/home',
        routes: {
          '/home': (_) => const MainShell(),
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
                child: const ShopShell(),
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
