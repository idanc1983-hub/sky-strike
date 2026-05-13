/// A/B experiment variant assignments.
///
/// Parses `experiments__ab_assignment__v1`:
/// ```
/// {"schema_version":1,
///  "experiments":{"first_purchase_offer":"control", "hud_layout":"compact"}}
/// ```
///
/// In production, Firebase conditions evaluate per-user and the served
/// payload contains the chosen variant. The client never re-buckets.
class AbAssignment {
  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, String> experiments;

  const AbAssignment({
    required this.schemaVersion,
    required this.experiments,
  });

  static const AbAssignment fallback = AbAssignment(
    schemaVersion: supportedSchemaVersion,
    experiments: <String, String>{},
  );

  factory AbAssignment.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> raw =
        (json['experiments'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (v is String) out[k] = v;
    });
    return AbAssignment(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      experiments: Map.unmodifiable(out),
    );
  }

  /// Variant for [experimentKey], or "control" if not configured.
  String variantFor(String experimentKey) =>
      experiments[experimentKey] ?? 'control';

  @override
  String toString() =>
      'AbAssignment(v$schemaVersion, ${experiments.length} experiments)';
}
