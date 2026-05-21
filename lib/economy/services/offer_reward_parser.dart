/// Parses monetization offer reward strings into structured items.
///
/// Reward strings come from the xlsx → JSON pipeline as `+`-separated
/// tokens. Examples:
///   "1000coin"                              -> 1 coin item
///   "12000coin + 100gem"                    -> 2 items
///   "epic_chest + 1500coin"                 -> chest + coin
///   "5x_powerup_T1_T3"                      -> powerup pack
///   "biome_chest_match"                     -> runtime-resolved chest
///
/// Pure function — no Flutter, no Firebase. Safe to unit-test.
library;

enum OfferRewardKind { coin, gem, chest, powerupPack, unknown }

class OfferRewardItem {
  final OfferRewardKind kind;
  /// Populated for coin / gem (the amount) and powerupPack (the count).
  final int amount;
  /// Populated for chest (e.g., "epic_chest", "biome_chest_match") and
  /// powerupPack (e.g., "T1_T3").
  final String? id;
  /// Original token, useful for debugging / showing in dev placeholders.
  final String raw;

  const OfferRewardItem({
    required this.kind,
    this.amount = 0,
    this.id,
    required this.raw,
  });

  @override
  String toString() => 'OfferRewardItem($raw)';
}

class OfferRewardParser {
  OfferRewardParser._();

  static const String biomeChestMatchToken = 'biome_chest_match';

  /// Parses a reward string into a list of structured items. Returns an
  /// empty list for null/empty/`"free"`. Unknown tokens come back as
  /// `OfferRewardKind.unknown` with `raw` populated so callers can log
  /// or render a fallback chip.
  static List<OfferRewardItem> parse(String? s) {
    if (s == null) return const [];
    final trimmed = s.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'free') {
      return const [];
    }
    final out = <OfferRewardItem>[];
    for (final partRaw in trimmed.split('+')) {
      final p = partRaw.trim();
      if (p.isEmpty) continue;

      final coinM = RegExp(r'^(\d+)\s*coin', caseSensitive: false).firstMatch(p);
      if (coinM != null) {
        out.add(OfferRewardItem(
            kind: OfferRewardKind.coin,
            amount: int.parse(coinM.group(1)!),
            raw: p));
        continue;
      }

      final gemM = RegExp(r'^(\d+)\s*gem', caseSensitive: false).firstMatch(p);
      if (gemM != null) {
        out.add(OfferRewardItem(
            kind: OfferRewardKind.gem,
            amount: int.parse(gemM.group(1)!),
            raw: p));
        continue;
      }

      if (p.endsWith('_chest') || p == biomeChestMatchToken) {
        out.add(OfferRewardItem(
            kind: OfferRewardKind.chest, id: p, raw: p));
        continue;
      }

      final puM = RegExp(r'^(\d+)x_powerup_(.+)$').firstMatch(p);
      if (puM != null) {
        out.add(OfferRewardItem(
            kind: OfferRewardKind.powerupPack,
            amount: int.parse(puM.group(1)!),
            id: puM.group(2),
            raw: p));
        continue;
      }

      out.add(OfferRewardItem(kind: OfferRewardKind.unknown, raw: p));
    }
    return out;
  }
}
