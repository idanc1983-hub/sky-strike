/// Snapshot of the current player used for segment & prerequisite checks.
class PlayerSegmentData {
  final String playerId;
  final List<String> segments;
  final int level;
  final double totalSpendUsd;
  final int lastActiveDaysAgo;

  /// Map of `bundleId → list of purchase timestamps` (epoch ms). Persisted
  /// across runs by [MockBundleRepository]; consulted by [SegmentEvaluator]
  /// for `purchaseLimit` and cooldown checks.
  final Map<String, List<int>> bundlePurchases;

  /// Set of jet ids the player owns — used by `ownsJet` prerequisites.
  final Set<String> ownedJets;

  /// Highest world index the player has completed — used by
  /// `completedWorld` prerequisites.
  final int completedWorld;

  const PlayerSegmentData({
    required this.playerId,
    required this.segments,
    required this.level,
    required this.totalSpendUsd,
    required this.lastActiveDaysAgo,
    this.bundlePurchases = const {},
    this.ownedJets = const {},
    this.completedWorld = 0,
  });

  /// Anonymous fallback used when the segments file fails to load. Lets the
  /// shop render an empty state instead of crashing.
  static const PlayerSegmentData anonymous = PlayerSegmentData(
    playerId: 'anonymous',
    segments: [],
    level: 1,
    totalSpendUsd: 0,
    lastActiveDaysAgo: 0,
  );

  /// Returns a copy of this record with [bundlePurchases] augmented to
  /// include a new purchase of [bundleId] at [timestamp].
  PlayerSegmentData withPurchase(String bundleId, int timestamp) {
    final next = Map<String, List<int>>.from(bundlePurchases);
    final existing = List<int>.from(next[bundleId] ?? const []);
    existing.add(timestamp);
    next[bundleId] = existing;
    return PlayerSegmentData(
      playerId: playerId,
      segments: segments,
      level: level,
      totalSpendUsd: totalSpendUsd,
      lastActiveDaysAgo: lastActiveDaysAgo,
      bundlePurchases: next,
      ownedJets: ownedJets,
      completedWorld: completedWorld,
    );
  }

  /// Returns a copy with [segments] replaced — used by the debug overlay
  /// to flip the active player profile for live-ops verification.
  PlayerSegmentData withSegments(List<String> nextSegments) {
    return PlayerSegmentData(
      playerId: playerId,
      segments: nextSegments,
      level: level,
      totalSpendUsd: totalSpendUsd,
      lastActiveDaysAgo: lastActiveDaysAgo,
      bundlePurchases: bundlePurchases,
      ownedJets: ownedJets,
      completedWorld: completedWorld,
    );
  }

  factory PlayerSegmentData.fromJson(Map<String, dynamic> json) {
    final purchases = <String, List<int>>{};
    final raw = json['bundlePurchases'];
    if (raw is Map<String, dynamic>) {
      raw.forEach((k, v) {
        if (v is List) {
          purchases[k] = v.whereType<num>().map((n) => n.toInt()).toList();
        }
      });
    }
    final ownedRaw = json['ownedJets'];
    final owned = (ownedRaw is List)
        ? ownedRaw.whereType<String>().toSet()
        : <String>{};
    return PlayerSegmentData(
      playerId: (json['playerId'] as String?) ?? 'anonymous',
      segments: ((json['segments'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalSpendUsd: (json['totalSpendUsd'] as num?)?.toDouble() ?? 0,
      lastActiveDaysAgo: (json['lastActiveDaysAgo'] as num?)?.toInt() ?? 0,
      bundlePurchases: purchases,
      ownedJets: owned,
      completedWorld: (json['completedWorld'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'segments': segments,
        'level': level,
        'totalSpendUsd': totalSpendUsd,
        'lastActiveDaysAgo': lastActiveDaysAgo,
        'bundlePurchases': bundlePurchases,
        'ownedJets': ownedJets.toList(),
        'completedWorld': completedWorld,
      };
}
