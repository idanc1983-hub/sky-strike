/// Visual theme of a [ShopBundle] — banner art, accents, optional particle.
///
/// Field values come from server JSON. Hex strings are parsed to [Color] at
/// the UI boundary via `AppColors.fromHex` to keep this model `flutter`-free.
class BundleTheme {
  final String themeId;
  final String bannerAsset;
  final String accentColorHex;
  final String backgroundColorHex;
  final String? particleEffect;

  const BundleTheme({
    required this.themeId,
    required this.bannerAsset,
    required this.accentColorHex,
    required this.backgroundColorHex,
    this.particleEffect,
  });

  /// Builds a [BundleTheme] from JSON. Missing required fields default to
  /// safe sentinels rather than throwing — invalid records are surfaced by
  /// `BundleValidator`, not by parse-time crashes.
  factory BundleTheme.fromJson(Map<String, dynamic> json) {
    return BundleTheme(
      themeId: (json['themeId'] as String?) ?? '',
      bannerAsset: (json['bannerAsset'] as String?) ?? '',
      accentColorHex: (json['accentColorHex'] as String?) ?? '#3B6D11',
      backgroundColorHex: (json['backgroundColorHex'] as String?) ?? '#0a1a0a',
      particleEffect: json['particleEffect'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeId': themeId,
        'bannerAsset': bannerAsset,
        'accentColorHex': accentColorHex,
        'backgroundColorHex': backgroundColorHex,
        if (particleEffect != null) 'particleEffect': particleEffect,
      };
}
