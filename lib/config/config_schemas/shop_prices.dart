/// Shop catalog: jets, bundles, daily deals pool.
///
/// Parses `economy__shop_prices__v1`:
/// ```
/// {"schema_version":1,
///  "jets":{"scout":{"currency":"gems","amount":120,"sku":""}, ...},
///  "bundles":{"starter_pack":{"currency":"usd","amount":299,"sku":"..."}, ...},
///  "daily_deals_pool":["scout","phantom","powerup_bundle"]}
/// ```
class ShopPrices {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, PriceEntry> jets;
  final Map<String, PriceEntry> bundles;
  final List<String> dailyDealsPool;

  const ShopPrices({
    required this.schemaVersion,
    required this.jets,
    required this.bundles,
    required this.dailyDealsPool,
  });

  static const ShopPrices fallback = ShopPrices(
    schemaVersion: supportedSchemaVersion,
    jets: <String, PriceEntry>{},
    bundles: <String, PriceEntry>{},
    dailyDealsPool: <String>[],
  );

  factory ShopPrices.fromJson(Map<String, dynamic> json) {
    Map<String, PriceEntry> parseMap(dynamic raw) {
      final Map<String, dynamic> m =
          (raw as Map?)?.cast<String, dynamic>() ?? const {};
      final out = <String, PriceEntry>{};
      m.forEach((k, v) {
        if (v is Map) {
          out[k] = PriceEntry.fromJson(v.cast<String, dynamic>());
        }
      });
      return out;
    }

    final List rawPool = (json['daily_deals_pool'] as List?) ?? const [];
    final pool = <String>[for (final v in rawPool) if (v is String) v];

    return ShopPrices(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      jets: Map.unmodifiable(parseMap(json['jets'])),
      bundles: Map.unmodifiable(parseMap(json['bundles'])),
      dailyDealsPool: List.unmodifiable(pool),
    );
  }

  @override
  String toString() => 'ShopPrices(v$schemaVersion, ${jets.length} jets, '
      '${bundles.length} bundles, ${dailyDealsPool.length} daily)';
}

class PriceEntry {
  /// One of "gems", "coins", or "usd". For "usd", [amount] is in cents.
  final String currency;
  final int amount;
  final String sku;

  const PriceEntry({
    required this.currency,
    required this.amount,
    required this.sku,
  });

  factory PriceEntry.fromJson(Map<String, dynamic> json) => PriceEntry(
        currency: json['currency'] as String? ?? 'gems',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        sku: json['sku'] as String? ?? '',
      );

  @override
  String toString() => 'PriceEntry($currency, $amount, sku=$sku)';
}
