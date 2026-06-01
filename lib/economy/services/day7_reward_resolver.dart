import 'dart:math';

import '../state/reward.dart';
import 'chest_reward_resolver.dart';

/// Biome ordering mirrors WorldMap / Jets — worldIndex (1..6) = biome
/// position. Index 0 is 1-based padding so the list can be indexed by
/// `currentWorld` directly. Keep in sync with jets_screen's
/// `_biomeToWorld`.
const List<String> kDay7WorldToBiome = [
  '', // 1-based padding
  'jungle',
  'desert',
  'sea',
  'ice',
  'volcano',
  'city',
];

/// Biome → jet code-id. Code-ids must match the keys used by
/// `EconomyState._ownedJets` and `jets_screen._codeIdToRcName`.
const Map<String, String> kDay7BiomeToJetCodeId = {
  'jungle': 'jet_player',
  'desert': 'wraith_x',
  'sea': 'specter',
  'ice': 'viper',
  'volcano': 'inferno',
  'city': 'phantom',
};

/// Outcome of resolving a Day-7 reward. Either a jet drop (the biome
/// jet the player doesn't yet own) OR the fallback bundle, never both
/// — mirrors the calendar tile's "jet OR fallback" semantics.
class Day7ResolvedReward {
  final Reward reward;

  /// True when the resolver granted the biome jet (i.e. the player did
  /// not previously own it). Lets the caller drive a one-shot
  /// "jet unlocked" cinematic.
  final bool grantedBiomeJet;

  const Day7ResolvedReward({
    required this.reward,
    required this.grantedBiomeJet,
  });
}

/// Resolves the Day-7 streak reward from the same RC entry the calendar
/// tile renders, so the granted reward always matches what the player
/// sees on the tile.
///
/// Algorithm (matches `_resolveJetReward` in daily_reward_screen):
/// 1. Base coin + gem from the RC entry.
/// 2. Optional chest field rolled via [ChestRewardResolver].
/// 3. `jet: "biome_match"` resolves to the player's current-biome jet
///    code-id via [kDay7WorldToBiome] + [kDay7BiomeToJetCodeId].
///    - Unowned → grant the jet (via the [Reward.jet] field).
///    - Owned   → grant the parsed `jet_fallback` bundle instead.
/// 4. `jet: "<explicit-id>"` grants that jet if unowned, else falls
///    back to the bundle.
class Day7RewardResolver {
  Day7RewardResolver._();

  static Day7ResolvedReward resolve({
    required Map<String, dynamic>? rcEntry,
    required int currentWorld,
    required bool Function(String jetCodeId) ownsJet,
    required Map<String, dynamic>? Function(String chestId)
        chestDefinitionLookup,
    required Random rng,
  }) {
    if (rcEntry == null) {
      return const Day7ResolvedReward(
        reward: Reward.empty,
        grantedBiomeJet: false,
      );
    }

    final coin = (rcEntry['coin'] as num?)?.toInt() ?? 0;
    final gem = (rcEntry['gem'] as num?)?.toInt() ?? 0;
    final jet = rcEntry['jet'] as String?;
    final jetFallback = rcEntry['jet_fallback'] as String?;
    final chest = rcEntry['chest'] as String?;

    var reward = Reward(coins: coin, gems: gem);

    if (chest != null && chest.isNotEmpty) {
      final def = chestDefinitionLookup(chest);
      if (def != null) {
        final roll = ChestRewardResolver.resolve(definition: def, rng: rng);
        reward = reward.plus(roll.reward);
        if (roll.hasJet && !ownsJet(roll.jetId!)) {
          reward = reward.copyWithJet(roll.jetId);
        }
      }
    }

    var grantedJet = false;
    if (jet != null && jet.isNotEmpty) {
      final jetCodeId = _resolveJetCodeId(jet, currentWorld);
      if (jetCodeId != null && !ownsJet(jetCodeId)) {
        // Carry only one jet on a Reward — if a chest already populated
        // it, the biome jet wins (it's the headline D7 reward).
        reward = reward.copyWithJet(jetCodeId);
        grantedJet = true;
      } else if (jetFallback != null && jetFallback.isNotEmpty) {
        reward = reward.plus(_parseFallbackBundle(
          raw: jetFallback,
          chestDefinitionLookup: chestDefinitionLookup,
          rng: rng,
        ));
      }
    }

    return Day7ResolvedReward(
      reward: reward,
      grantedBiomeJet: grantedJet,
    );
  }

  /// Returns the jet code-id for [jet] in the context of [currentWorld].
  /// `biome_match` resolves through [kDay7WorldToBiome]; any other value
  /// is treated as a literal jet code-id and returned unchanged.
  static String? resolveJetCodeId(String jet, int currentWorld) =>
      _resolveJetCodeId(jet, currentWorld);

  static String? _resolveJetCodeId(String jet, int currentWorld) {
    if (jet != 'biome_match') return jet;
    final biome = (currentWorld >= 1 && currentWorld < kDay7WorldToBiome.length)
        ? kDay7WorldToBiome[currentWorld]
        : 'jungle';
    return kDay7BiomeToJetCodeId[biome];
  }

  /// Parses bundle strings like `"epic_chest + 50gem"` into a Reward.
  /// Unknown tokens are silently ignored — same tolerance as the
  /// display-side parser.
  static Reward _parseFallbackBundle({
    required String raw,
    required Map<String, dynamic>? Function(String) chestDefinitionLookup,
    required Random rng,
  }) {
    var reward = Reward.empty;
    for (final part in raw.split('+').map((s) => s.trim())) {
      if (part.isEmpty) continue;
      final amount = RegExp(
        r'^(\d+)\s*(gem|gems|coin|coins)$',
        caseSensitive: false,
      ).firstMatch(part);
      if (amount != null) {
        final n = int.parse(amount.group(1)!);
        final unit = amount.group(2)!.toLowerCase();
        reward = reward.plus(unit.startsWith('gem')
            ? Reward(gems: n)
            : Reward(coins: n));
        continue;
      }
      if (part.endsWith('_chest')) {
        final def = chestDefinitionLookup(part);
        if (def == null) continue;
        final roll = ChestRewardResolver.resolve(definition: def, rng: rng);
        reward = reward.plus(roll.reward);
      }
    }
    return reward;
  }
}
