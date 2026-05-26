import 'package:flutter/foundation.dart';

import 'ad_units.dart';

class AdsState {
  AdsState._();
  static final AdsState instance = AdsState._();

  final Map<RewardedPlacement, ValueNotifier<bool>> rewardedAdLoaded = {
    for (final p in RewardedPlacement.values) p: ValueNotifier<bool>(false),
  };

  void dispose() {
    for (final notifier in rewardedAdLoaded.values) {
      notifier.dispose();
    }
  }
}
