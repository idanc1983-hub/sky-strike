import '../models/player_segment.dart';
import '../models/shop_bundle.dart';

/// Filters validated bundles down to the set the *current* player should
/// see, applying the rules in the order documented by the build prompt.
class SegmentEvaluator {
  /// Clock injection point — tests pass a fixed value, production uses
  /// [DateTime.now]. Returning UTC keeps the comparison consistent with
  /// server timestamps which always arrive in UTC.
  final DateTime Function() _now;

  SegmentEvaluator({DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc());

  /// Returns the bundles visible to [player] right now, sorted by
  /// `priority` descending. Filtering rules:
  ///
  /// 1. `now ∈ [startsAt, endsAt]`
  /// 2. `targetSegments` empty OR shares ≥1 segment with the player
  /// 3. Every prerequisite passes against the player profile
  /// 4. `purchaseLimit` not yet reached
  /// 5. Cooldown window since last purchase has elapsed
  List<ShopBundle> filter(
    Iterable<ShopBundle> bundles,
    PlayerSegmentData player,
  ) {
    final now = _now();
    final survivors = <ShopBundle>[];
    for (final b in bundles) {
      if (!_inTimeWindow(b, now)) continue;
      if (!_passesSegments(b, player)) continue;
      if (!_passesPrerequisites(b, player)) continue;
      if (!_passesPurchaseLimit(b, player)) continue;
      if (!_passesCooldown(b, player, now)) continue;
      survivors.add(b);
    }
    survivors.sort((a, b) => b.priority.compareTo(a.priority));
    return survivors;
  }

  bool _inTimeWindow(ShopBundle b, DateTime now) {
    return !now.isBefore(b.startsAt) && !now.isAfter(b.endsAt);
  }

  bool _passesSegments(ShopBundle b, PlayerSegmentData p) {
    if (b.targetSegments.isEmpty) return true;
    for (final s in b.targetSegments) {
      if (p.segments.contains(s)) return true;
    }
    return false;
  }

  bool _passesPrerequisites(ShopBundle b, PlayerSegmentData p) {
    for (final pr in b.prerequisites) {
      switch (pr.type) {
        case PrerequisiteType.minLevel:
          final v = pr.value;
          if (v is! int || p.level < v) return false;
          break;
        case PrerequisiteType.completedWorld:
          final v = pr.value;
          if (v is! int || p.completedWorld < v) return false;
          break;
        case PrerequisiteType.minSpend:
          final v = pr.value;
          if (v is! num || p.totalSpendUsd < v.toDouble()) return false;
          break;
        case PrerequisiteType.ownsJet:
          final v = pr.value;
          if (v is! String || !p.ownedJets.contains(v)) return false;
          break;
      }
    }
    return true;
  }

  bool _passesPurchaseLimit(ShopBundle b, PlayerSegmentData p) {
    final limit = b.purchaseLimit;
    if (limit == null) return true;
    final history = p.bundlePurchases[b.id] ?? const [];
    return history.length < limit;
  }

  bool _passesCooldown(ShopBundle b, PlayerSegmentData p, DateTime now) {
    final hours = b.cooldownAfterPurchaseHours;
    if (hours == null) return true;
    final history = p.bundlePurchases[b.id] ?? const [];
    if (history.isEmpty) return true;
    final lastMs = history.last;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs).toUtc();
    final earliestNext = last.add(Duration(hours: hours));
    return !now.isBefore(earliestNext);
  }
}
