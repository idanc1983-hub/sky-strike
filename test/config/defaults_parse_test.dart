import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/config/config_keys.dart';
import 'package:skystrike/config/config_schemas/ab_assignment.dart';
import 'package:skystrike/config/config_schemas/drop_rates.dart';
import 'package:skystrike/config/config_schemas/enemy_scaling.dart';
import 'package:skystrike/config/config_schemas/feature_flags.dart';
import 'package:skystrike/config/config_schemas/level_rewards.dart';
import 'package:skystrike/config/config_schemas/revive_pricing.dart';
import 'package:skystrike/config/config_schemas/shop_prices.dart';
import 'package:skystrike/config/config_schemas/streak_boost.dart';
import 'package:skystrike/config/config_schemas/wave_curve.dart';
import 'package:skystrike/config/config_schemas/xp_curve.dart';

void main() {
  group('defaults.json round-trip', () {
    late Map<String, String> defaults;

    setUpAll(() {
      final file = File('assets/config/defaults.json');
      expect(file.existsSync(), isTrue,
          reason: 'run `python tools/build_config.py` first');
      final decoded = json.decode(file.readAsStringSync()) as Map;
      defaults = decoded.map((k, v) => MapEntry(k as String, v as String));
    });

    test('contains every canonical key', () {
      for (final k in ConfigKeys.all) {
        expect(defaults.containsKey(k), isTrue, reason: 'missing $k');
      }
    });

    Map<String, dynamic> decode(String key) =>
        (json.decode(defaults[key]!) as Map).cast<String, dynamic>();

    test('difficulty__wave_curves__v1 parses', () {
      final t = WaveCurveTable.fromJson(decode(ConfigKeys.difficultyWaveCurves));
      expect(t.schemaVersion, WaveCurveTable.supportedSchemaVersion);
      expect(t.waves.isNotEmpty, isTrue);
      expect(identical(t, WaveCurveTable.fallback), isFalse);
    });

    test('difficulty__enemy_scaling__v1 parses', () {
      final t =
          EnemyScalingTable.fromJson(decode(ConfigKeys.difficultyEnemyScaling));
      expect(t.schemaVersion, EnemyScalingTable.supportedSchemaVersion);
      expect(t.worlds.isNotEmpty, isTrue);
    });

    test('drops__rates__v1 + powerup_distribution merge', () {
      final rates = decode(ConfigKeys.dropsRates);
      final dist = decode(ConfigKeys.dropsPowerupDistribution);
      final merged = <String, dynamic>{
        'schema_version': rates['schema_version'],
        'buckets': rates['buckets'],
        'powerup_distribution': dist['distribution'],
      };
      final cfg = DropRatesConfig.fromJson(merged);
      expect(cfg.schemaVersion, DropRatesConfig.supportedSchemaVersion);
      expect(cfg.buckets.isNotEmpty, isTrue);
      expect(cfg.powerupDistribution.isNotEmpty, isTrue);
    });

    test('drops__streak_boost__v1 parses', () {
      final s = StreakBoost.fromJson(decode(ConfigKeys.dropsStreakBoost));
      expect(s.schemaVersion, StreakBoost.supportedSchemaVersion);
      expect(s.triggerStreakModulo, greaterThan(0));
    });

    test('economy__revive_pricing__v1 parses', () {
      final p = RevivePricing.fromJson(decode(ConfigKeys.economyRevivePricing));
      expect(p.schemaVersion, RevivePricing.supportedSchemaVersion);
      expect(p.waveBrackets.isNotEmpty, isTrue);
      expect(p.bossCostGems, greaterThan(0));
    });

    test('economy__shop_prices__v1 parses', () {
      final s = ShopPrices.fromJson(decode(ConfigKeys.economyShopPrices));
      expect(s.schemaVersion, ShopPrices.supportedSchemaVersion);
      expect(s.jets.isNotEmpty, isTrue);
      expect(s.bundles.isNotEmpty, isTrue);
    });

    test('progression__xp_curve__v1 parses', () {
      final c = XpCurve.fromJson(decode(ConfigKeys.progressionXpCurve));
      expect(c.schemaVersion, XpCurve.supportedSchemaVersion);
      expect(c.levelCap, greaterThan(1));
      expect(c.xpCumulative.first, 0);
      expect(c.xpCumulative.length, greaterThanOrEqualTo(2));
    });

    test('progression__level_rewards__v1 parses', () {
      final r =
          LevelRewardsTable.fromJson(decode(ConfigKeys.progressionLevelRewards));
      expect(r.schemaVersion, LevelRewardsTable.supportedSchemaVersion);
      expect(r.rewards.isNotEmpty, isTrue);
    });

    test('flags__feature_flags__v1 parses', () {
      final f = FeatureFlags.fromJson(decode(ConfigKeys.flagsFeatureFlags));
      expect(f.schemaVersion, FeatureFlags.supportedSchemaVersion);
      expect(f.flags.isNotEmpty, isTrue);
    });

    test('flags__kill_switches__v1 parses', () {
      final k = KillSwitches.fromJson(decode(ConfigKeys.flagsKillSwitches));
      expect(k.schemaVersion, KillSwitches.supportedSchemaVersion);
      expect(k.flags.isNotEmpty, isTrue);
    });

    test('experiments__ab_assignment__v1 parses', () {
      final a =
          AbAssignment.fromJson(decode(ConfigKeys.experimentsAbAssignment));
      expect(a.schemaVersion, AbAssignment.supportedSchemaVersion);
      expect(a.experiments.isNotEmpty, isTrue);
    });
  });
}
