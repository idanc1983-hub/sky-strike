import '../constants/ad_placement_catalog.dart';

/// Outcome of attempting to show a rewarded video.
enum AdShowResult {
  /// Player watched to completion. Caller should grant the reward.
  rewardEarned,

  /// Player dismissed mid-video. No reward should be granted.
  dismissed,

  /// Network/SDK error. Caller should show "Ad unavailable, try again".
  failedToLoad,

  /// Cap-protected: this placement is rate-limited and currently blocked.
  /// Caller should silently fall back (e.g. to gem revive).
  capReached,
}

/// Outcome record. [placement] echoes the request so callers can route
/// correctly through async stacks.
class AdShowOutcome {
  final AdShowResult result;
  final AdPlacement placement;
  final String? errorMessage;

  const AdShowOutcome({
    required this.result,
    required this.placement,
    this.errorMessage,
  });
}

/// Backend-agnostic surface for rewarded video ads. The real
/// implementation wraps `package:google_mobile_ads`; the mock used during
/// development resolves instantly without any network call.
abstract class AdsService {
  /// Shows the rewarded video for [placement]. Returns when the player
  /// dismisses or the reward is earned.
  Future<AdShowOutcome> show(AdPlacement placement);

  /// Whether ads are currently disabled (e.g. the player bought
  /// `remove_ads`). When true, callers should still grant any reward
  /// associated with the placement (per GDD §2.11 — "doubles all rewards
  /// from that placement permanently").
  bool get adsRemoved;

  /// Releases listeners held by the implementation.
  void dispose();
}
