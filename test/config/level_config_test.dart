import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/config/level_config.dart';

void main() {
  group('LevelConfig.fromLevelsMap — happy paths', () {
    // Minimal fixture mirroring the v2 RC shape for two representative
    // levels: a tier-1-only intro level and a multi-tier boss level.
    final fixture = <String, dynamic>{
      'jungle_1': <String, dynamic>{
        'biome': 'jungle',
        'level': 1,
        'waves': 5,
        'jet_multiplier': 1.0,
        'world_coin_mult': 1.0,
        'enemies': <Map<String, dynamic>>[
          {'tag': 'enemy_1', 'count': 10, 'power': 1.0},
        ],
      },
      'jungle_6': <String, dynamic>{
        'biome': 'jungle',
        'level': 6,
        'waves': 10,
        'jet_multiplier': 1.17,
        'world_coin_mult': 1.0,
        'enemies': <Map<String, dynamic>>[
          {'tag': 'enemy_1', 'count': 18, 'power': 1.15},
          {'tag': 'enemy_2', 'count': 12, 'power': 1.84},
          {'tag': 'enemy_3', 'count': 6, 'power': 2.88},
          {'tag': 'boss', 'count': 1, 'power': 8.62},
        ],
      },
      'city_60': <String, dynamic>{
        'biome': 'city',
        'level': 60,
        'waves': 10,
        'jet_multiplier': 4.5,
        'world_coin_mult': 2.8,
        'enemies': <Map<String, dynamic>>[
          {'tag': 'enemy_1', 'count': 24, 'power': 8.64},
          {'tag': 'boss', 'count': 1, 'power': 112.27},
        ],
      },
    };

    test('parses intro level (jungle_1)', () {
      final cfg = LevelConfig.fromLevelsMap(
        world: 1,
        stage: 1,
        levels: fixture,
      );
      expect(cfg, isNotNull);
      expect(cfg!.level, 1);
      expect(cfg.biome, 'jungle');
      expect(cfg.waves, 5);
      expect(cfg.jetMultiplier, 1.0);
      expect(cfg.worldCoinMult, 1.0);
      expect(cfg.enemies.length, 1);
      expect(cfg.enemies.first.tag, 'enemy_1');
      expect(cfg.enemies.first.count, 10);
      expect(cfg.enemies.first.power, 1.0);
      expect(cfg.isBossLevel, isFalse);
    });

    test('parses boss level (jungle_6) with multi-tier enemies', () {
      final cfg = LevelConfig.fromLevelsMap(
        world: 1,
        stage: 6,
        levels: fixture,
      );
      expect(cfg, isNotNull);
      expect(cfg!.waves, 10);
      expect(cfg.enemies.length, 4);
      expect(cfg.isBossLevel, isTrue);
      expect(cfg.countFor('boss'), 1);
      expect(cfg.powerFor('boss'), 8.62);
      expect(cfg.countFor('enemy_3'), 6);
      expect(cfg.powerFor('enemy_3'), 2.88);
      // Tier not present → defaults
      expect(cfg.countFor('enemy_4'), 0);
      expect(cfg.powerFor('enemy_4'), 1.0);
    });

    test('parses far-end level (city_60)', () {
      final cfg = LevelConfig.fromLevelsMap(
        world: 6,
        stage: 10,
        levels: fixture,
      );
      expect(cfg, isNotNull);
      expect(cfg!.biome, 'city');
      expect(cfg.jetMultiplier, 4.5);
      expect(cfg.worldCoinMult, 2.8);
      expect(cfg.powerFor('boss'), 112.27);
    });
  });

  group('LevelConfig.fromLevelsMap — defensive fallbacks', () {
    test('returns null when world is out of range', () {
      expect(
        LevelConfig.fromLevelsMap(world: 0, stage: 1, levels: const {}),
        isNull,
      );
      expect(
        LevelConfig.fromLevelsMap(world: 7, stage: 1, levels: const {}),
        isNull,
      );
    });

    test('returns null when stage is out of range', () {
      expect(
        LevelConfig.fromLevelsMap(world: 1, stage: 0, levels: const {}),
        isNull,
      );
      expect(
        LevelConfig.fromLevelsMap(world: 1, stage: 11, levels: const {}),
        isNull,
      );
    });

    test('returns null when the key is missing from the map', () {
      expect(
        LevelConfig.fromLevelsMap(
          world: 1,
          stage: 1,
          levels: const <String, dynamic>{'jungle_2': {}},
        ),
        isNull,
      );
    });

    test('returns null when the entry is not a Map', () {
      expect(
        LevelConfig.fromLevelsMap(
          world: 1,
          stage: 1,
          levels: const <String, dynamic>{'jungle_1': 'oops'},
        ),
        isNull,
      );
    });

    test('skips malformed enemy entries without crashing', () {
      final cfg = LevelConfig.fromLevelsMap(
        world: 1,
        stage: 1,
        levels: <String, dynamic>{
          'jungle_1': <String, dynamic>{
            'biome': 'jungle',
            'level': 1,
            'waves': 5,
            'enemies': <dynamic>[
              {'tag': 'enemy_1', 'count': 5, 'power': 1.0},
              'not-a-map', // skipped
              {'count': 3}, // missing tag → skipped
              {'tag': 'enemy_2', 'count': 4, 'power': 2.0},
            ],
          },
        },
      );
      expect(cfg, isNotNull);
      expect(cfg!.enemies.length, 2);
      expect(cfg.enemies.map((e) => e.tag), containsAll(['enemy_1', 'enemy_2']));
    });
  });

  group('keying — biome_<globalLevel>', () {
    test('world 2 stage 1 maps to desert_11', () {
      final cfg = LevelConfig.fromLevelsMap(
        world: 2,
        stage: 1,
        levels: <String, dynamic>{
          'desert_11': <String, dynamic>{
            'biome': 'desert',
            'level': 11,
            'waves': 5,
            'enemies': <dynamic>[],
          },
        },
      );
      expect(cfg, isNotNull);
      expect(cfg!.level, 11);
      expect(cfg.biome, 'desert');
    });

    test('world 4 (ice) stage 5 maps to ice_35', () {
      final cfg = LevelConfig.fromLevelsMap(
        world: 4,
        stage: 5,
        levels: <String, dynamic>{
          'ice_35': <String, dynamic>{
            'biome': 'ice',
            'level': 35,
            'waves': 7,
            'enemies': <dynamic>[],
          },
        },
      );
      expect(cfg, isNotNull);
      expect(cfg!.level, 35);
      expect(cfg.biome, 'ice');
      expect(cfg.waves, 7);
    });
  });
}
