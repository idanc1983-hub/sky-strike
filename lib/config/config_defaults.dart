import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart' show rootBundle;

import 'config_keys.dart';

/// Loads the baked-in defaults shipped at `assets/config/defaults.json`.
///
/// Keys are the canonical Firebase Remote Config names; values are
/// JSON-stringified payloads matching each schema's `fromJson`.
class ConfigDefaults {
  ConfigDefaults._();

  /// Load defaults from the asset bundle. Returns a map of
  /// Firebase-key -> JSON-stringified payload. Missing or unreadable
  /// asset returns an empty map (service will fall back to per-schema
  /// static defaults).
  static Future<Map<String, String>> load() async {
    try {
      final raw = await rootBundle.loadString('assets/config/defaults.json');
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        developer.log(
          'defaults.json root is not a JSON object',
          name: 'remote_config',
          level: 900,
        );
        return <String, String>{};
      }
      final out = <String, String>{};
      decoded.forEach((k, v) {
        if (k is String && v is String) {
          out[k] = v;
        }
      });
      _warnMissingKeys(out);
      return out;
    } catch (e, st) {
      developer.log(
        'failed to load defaults.json: $e',
        name: 'remote_config',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      return <String, String>{};
    }
  }

  static void _warnMissingKeys(Map<String, String> loaded) {
    for (final key in ConfigKeys.all) {
      if (!loaded.containsKey(key)) {
        developer.log(
          'defaults.json missing key: $key',
          name: 'remote_config',
          level: 900,
        );
      }
    }
  }
}
