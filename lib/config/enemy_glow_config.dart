import 'dart:convert';
import 'dart:ui';

class EnemyGlowConfig {
  final bool enabled;
  final double blurSigma;
  final double baseOpacity;
  final double pulseAmplitude;
  final int pulsePeriodMs;
  final Map<int, Color> colorByWorld;

  const EnemyGlowConfig({
    required this.enabled,
    required this.blurSigma,
    required this.baseOpacity,
    required this.pulseAmplitude,
    required this.pulsePeriodMs,
    required this.colorByWorld,
  });

  /// Used when Remote Config has not yet been fetched or fails.
  static const EnemyGlowConfig fallback = EnemyGlowConfig(
    enabled: true,
    blurSigma: 8.0,
    baseOpacity: 0.55,
    pulseAmplitude: 0.15,
    pulsePeriodMs: 1200,
    colorByWorld: {
      1: Color(0xFFEF9F27), // Jungle  — amber
      2: Color(0xFFEF9F27), // Ocean   — amber
      3: Color(0xFFEF9F27), // Desert  — amber (live-tune candidate)
      4: Color(0xFF45C4F0), // Volcano — cyan override
      5: Color(0xFFEF9F27), // Arctic  — amber
      6: Color(0xFFEF9F27), // Megacity— amber
    },
  );

  Color colorForWorld(int world) =>
      colorByWorld[world] ?? const Color(0xFFEF9F27);

  /// Parse a hex string like "#EF9F27" or "EF9F27" into a fully opaque Color.
  static Color _hexToColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  /// Build from already-fetched Remote Config primitive values.
  /// `colorsJson` is the JSON-stringified map of world(String)->hex(String).
  factory EnemyGlowConfig.fromRemote({
    required bool enabled,
    required double blurSigma,
    required double baseOpacity,
    required double pulseAmplitude,
    required int pulsePeriodMs,
    required String colorsJson,
  }) {
    final Map<int, Color> colors = {};
    try {
      final decoded = jsonDecode(colorsJson) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        final w = int.tryParse(k);
        if (w != null && v is String) colors[w] = _hexToColor(v);
      });
    } catch (_) {
      // Bad payload -> fall back to baked colour table.
      return EnemyGlowConfig(
        enabled: enabled,
        blurSigma: blurSigma,
        baseOpacity: baseOpacity,
        pulseAmplitude: pulseAmplitude,
        pulsePeriodMs: pulsePeriodMs,
        colorByWorld: fallback.colorByWorld,
      );
    }
    return EnemyGlowConfig(
      enabled: enabled,
      blurSigma: blurSigma,
      baseOpacity: baseOpacity,
      pulseAmplitude: pulseAmplitude,
      pulsePeriodMs: pulsePeriodMs,
      colorByWorld: colors.isEmpty ? fallback.colorByWorld : colors,
    );
  }
}
