import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/config/config_keys.dart';
import 'package:skystrike/config/config_schemas/drop_rates.dart';
import 'package:skystrike/config/config_schemas/revive_pricing.dart';
import 'package:skystrike/config/config_schemas/streak_boost.dart';

DropRatesConfig _loadDropRates() {
  final raw = json.decode(File('assets/config/defaults.json').readAsStringSync())
      as Map;
  final rates =
      (json.decode(raw[ConfigKeys.dropsRates] as String) as Map).cast<String, dynamic>();
  final dist = (json.decode(raw[ConfigKeys.dropsPowerupDistribution] as String)
          as Map)
      .cast<String, dynamic>();
  return DropRatesConfig.fromJson(<String, dynamic>{
    'schema_version': rates['schema_version'],
    'buckets': rates['buckets'],
    'powerup_distribution': dist['distribution'],
  });
}

StreakBoost _loadStreakBoost() {
  final raw = json.decode(File('assets/config/defaults.json').readAsStringSync())
      as Map;
  final m = (json.decode(raw[ConfigKeys.dropsStreakBoost] as String) as Map)
      .cast<String, dynamic>();
  return StreakBoost.fromJson(m);
}

RevivePricing _loadRevive() {
  final raw = json.decode(File('assets/config/defaults.json').readAsStringSync())
      as Map;
  final m = (json.decode(raw[ConfigKeys.economyRevivePricing] as String) as Map)
      .cast<String, dynamic>();
  return RevivePricing.fromJson(m);
}

void main() {
  group('DropRates bucket lookup', () {
    final cfg = _loadDropRates();
    final boost = _loadStreakBoost();

    for (int wave = 1; wave <= 10; wave++) {
      test('world 1 wave $wave hits a bucket', () {
        final bucket = cfg.bucketFor(world: 1, wave: wave);
        expect(bucket, isNotNull, reason: 'no bucket covers wave $wave');
      });
    }

    test('failureStreak=5 applies streak boost', () {
      final unboosted = cfg.lookup(
        world: 1,
        wave: 3,
        failureStreak: 0,
        streakBoost: boost,
      );
      final boosted = cfg.lookup(
        world: 1,
        wave: 3,
        failureStreak: 5,
        streakBoost: boost,
      );
      expect(boosted.streakBoostApplied, isTrue);
      expect(unboosted.streakBoostApplied, isFalse);
      expect(boosted.hpProb, greaterThan(unboosted.hpProb));
      expect(boosted.powerupProb, greaterThan(unboosted.powerupProb));
      expect(boosted.gemProb, greaterThan(unboosted.gemProb));
    });

    test('failureStreak=4 does NOT apply streak boost', () {
      final r = cfg.lookup(
        world: 1,
        wave: 3,
        failureStreak: 4,
        streakBoost: boost,
      );
      expect(r.streakBoostApplied, isFalse);
    });

    test('failureStreak=0 does NOT apply boost even with modulo match', () {
      final r = cfg.lookup(
        world: 1,
        wave: 3,
        failureStreak: 0,
        streakBoost: boost,
      );
      expect(r.streakBoostApplied, isFalse);
    });
  });

  group('RevivePricing lookup', () {
    final p = _loadRevive();

    test('waves 1..3 cost 5 gems', () {
      for (int w = 1; w <= 3; w++) {
        expect(p.costFor(wave: w, isBoss: false), 5,
            reason: 'wave $w should cost 5');
      }
    });

    test('waves 4..6 cost 10 gems', () {
      for (int w = 4; w <= 6; w++) {
        expect(p.costFor(wave: w, isBoss: false), 10,
            reason: 'wave $w should cost 10');
      }
    });

    test('waves 7..9 cost 15 gems', () {
      for (int w = 7; w <= 9; w++) {
        expect(p.costFor(wave: w, isBoss: false), 15,
            reason: 'wave $w should cost 15');
      }
    });

    test('isBoss returns boss_cost_gems regardless of wave', () {
      expect(p.costFor(wave: 1, isBoss: true), p.bossCostGems);
      expect(p.costFor(wave: 10, isBoss: true), p.bossCostGems);
    });
  });
}
