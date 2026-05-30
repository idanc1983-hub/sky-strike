/// Parses prize strings from the RC challenge stage ladder
/// (`challenge_stages.<cycle_id>[i].prize`) into a renderable
/// {asset, amount, label} tuple.
///
/// Examples handled:
///   - "20coin"                       → coin, 20
///   - "50gem"                        → gem, 50
///   - "unique_chest"                 → unique chest, 1
///   - "biome_chest_match"            → biome chest, 1
///   - "100coin+ unique_chest"        → unique chest, 1 (chest wins)
///   - "biome_chest_match + 50gem + 500coin" → biome chest, 1
///
/// Compound prizes prefer chest > gem > coin so the UI surfaces the
/// most visually striking element.
class ChallengePrize {
  final String asset;
  final int amount;
  final String label;
  /// Non-null when this prize is (or contains) a chest — caller can use
  /// it to look up the chest's contents via `RemoteConfigService.chests`
  /// and open a "what's inside" popup on tap.
  final String? chestId;
  const ChallengePrize({
    required this.asset,
    required this.amount,
    required this.label,
    this.chestId,
  });

  static const ChallengePrize unknown = ChallengePrize(
    asset: 'assets/ui/icon_coin.png',
    amount: 0,
    label: '',
  );
}

ChallengePrize parseChallengePrize(String raw) {
  final parts = raw.split(RegExp(r'\s*\+\s*'));

  ChallengePrize? chest;
  ChallengePrize? gem;
  ChallengePrize? coin;

  for (final partRaw in parts) {
    final part = partRaw.trim();
    if (part.isEmpty) continue;

    final coinMatch = RegExp(r'^(\d+)\s*coin$').firstMatch(part);
    if (coinMatch != null) {
      coin = ChallengePrize(
        asset: 'assets/ui/icon_coin.png',
        amount: int.parse(coinMatch.group(1)!),
        label: '${coinMatch.group(1)}',
      );
      continue;
    }
    final gemMatch = RegExp(r'^(\d+)\s*gem$').firstMatch(part);
    if (gemMatch != null) {
      gem = ChallengePrize(
        asset: 'assets/ui/icon_gem.png',
        amount: int.parse(gemMatch.group(1)!),
        label: '${gemMatch.group(1)}',
      );
      continue;
    }
    if (part.endsWith('_chest') || part.contains('chest')) {
      chest = ChallengePrize(
        asset: _chestAssetFor(part),
        amount: 1,
        label: _chestLabelFor(part),
        // biome_chest_match has no fixed chest_id (it resolves per biome
        // at claim time), so don't expose it as tappable — there's no
        // single chest definition to preview.
        chestId: part == 'biome_chest_match' ? null : part,
      );
    }
  }

  return chest ?? gem ?? coin ?? ChallengePrize.unknown;
}

String _chestAssetFor(String token) {
  switch (token) {
    case 'unique_chest':
      return 'assets/ui/icon_unique_chest.png';
    case 'rare_chest':
      return 'assets/ui/icon_chest_rare.png';
    case 'epic_chest':
      return 'assets/ui/icon_chest_epic.png';
    case 'basic_chest':
      return 'assets/ui/icon_basic_chest.png';
    case 'operation_chest':
    case 'operational_chest':
      return 'assets/ui/icon_chest_operation.png';
    case 'biome_chest_match':
      return 'assets/ui/icon_chest.png';
    default:
      return 'assets/ui/icon_chest.png';
  }
}

String _chestLabelFor(String token) {
  switch (token) {
    case 'unique_chest':
      return 'Unique';
    case 'rare_chest':
      return 'Rare';
    case 'epic_chest':
      return 'Epic';
    case 'basic_chest':
      return 'Basic';
    case 'operation_chest':
    case 'operational_chest':
      return 'Operation';
    case 'biome_chest_match':
      return 'Biome';
    default:
      return 'Chest';
  }
}
