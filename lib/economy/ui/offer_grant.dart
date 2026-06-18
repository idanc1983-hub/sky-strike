import 'dart:math';

import '../../config/remote_config_service.dart';
import '../services/chest_reward_resolver.dart';
import '../services/offer_reward_parser.dart';
import '../state/economy_state.dart';

/// Applies parsed monetization-offer rewards to [economy].
///
/// `coin` / `gem` / `powerupPack` items are granted by
/// [EconomyState.applyOfferRewards]. `chest` tokens are resolved *here*
/// against Remote Config (so the economy layer stays RC-free) and granted
/// via [EconomyState.grantChest].
///
/// Returns the raw tokens that could not be granted — unknown tokens, or
/// the runtime `biome_chest_match` token, which needs in-run biome context
/// the offer popups don't have. Callers should log these rather than drop
/// them silently.
class OfferGrant {
  OfferGrant._();

  /// Single session RNG so chest rolls look random to the player; tests
  /// pin outcomes by calling [ChestRewardResolver.resolve] directly.
  static final Random _rng = Random();

  static List<String> apply(EconomyState economy, List<OfferRewardItem> items) {
    // EconomyState grants coin/gem/powerupPack and hands back the tokens it
    // can't resolve without Remote Config (chest + unknown).
    final leftover = economy.applyOfferRewards(items);
    final unresolved = <String>[];
    for (final token in leftover) {
      final def = RemoteConfigService.I.chests.byId(token);
      if (def == null) {
        // Not a known chest id (e.g. `biome_chest_match` or a typo) — pass
        // it back so the caller can surface the gap.
        unresolved.add(token);
        continue;
      }
      final result = ChestRewardResolver.resolve(
        definition: <String, dynamic>{
          'coin_min': def.coinMin,
          'coin_max': def.coinMax,
          'gem_min': def.gemMin,
          'gem_max': def.gemMax,
          'jet_drop_chance': def.jetDropChance,
          'jet_id': def.jetId,
        },
        rng: _rng,
      );
      economy.grantChest(
        coins: result.reward.coins,
        gems: result.reward.gems,
        jetId: result.hasJet ? result.jetId : null,
      );
    }
    return unresolved;
  }
}
