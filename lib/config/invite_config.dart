/// Resolved Remote Config values for the Invite Friends feature.
///
/// Mirrors the [EnemyGlowConfig] pattern: primitive `invite__*__v1` keys are
/// registered as code defaults in [RemoteConfigService] and read back into
/// this immutable snapshot. No player-facing value is hardcoded in the widget
/// or state — everything flows through here.
class InviteConfig {
  final bool enabled;
  final int dailyCap;
  final int cooldownHours;
  final int rewardGems;
  final int rewardCoins;
  final String shareMessage;
  final String shareUrl;

  const InviteConfig({
    required this.enabled,
    required this.dailyCap,
    required this.cooldownHours,
    required this.rewardGems,
    required this.rewardCoins,
    required this.shareMessage,
    required this.shareUrl,
  });

  /// Used when Remote Config has not yet been fetched or fails. These are the
  /// same constants registered as RC defaults, kept here so the feature is
  /// fully functional offline / on first launch.
  static const InviteConfig fallback = InviteConfig(
    enabled: true,
    dailyCap: 2,
    cooldownHours: 24,
    rewardGems: 10,
    rewardCoins: 150,
    shareMessage:
        'Come fly with me in SKYSTRIKE — fast top-down aerial combat. Download free:',
    shareUrl:
        'https://play.google.com/store/apps/details?id=com.skystrike.skystrike',
  );

  /// The text handed to the OS share sheet: "{message} {url}" — message, a
  /// single space, then the url.
  String get shareText => '$shareMessage $shareUrl';
}
