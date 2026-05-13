import 'package:flutter_test/flutter_test.dart';
import 'package:skystrike/config/config_schemas/feature_flags.dart';
import 'package:skystrike/config/config_schemas/wave_curve.dart';
import 'package:skystrike/config/config_schemas/xp_curve.dart';

/// The schemas' fromJson is permissive: it parses whatever it gets and
/// preserves the seen schema_version so the service layer can detect a
/// mismatch and fall back to last-good. This test verifies the
/// invariant the service depends on: `seen.schemaVersion` equals the
/// raw value, regardless of supportedSchemaVersion.
void main() {
  group('schema_version mismatch detection', () {
    test('WaveCurveTable preserves schema_version=99', () {
      final t = WaveCurveTable.fromJson(<String, dynamic>{
        'schema_version': 99,
        'waves': <String, dynamic>{
          '1_1': <String, dynamic>{
            'hp_mult': 1.0,
            'speed_mult': 1.0,
            'spawn_count': 8,
            'elites_allowed': false,
            'enemy_fire': false,
            'is_boss': false,
          },
        },
      });
      expect(t.schemaVersion, 99);
      expect(t.schemaVersion, greaterThan(WaveCurveTable.supportedSchemaVersion));
    });

    test('XpCurve preserves schema_version=99', () {
      final c = XpCurve.fromJson(<String, dynamic>{
        'schema_version': 99,
        'level_cap': 100,
        'xp_cumulative': <int>[0, 100, 250],
      });
      expect(c.schemaVersion, 99);
      expect(c.schemaVersion, greaterThan(XpCurve.supportedSchemaVersion));
    });

    test('FeatureFlags preserves schema_version=99', () {
      final f = FeatureFlags.fromJson(<String, dynamic>{
        'schema_version': 99,
        'flags': <String, dynamic>{'some_flag': true},
      });
      expect(f.schemaVersion, 99);
      expect(f.schemaVersion, greaterThan(FeatureFlags.supportedSchemaVersion));
    });

    test('Lower schema_version values are accepted (forward-compat)', () {
      final t = WaveCurveTable.fromJson(<String, dynamic>{
        'schema_version': 0,
        'waves': <String, dynamic>{},
      });
      expect(t.schemaVersion, 0);
      expect(t.schemaVersion,
          lessThanOrEqualTo(WaveCurveTable.supportedSchemaVersion));
    });
  });
}
