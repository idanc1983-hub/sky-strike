import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsentManager {
  ConsentManager._();

  static const String _kStatusKey = 'ads_consent_status';

  static Future<void> requestConsentIfNeeded() async {
    final completer = Completer<void>();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            ConsentForm.loadAndShowConsentFormIfRequired(
              (FormError? error) async {
                if (error != null) {
                  debugPrint(
                    '[ads] consent form dismissed with error: '
                    '${error.errorCode} ${error.message}',
                  );
                }
                await _persistStatus();
                if (!completer.isCompleted) completer.complete();
              },
            );
          } catch (e) {
            debugPrint('[ads] consent form load threw: $e');
            await _persistStatus();
            if (!completer.isCompleted) completer.complete();
          }
        },
        (FormError formError) async {
          debugPrint(
            '[ads] consent info update failed: '
            '${formError.errorCode} ${formError.message}',
          );
          await _persistStatus();
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      debugPrint('[ads] consent request threw: $e');
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  static Future<void> _persistStatus() async {
    try {
      final status = await ConsentInformation.instance.getConsentStatus();
      final canRequest = await ConsentInformation.instance.canRequestAds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kStatusKey, status.index);
      debugPrint(
        '[ads] consent status=${status.name} canRequestAds=$canRequest',
      );
    } catch (e) {
      debugPrint('[ads] consent persist failed: $e');
    }
  }
}
