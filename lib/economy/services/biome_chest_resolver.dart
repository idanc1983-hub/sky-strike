/// Resolves the `biome_chest_match` runtime token used in monetization
/// offers and challenge prizes. See /Remote Config/CLIENT_RUNTIME_SPEC.md
/// Runtime 1 for the full spec.
///
/// Pure function — no Firebase, no I/O. Easy to unit-test.
class BiomeChestResolver {
  BiomeChestResolver._();

  static const String matchToken = 'biome_chest_match';

  static const Set<String> knownBiomes = {
    'jungle', 'desert', 'sea', 'ice', 'volcano', 'city',
  };

  /// Returns the actual chest ID for the given token + biome. Pass-through
  /// for any other chest ID. Falls back to `jungle_chest` for unknown
  /// biomes (defensive: should not happen in production).
  static String resolve({
    required String chestId,
    required String currentBiome,
  }) {
    if (chestId != matchToken) return chestId;
    final biome = knownBiomes.contains(currentBiome) ? currentBiome : 'jungle';
    return '${biome}_chest';
  }
}
