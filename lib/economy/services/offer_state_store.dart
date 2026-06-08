import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-offer client-side state — persisted to SharedPreferences.
///
/// Tracks:
///   1. The randomized cosmetic discount picked for Generic offers
///      (one of {70, 75, 80}). Picked once when the offer instance
///      starts and held until [resetInstance] flips it.
///   2. How many sequential slots have been claimed in Snake / 1+2
///      offers (`claimedCount`). Drives the dimmed-vs-tappable state.
///
/// All reads are async since SharedPreferences is async-only. Callers
/// typically resolve once in `initState` and cache the value in widget
/// state.
class OfferStateStore {
  OfferStateStore._();
  static final OfferStateStore instance = OfferStateStore._();

  static const _kDiscountPrefix = 'monetization.offer.discount_pct.';
  static const _kClaimedPrefix = 'monetization.offer.claimed_slots.';
  static const _kInstancePrefix = 'monetization.offer.instance_id.';
  static const List<int> validDiscountPercents = [70, 75, 80];

  /// Returns the persisted discount % for [assetId]. Rolls a fresh value
  /// from [validDiscountPercents] on first call (or whenever [resetInstance]
  /// has cleared the cached value).
  Future<int> discountFor(String assetId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kDiscountPrefix$assetId';
    final cached = prefs.getInt(key);
    if (cached != null && validDiscountPercents.contains(cached)) {
      return cached;
    }
    final pick = validDiscountPercents[Random().nextInt(validDiscountPercents.length)];
    await prefs.setInt(key, pick);
    return pick;
  }

  /// Flushes the discount + claim progress for [assetId]. Call when a
  /// new sale instance starts (e.g. cycle rotation, cooldown expired).
  Future<void> resetInstance(String assetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kDiscountPrefix$assetId');
    await prefs.remove('$_kClaimedPrefix$assetId');
    await prefs.setString(
      '$_kInstancePrefix$assetId',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Number of slots already claimed for [assetId] (sequential mode).
  Future<int> claimedCount(String assetId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kClaimedPrefix$assetId') ?? 0;
  }

  /// Marks the next slot as claimed. Returns the new count.
  Future<int> incrementClaimed(String assetId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kClaimedPrefix$assetId';
    final next = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, next);
    return next;
  }
}
