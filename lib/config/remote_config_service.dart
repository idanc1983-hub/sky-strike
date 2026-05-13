import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'config_analytics.dart';
import 'config_defaults.dart';
import 'config_keys.dart';
import 'config_schemas/ab_assignment.dart';
import 'config_schemas/challenges_cycle_plan.dart';
import 'config_schemas/drop_rates.dart';
import 'config_schemas/enemy_scaling.dart';
import 'config_schemas/feature_flags.dart';
import 'config_schemas/level_rewards.dart';
import 'config_schemas/revive_pricing.dart';
import 'config_schemas/shop_prices.dart';
import 'config_schemas/streak_boost.dart';
import 'config_schemas/wave_curve.dart';
import 'config_schemas/xp_curve.dart';
import 'forced_variants.dart';

const String _logName = 'remote_config';

/// Singleton orchestrator for Firebase Remote Config.
///
/// Lifecycle:
///   1. `RemoteConfigService.instance.initialize()` during app startup.
///   2. Service registers a lifecycle observer; refreshes on
///      `AppLifecycleState.resumed`.
///   3. Game code calls typed getters in hot paths — safe at 60fps.
///
/// Resilience:
///   - Asset / fetch / parse failures never propagate. Each failure mode
///     drops to a documented fallback: last-good cached value, then the
///     baked default from `defaults.json`, then the per-schema static
///     fallback constant.
class RemoteConfigService with WidgetsBindingObserver {
  RemoteConfigService._({
    FirebaseRemoteConfig? remote,
    ConfigAnalytics? analytics,
  })  : _remote = remote ?? FirebaseRemoteConfig.instance,
        _analytics = analytics ?? ConfigAnalytics();

  static RemoteConfigService? _instance;
  static RemoteConfigService get instance =>
      _instance ??= RemoteConfigService._();

  /// Test-only: replace the singleton with a custom instance.
  @visibleForTesting
  static void installForTests(RemoteConfigService instance) {
    _instance = instance;
  }

  /// Test-only: clear the singleton.
  @visibleForTesting
  static void resetForTests() {
    _instance = null;
  }

  final FirebaseRemoteConfig _remote;
  final ConfigAnalytics _analytics;

  /// Increments on every successful activate. UI can watch this to
  /// trigger rebuilds when remote values change.
  final ValueNotifier<int> configVersion = ValueNotifier<int>(0);

  bool _initialized = false;

  // Parsed schemas — populated by initialize() and refresh().
  WaveCurveTable _waveCurves = WaveCurveTable.fallback;
  EnemyScalingTable _enemyScaling = EnemyScalingTable.fallback;
  DropRatesConfig _dropRates = DropRatesConfig.fallback;
  StreakBoost _streakBoost = StreakBoost.fallback;
  RevivePricing _revivePricing = RevivePricing.fallback;
  ShopPrices _shopPrices = ShopPrices.fallback;
  XpCurve _xpCurve = XpCurve.fallback;
  LevelRewardsTable _levelRewards = LevelRewardsTable.fallback;
  FeatureFlags _featureFlags = FeatureFlags.fallback;
  KillSwitches _killSwitches = KillSwitches.fallback;
  AbAssignment _abAssignment = AbAssignment.fallback;
  ChallengesCyclePlan _challengesCyclePlan = ChallengesCyclePlan.fallback;

  /// Last-known-good raw JSON strings keyed by Firebase key. Used to
  /// recover when a fresh remote value parses badly.
  final Map<String, String> _lastGoodRaw = <String, String>{};

  /// Initialize the service. Idempotent. Loads baked defaults, registers
  /// them with Firebase, fetches the remote payload (best-effort), and
  /// hooks the lifecycle observer.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final defaults = await ConfigDefaults.load();
    // Seed our parser cache from defaults so getters work even if
    // fetchAndActivate fails or times out.
    _lastGoodRaw.addAll(defaults);
    _parseAll(defaults, isDefault: true);

    // Wire defaults into Firebase so its in-memory store falls back
    // correctly. Firebase only accepts primitive types; we already
    // stringified the payloads on the build side.
    try {
      await _remote.setDefaults(<String, Object>{
        for (final entry in defaults.entries) entry.key: entry.value,
      });
    } catch (e, st) {
      developer.log('setDefaults failed: $e',
          name: _logName, level: 900, error: e, stackTrace: st);
    }

