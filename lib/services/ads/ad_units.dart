import 'dart:io' show Platform;

enum RewardedPlacement {
  revive,
  waveComplete,
  dailyGift,
}

class AdUnits {
  AdUnits._();

  static const bool useTestIds = true;

  static const String _testRewarded =
      'ca-app-pub-3940256099942544/5224354917';

  static const String _prodRewardedIOSRevive =
      'ca-app-pub-6794495381248740/8599549478';
  static const String _prodRewardedIOSWaveComplete =
      'ca-app-pub-6794495381248740/1189935535';
  static const String _prodRewardedIOSDailyGift =
      'ca-app-pub-6794495381248740/7504439747';

  static const String _prodRewardedAndroidRevive =
      'ca-app-pub-6794495381248740/3010660963';
  static const String _prodRewardedAndroidWaveComplete =
      'ca-app-pub-6794495381248740/9266598034';
  static const String _prodRewardedAndroidDailyGift =
      'ca-app-pub-6794495381248740/5337441408';

  static String rewardedFor(RewardedPlacement placement) {
    if (useTestIds) return _testRewarded;

    if (Platform.isIOS) {
      switch (placement) {
        case RewardedPlacement.revive:
          return _prodRewardedIOSRevive;
        case RewardedPlacement.waveComplete:
          return _prodRewardedIOSWaveComplete;
        case RewardedPlacement.dailyGift:
          return _prodRewardedIOSDailyGift;
      }
    }
    if (Platform.isAndroid) {
      switch (placement) {
        case RewardedPlacement.revive:
          return _prodRewardedAndroidRevive;
        case RewardedPlacement.waveComplete:
          return _prodRewardedAndroidWaveComplete;
        case RewardedPlacement.dailyGift:
          return _prodRewardedAndroidDailyGift;
      }
    }
    throw UnsupportedError('Ads only supported on Android and iOS');
  }
}
