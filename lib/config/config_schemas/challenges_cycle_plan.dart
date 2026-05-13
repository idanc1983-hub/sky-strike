/// Per-cycle presentation metadata for the Challenge System.
///
/// Parses `challenges__cycle_plan__v1`:
/// ```
/// {
///   "schema_version": 1,
///   "cycles": {
///     "hunter":   {"display_name": "Iron Skies"},
///     "survivor": {"display_name": "Last Stand"},
///     "treasure": {"display_name": "Golden Sky"},
///     "conqueror":{"display_name": "Star Ascent"}
///   }
/// }
/// ```
///
/// The cycle key matches `ChallengeType.jsonValue`. `display_name` is the
/// hero label rendered above the home-screen challenge bar (e.g. "Iron
/// Skies"). Future fields — background asset path, bar tint, and the
/// 50% / 100% milestone prize references — slot in alongside without a
/// schema bump as long as they're optional with sensible fallbacks.
class ChallengeCyclePlanEntry {
  final String displayName;

  const ChallengeCyclePlanEntry({required this.displayName});

  factory ChallengeCyclePlanEntry.fromJson(Map<String, dynamic> json) {
    return ChallengeCyclePlanEntry(
      displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? (json['display_name'] as String).trim()
          : '',
    );
  }
}

class ChallengesCyclePlan {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, ChallengeCyclePlanEntry> cycles;

  const ChallengesCyclePlan({
    required this.schemaVersion,
    required this.cycles,
  });

  /// Used when the asset / fetch / parse pipeline fails. Names mirror the
  /// designs that ship today; ops can override per-cycle via remote
  /// config without a client release.
  static const ChallengesCyclePlan fallback = ChallengesCyclePlan(
    schemaVersion: supportedSchemaVersion,
    cycles: <String, ChallengeCyclePlanEntry>{
      'hunter': ChallengeCyclePlanEntry(displayName: 'Iron Skies'),
      'survivor': ChallengeCyclePlanEntry(displayName: 'Last Stand'),
      'treasure': ChallengeCyclePlanEntry(displayName: 'Golden Sky'),
      'conqueror': ChallengeCyclePlanEntry(displayName: 'Star Ascent'),
    },
  );

  factory ChallengesCyclePlan.fromJson(Map<String, dynamic> json) {
    final raw = json['cycles'];
    final out = <String, ChallengeCyclePlanEntry>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is Map) {
          out[k] =
              ChallengeCyclePlanEntry.fromJson(v.cast<String, dynamic>());
        }
      });
    }
    return ChallengesCyclePlan(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      cycles: Map<String, ChallengeCyclePlanEntry>.unmodifiable(out),
    );
  }

  /// Looks up a cycle entry by `ChallengeType.jsonValue`. Returns `null`
  /// when the type is missing from the config — the caller should fall
  /// back to a hardcoded display name in that case.
  ChallengeCyclePlanEntry? entryFor(String challengeTypeJsonValue) =>
      cycles[challengeTypeJsonValue];

  @override
  String toString() =>
      'ChallengesCyclePlan(v$schemaVersion, ${cycles.length} cycles)';
}
