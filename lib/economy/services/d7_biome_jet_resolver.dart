/// Resolves the Day-7 biome-matched jet reward at session start. See
/// /Remote Config/CLIENT_RUNTIME_SPEC.md Runtime 2 for the full spec.
///
/// Pure function — caller provides player state + the relevant slice of
/// remote config. No Firebase coupling.
library;

class D7Reward {
  final D7RewardKind kind;
  /// Populated when [kind] == [D7RewardKind.jet].
  final String? jetId;
  /// Populated when [kind] == [D7RewardKind.fallback]. Raw prize string
  /// from remote config (e.g. "epic_chest + 50gem"). Caller parses it
  /// with the same parser used for challenge stage prizes.
  final String? rawFallbackPrize;

  const D7Reward._(this.kind, {this.jetId, this.rawFallbackPrize});

  factory D7Reward.jet(String jetId) =>
      D7Reward._(D7RewardKind.jet, jetId: jetId);

  factory D7Reward.fallback(String rawPrize) =>
      D7Reward._(D7RewardKind.fallback, rawFallbackPrize: rawPrize);
}

enum D7RewardKind { jet, fallback }

class D7BiomeJetResolver {
  D7BiomeJetResolver._();

  /// Maximum streak week — `economy__daily_reward__v1.rules.week_cap`.
  static const int weekCap = 5;

  /// Resolves the D7 reward for the current streak. Call at session-start
  /// when the player became eligible for D7 since their last claim.
  ///
  /// - [week]: 1..5+, clamped to [weekCap]
  /// - [highestUnlockedBiome]: e.g. 'desert'
  /// - [ownedJets]: jet IDs already in the player's collection
  /// - [biomeToJetMap]: from remote config `biome_to_jet_map`
  /// - [d7FallbackByWeek]: keyed by week number string ("1".."5"),
  ///   value = raw prize string from `weeks.<w>.7.jet_fallback`
  static D7Reward resolve({
    required int week,
    required String highestUnlockedBiome,
    required Set<String> ownedJets,
    required Map<String, String> biomeToJetMap,
    required Map<String, String> d7FallbackByWeek,
  }) {
    final clampedWeek = week.clamp(1, weekCap);
    final matchingJet = biomeToJetMap[highestUnlockedBiome];
    if (matchingJet == null) {
      // Unknown biome — defensive fallback to W1 prize, no jet.
      return D7Reward.fallback(d7FallbackByWeek['1'] ?? '');
    }
    if (!ownedJets.contains(matchingJet)) {
      return D7Reward.jet(matchingJet);
    }
    final raw = d7FallbackByWeek[clampedWeek.toString()] ??
        d7FallbackByWeek['1'] ??
        '';
    return D7Reward.fallback(raw);
  }
}
