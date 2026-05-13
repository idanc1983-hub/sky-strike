/// Boolean flag tables.
///
/// Both `flags__feature_flags__v1` and `flags__kill_switches__v1` share the
/// shape:
/// ```
/// {"schema_version":1, "flags":{"key": true|false, ...}}
/// ```
/// `FeatureFlags` wraps feature toggles (TRUE = enabled).
/// `KillSwitches` wraps kill-switches (TRUE = killed).
class FeatureFlags {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, bool> flags;

  const FeatureFlags({
    required this.schemaVersion,
    required this.flags,
  });

  static const FeatureFlags fallback = FeatureFlags(
    schemaVersion: supportedSchemaVersion,
    flags: <String, bool>{},
  );

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> raw =
        (json['flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = <String, bool>{};
    raw.forEach((k, v) {
      if (v is bool) out[k] = v;
    });
    return FeatureFlags(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      flags: Map.unmodifiable(out),
    );
  }

  bool isEnabled(String key, {bool fallbackValue = false}) =>
      flags[key] ?? fallbackValue;

  @override
  String toString() =>
      'FeatureFlags(v$schemaVersion, ${flags.length} flags)';
}

/// Same shape as [FeatureFlags] but with kill-switch semantics:
/// `isOn(key)` returns true when the feature should be KILLED.
class KillSwitches {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, bool> flags;

  const KillSwitches({
    required this.schemaVersion,
    required this.flags,
  });

  static const KillSwitches fallback = KillSwitches(
    schemaVersion: supportedSchemaVersion,
    flags: <String, bool>{},
  );

  factory KillSwitches.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> raw =
        (json['flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = <String, bool>{};
    raw.forEach((k, v) {
      if (v is bool) out[k] = v;
    });
    return KillSwitches(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      flags: Map.unmodifiable(out),
    );
  }

  bool isOn(String key) => flags[key] ?? false;

  @override
  String toString() =>
      'KillSwitches(v$schemaVersion, ${flags.length} switches)';
}