    try {
      await _remote.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(seconds: 60),
      ));
    } catch (e) {
      developer.log('setConfigSettings failed: $e',
          name: _logName, level: 900);
    }

    WidgetsBinding.instance.addObserver(this);

    await refresh(source: 'launch');
  }

  /// Force a fetch+activate. Safe to call any time after [initialize].
  Future<void> refresh({String source = 'foreground'}) async {
    final stopwatch = Stopwatch()..start();
    bool activated = false;
    String? errorCode;
    try {
      activated = await _remote
          .fetchAndActivate()
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      errorCode = 'timeout';
    } catch (e, st) {
      errorCode = e.runtimeType.toString();
      developer.log(
        'fetchAndActivate failed: $e',
        name: _logName,
        level: 900,
        error: e,
        stackTrace: st,
      );
    }
    stopwatch.stop();

    unawaited(_analytics.logFetch(
      success: errorCode == null,
      durationMs: stopwatch.elapsedMilliseconds,
      source: source,
      errorCode: errorCode,
    ));

    if (errorCode != null) return;

    // Read every key's current value (remote-active overlay on top of
    // defaults) and re-parse.
    final fresh = <String, String>{};
    for (final key in ConfigKeys.all) {
      try {
        final s = _remote.getString(key);
        if (s.isNotEmpty) fresh[key] = s;
      } catch (e) {
        developer.log('getString($key) failed: $e',
            name: _logName, level: 900);
      }
    }
    final schemaVersions = _parseAll(fresh, isDefault: false);

    if (activated) {
      configVersion.value = configVersion.value + 1;
    }
    int? templateVersion;
    try {
      templateVersion = _remote.lastFetchTime.millisecondsSinceEpoch;
    } catch (_) {
      templateVersion = null;
    }
    unawaited(_analytics.logActivated(
      schemaVersions: schemaVersions,
      templateVersion: templateVersion,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized) {
      // Fire-and-forget; refresh has its own error guards.
      unawaited(refresh(source: 'foreground'));
    }
  }

  // -------------------------------------------------------------------
  // Parsing
  // -------------------------------------------------------------------

  /// Parse every namespace from [raw]. Returns a `{namespace: schema_version}`
  /// map describing what we successfully parsed.
  Map<String, int> _parseAll(Map<String, String> raw,
      {required bool isDefault}) {
    final versions = <String, int>{};

    _waveCurves = _parseOne<WaveCurveTable>(
      raw: raw,
      key: ConfigKeys.difficultyWaveCurves,
      supported: WaveCurveTable.supportedSchemaVersion,
      namespace: 'difficulty.wave_curves',
      previous: _waveCurves,
      fallback: WaveCurveTable.fallback,
      parse: (m) => WaveCurveTable.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'difficulty.wave_curves',
      isDefault: isDefault,
    );
    _enemyScaling = _parseOne<EnemyScalingTable>(
      raw: raw,
      key: ConfigKeys.difficultyEnemyScaling,
      supported: EnemyScalingTable.supportedSchemaVersion,
      namespace: 'difficulty.enemy_scaling',
      previous: _enemyScaling,
      fallback: EnemyScalingTable.fallback,
      parse: (m) => EnemyScalingTable.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'difficulty.enemy_scaling',
      isDefault: isDefault,
    );

    // DropRates merges TWO Firebase keys (rates + powerup_distribution).
    _dropRates = _parseDropRates(raw, isDefault: isDefault, versions: versions);

    _streakBoost = _parseOne<StreakBoost>(
      raw: raw,
      key: ConfigKeys.dropsStreakBoost,
      supported: StreakBoost.supportedSchemaVersion,
      namespace: 'drops.streak_boost',
      previous: _streakBoost,
      fallback: StreakBoost.fallback,
      parse: (m) => StreakBoost.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'drops.streak_boost',
      isDefault: isDefault,
    );
    _revivePricing = _parseOne<RevivePricing>(
      raw: raw,
      key: ConfigKeys.economyRevivePricing,
      supported: RevivePricing.supportedSchemaVersion,
      namespace: 'economy.revive_pricing',
      previous: _revivePricing,
      fallback: RevivePricing.fallback,
      parse: (m) => RevivePricing.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'economy.revive_pricing',
      isDefault: isDefault,
    );
    _shopPrices = _parseOne<ShopPrices>(
      raw: raw,
      key: ConfigKeys.economyShopPrices,
      supported: ShopPrices.supportedSchemaVersion,
      namespace: 'economy.shop_prices',
      previous: _shopPrices,
      fallback: ShopPrices.fallback,
      parse: (m) => ShopPrices.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'economy.shop_prices',
      isDefault: isDefault,
    );
    _xpCurve = _parseOne<XpCurve>(
      raw: raw,
      key: ConfigKeys.progressionXpCurve,
      supported: XpCurve.supportedSchemaVersion,
      namespace: 'progression.xp_curve',
      previous: _xpCurve,
      fallback: XpCurve.fallback,
      parse: (m) => XpCurve.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'progression.xp_curve',
      isDefault: isDefault,
    );
    _levelRewards = _parseOne<LevelRewardsTable>(
      raw: raw,
      key: ConfigKeys.progressionLevelRewards,
      supported: LevelRewardsTable.supportedSchemaVersion,
      namespace: 'progression.level_rewards',
      previous: _levelRewards,
      fallback: LevelRewardsTable.fallback,
      parse: (m) => LevelRewardsTable.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'progression.level_rewards',
      isDefault: isDefault,
    );
    _featureFlags = _parseOne<FeatureFlags>(
      raw: raw,
      key: ConfigKeys.flagsFeatureFlags,
      supported: FeatureFlags.supportedSchemaVersion,
      namespace: 'flags.feature_flags',
      previous: _featureFlags,
      fallback: FeatureFlags.fallback,
      parse: (m) => FeatureFlags.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'flags.feature_flags',
      isDefault: isDefault,
    );
    _killSwitches = _parseOne<KillSwitches>(
      raw: raw,
      key: ConfigKeys.flagsKillSwitches,
      supported: KillSwitches.supportedSchemaVersion,
      namespace: 'flags.kill_switches',
      previous: _killSwitches,
      fallback: KillSwitches.fallback,
      parse: (m) => KillSwitches.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'flags.kill_switches',
      isDefault: isDefault,
    );
    _abAssignment = _parseOne<AbAssignment>(
      raw: raw,
      key: ConfigKeys.experimentsAbAssignment,
      supported: AbAssignment.supportedSchemaVersion,
      namespace: 'experiments.ab_assignment',
      previous: _abAssignment,
      fallback: AbAssignment.fallback,
      parse: (m) => AbAssignment.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'experiments.ab_assignment',
      isDefault: isDefault,
    );
    _challengesCyclePlan = _parseOne<ChallengesCyclePlan>(
      raw: raw,
      key: ConfigKeys.challengesCyclePlan,
      supported: ChallengesCyclePlan.supportedSchemaVersion,
      namespace: 'challenges.cycle_plan',
      previous: _challengesCyclePlan,
      fallback: ChallengesCyclePlan.fallback,
      parse: (m) => ChallengesCyclePlan.fromJson(m),
      versionOf: (v) => v.schemaVersion,
      versions: versions,
      versionKey: 'challenges.cycle_plan',
      isDefault: isDefault,
    );

    return versions;
  }

  T _parseOne<T>({
    required Map<String, String> raw,
    required String key,
    required int supported,
    required String namespace,
    required T previous,
    required T fallback,
    required T Function(Map<String, dynamic>) parse,
    required int Function(T) versionOf,
    required Map<String, int> versions,
    required String versionKey,
    required bool isDefault,
  }) {
    final s = raw[key];
    if (s == null || s.isEmpty) {
      versions[versionKey] = versionOf(previous);
      return previous;
    }
    try {
      final decoded = json.decode(s);
      if (decoded is! Map) {
        throw const FormatException('payload is not a JSON object');
      }
      final map = decoded.cast<String, dynamic>();
      final seen = (map['schema_version'] as num?)?.toInt() ?? 0;
      if (seen > supported) {
        unawaited(_analytics.logSchemaMismatch(
          namespace: namespace,
          schemaVersionSeen: seen,
          schemaVersionSupported: supported,
        ));
        developer.log(
          'schema mismatch for $namespace: seen=$seen supported=$supported. '
          'Falling back.',
          name: _logName,
          level: 900,
        );
        versions[versionKey] = versionOf(previous);
        return previous;
      }
      final parsed = parse(map);
      _lastGoodRaw[key] = s;
      versions[versionKey] = versionOf(parsed);
      return parsed;
    } catch (e, st) {
      unawaited(_analytics.logParseError(
        namespace: namespace,
        schemaVersionSeen: _peekSchemaVersion(s),
        error: e.toString(),
      ));
      developer.log(
        'parse error for $namespace: $e',
        name: _logName,
        level: 1000,
        error: e,
        stackTrace: st,
      );
      // Keep last good if we have one; else hand back the fallback.
      versions[versionKey] = versionOf(previous);
      return previous;
    }
  }

  DropRatesConfig _parseDropRates(
    Map<String, String> raw, {
    required bool isDefault,
    required Map<String, int> versions,
  }) {
    final ratesRaw = raw[ConfigKeys.dropsRates];
    final distRaw = raw[ConfigKeys.dropsPowerupDistribution];
    if (ratesRaw == null || distRaw == null) {
      versions['drops.rates'] = _dropRates.schemaVersion;
      return _dropRates;
    }
    try {
      final ratesMap =
          (json.decode(ratesRaw) as Map).cast<String, dynamic>();
      final distMap =
          (json.decode(distRaw) as Map).cast<String, dynamic>();
      final ratesVersion =
          (ratesMap['schema_version'] as num?)?.toInt() ?? 0;
      final distVersion =
          (distMap['schema_version'] as num?)?.toInt() ?? 0;
      final supported = DropRatesConfig.supportedSchemaVersion;
      if (ratesVersion > supported || distVersion > supported) {
        unawaited(_analytics.logSchemaMismatch(
          namespace: 'drops.rates',
          schemaVersionSeen:
              ratesVersion > supported ? ratesVersion : distVersion,
          schemaVersionSupported: supported,
        ));
        versions['drops.rates'] = _dropRates.schemaVersion;
        return _dropRates;
      }
      final merged = <String, dynamic>{
        'schema_version': ratesVersion,
        'buckets': ratesMap['buckets'] ?? const [],
        'powerup_distribution':
            distMap['distribution'] ?? const <String, dynamic>{},
      };
      final parsed = DropRatesConfig.fromJson(merged);
      _lastGoodRaw[ConfigKeys.dropsRates] = ratesRaw;
      _lastGoodRaw[ConfigKeys.dropsPowerupDistribution] = distRaw;
      versions['drops.rates'] = parsed.schemaVersion;
      return parsed;
    } catch (e, st) {
      unawaited(_analytics.logParseError(
        namespace: 'drops.rates',
        schemaVersionSeen: _peekSchemaVersion(ratesRaw),
        error: e.toString(),
      ));
      developer.log(
        'parse error for drops.rates: $e',
        name: _logName,
        level: 1000,
        error: e,
        stackTrace: st,
      );
      versions['drops.rates'] = _dropRates.schemaVersion;
      return _dropRates;
    }
  }

  int? _peekSchemaVersion(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final decoded = json.decode(s);
      if (decoded is Map) {
        final v = decoded['schema_version'];
        if (v is num) return v.toInt();
      }
    } catch (_) {}
    return null;
  }

  // -------------------------------------------------------------------
  // Typed getters (60fps safe — pure map lookups + analytics emit)
  // -------------------------------------------------------------------

  WaveCurve waveCurve({required int world, required int wave}) {
    final v = _waveCurves.lookup(world: world, wave: wave);
    unawaited(_analytics.logValueUsed(
      key: ConfigKeys.difficultyWaveCurves,
      source: ConfigValueSource.remote,
      context: 'world=$world,wave=$wave',
    ));
    return v;
  }

  EnemyScaling enemyScaling({required int world}) {
    final v = _enemyScaling.lookup(world: world);
    unawaited(_analytics.logValueUsed(
      key: ConfigKeys.difficultyEnemyScaling,
      source: ConfigValueSource.remote,
      context: 'world=$world',
    ));
    return v;
  }

  EffectiveDropRates dropRates({
    required int world,
    required int wave,
    required int failureStreak,
  }) {
    final v = _dropRates.lookup(
      world: world,
      wave: wave,
      failureStreak: failureStreak,
      streakBoost: _streakBoost,
    );
    unawaited(_analytics.logValueUsed(
      key: ConfigKeys.dropsRates,
      source: ConfigValueSource.remote,
      context: 'world=$world,wave=$wave,streak=$failureStreak',
    ));
    return v;
  }

  StreakBoost streakBoost() => _streakBoost;

  int reviveCostGems({required int wave, required bool isBoss}) {
    final v = _revivePricing.costFor(wave: wave, isBoss: isBoss);
    unawaited(_analytics.logValueUsed(
      key: ConfigKeys.economyRevivePricing,
      source: ConfigValueSource.remote,
      context: 'wave=$wave,boss=$isBoss',
    ));
    return v;
  }

  ShopPrices shopPrices() => _shopPrices;

  XpCurve xpCurve() => _xpCurve;

  ChallengesCyclePlan challengesCyclePlan() => _challengesCyclePlan;

  LevelRewards? levelRewardsFor({required int level}) {
    final r = _levelRewards.lookup(level: level);
    if (r != null) {
      unawaited(_analytics.logValueUsed(
        key: ConfigKeys.progressionLevelRewards,
        source: ConfigValueSource.remote,
        context: 'level=$level',
      ));
    }
    return r;
  }

  bool isFeatureEnabled(String featureKey) {
    final forced = ForcedVariants.isEnabled
        ? ForcedVariants.instance.get(featureKey)
        : null;
    if (forced != null) {
      final v = forced.toLowerCase() == 'true';
      unawaited(_analytics.logValueUsed(
        key: ConfigKeys.flagsFeatureFlags,
        source: ConfigValueSource.forced,
        context: featureKey,
      ));
      return v;
    }
    final v = _featureFlags.isEnabled(featureKey);
    unawaited(_analytics.logValueUsed(
      key: ConfigKeys.flagsFeatureFlags,
      source: ConfigValueSource.remote,
      context: featureKey,
    ));
    return v;
  }

  bool isKillSwitchOn(String killSwitchKey) {
    final forced = ForcedVariants.isEnabled
        ? ForcedVariants.instance.get(killSwitchKey)
        : null;
    if (forced != null) {
      final v = forced.toLowerCase() == 'true';
      unawaited(_analytics.logValueUsed(
        key: ConfigKeys.flagsKillSwitches,
        source: ConfigValueSource.forced,
        context: killSwitchKey,
      ));
      return v;
    }
    final v = _killSwitches.isOn(killSwitchKey);
    unawaited(_analytics.logValueUsed(
      key: ConfigKeys.flagsKillSwitches,
      source: ConfigValueSource.remote,
      context: killSwitchKey,
    ));
    return v;
  }

  String abVariant(String experimentKey) {
    final forced = ForcedVariants.isEnabled
        ? ForcedVariants.instance.get(experimentKey)
        : null;
    if (forced != null) {
      unawaited(_analytics.logValueUsed(
        key: ConfigKeys.experimentsAbAssignment,
        source: ConfigValueSource.forced,
        context: experimentKey,
      ));
      unawaited(_analytics.logVariantAssigned(
        experiment: experimentKey,
        variant: forced,
        source: ConfigValueSource.forced,
      ));
      return forced;
    }
    final v = _abAssignment.variantFor(experimentKey);
    unawaited(_analytics.logValueUsed(
      key: ConfigKeys.experimentsAbAssignment,
      source: ConfigValueSource.remote,
      context: experimentKey,
    ));
    unawaited(_analytics.logVariantAssigned(
      experiment: experimentKey,
      variant: v,
      source: ConfigValueSource.remote,
    ));
    return v;
  }
}
