import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/economy/services/chest_reward_resolver.dart';

void main() {
  group('ChestRewardResolver', () {
    test('rolls coins inclusively within [coin_min, coin_max]', () {
      const trials = 500;
      final rng = Random(42);
      for (var i = 0; i < trials; i++) {
        final result = ChestRewardResolver.resolve(
          definition: const {
            'coin_min': 50,
            'coin_max': 200,
            'gem_min': 0,
            'gem_max': 0,
            'jet_drop_chance': 0,
            'jet_id': null,
          },
          rng: rng,
        );
        expect(result.reward.coins, inInclusiveRange(50, 200));
        expect(result.reward.gems, equals(0));
        expect(result.hasJet, isFalse);
      }
    });

    test('rolls gems inclusively within [gem_min, gem_max]', () {
      final rng = Random(7);
      final result = ChestRewardResolver.resolve(
        definition: const {
          'coin_min': 0,
          'coin_max': 0,
          'gem_min': 3,
          'gem_max': 6,
          'jet_drop_chance': 0,
          'jet_id': null,
        },
        rng: rng,
      );
      expect(result.reward.gems, inInclusiveRange(3, 6));
    });

    test('jet drops only when chance > 0 and jet_id is non-empty', () {
      final rng = Random(123);
      final never = ChestRewardResolver.resolve(
        definition: const {
          'coin_min': 0,
          'coin_max': 0,
          'gem_min': 0,
          'gem_max': 0,
          'jet_drop_chance': 0,
          'jet_id': 'Wraith X',
        },
        rng: rng,
      );
      expect(never.hasJet, isFalse);

      final always = ChestRewardResolver.resolve(
        definition: const {
          'coin_min': 0,
          'coin_max': 0,
          'gem_min': 0,
          'gem_max': 0,
          'jet_drop_chance': 1,
          'jet_id': 'Specter',
        },
        rng: rng,
      );
      expect(always.hasJet, isTrue);
      expect(always.jetId, equals('Specter'));
    });

    test('jet_id null suppresses jet roll even with non-zero chance', () {
      final rng = Random(1);
      final result = ChestRewardResolver.resolve(
        definition: const {
          'coin_min': 0,
          'coin_max': 0,
          'gem_min': 0,
          'gem_max': 0,
          'jet_drop_chance': 1,
          'jet_id': null,
        },
        rng: rng,
      );
      expect(result.hasJet, isFalse);
    });

    test('degenerate max <= min returns min, never crashes', () {
      final rng = Random(0);
      final result = ChestRewardResolver.resolve(
        definition: const {
          'coin_min': 100,
          'coin_max': 50,
          'gem_min': 0,
          'gem_max': 0,
          'jet_drop_chance': 0,
          'jet_id': null,
        },
        rng: rng,
      );
      expect(result.reward.coins, equals(100));
    });

    test('missing fields default to zero', () {
      final rng = Random(0);
      final result = ChestRewardResolver.resolve(
        definition: const <String, dynamic>{},
        rng: rng,
      );
      expect(result.reward.coins, equals(0));
      expect(result.reward.gems, equals(0));
      expect(result.hasJet, isFalse);
    });
  });
}
