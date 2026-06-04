import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot of UMP state after [ConsentManager.requestConsentIfNeeded]
/// resolves. Surfaced via [ConsentManager.lastResult] so other systems
/// (analytics consent gating, the Settings "Privacy Choices" row) can
/// react without re-querying the SDK.
@immutable
class ConsentResult {
  final ConsentStatus status;
  final bool canRequestAds;
  final bool isPrivacyOptionsRequired;

  const ConsentResult({
    required this.status,
    required this.canRequestAds,
    required this.isPrivacyOptionsRequired,
  });

  static const ConsentResult unknown = ConsentResult(
    status: ConsentStatus.unknown,
    canRequestAds: false,
    isPrivacyOptionsRequired: false,
  );
}

class ConsentManager {
  ConsentManager._();

  static const String _kStatusKey = 'ads_consent_status';

  static ConsentResult _last = ConsentResult.unknown;

  /// Snapshot of the most recent UMP resolution. Reads
  /// [ConsentResult.unknown] until [requestConsentIfNeeded] completes.
  static ConsentResult get lastResult => _last;

  /// Runs the full UMP flow: fetch latest consent info, then show the
  /// consent form if the user is in a regulated region and hasn't yet
  /// answered. Always resolves — errors are logged, never thrown — so
  /// the caller can chain ATT + Mobile Ads init without an extra
  /// try/catch at every call site.
  static Future<ConsentResult> requestConsentIfNeeded() async {
    final completer = Completer<ConsentResult>();

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
                final result = await _captureStatus();
                if (!completer.isCompleted) completer.complete(result);
              },
            );
          } catch (e) {
            debugPrint('[ads] consent form load threw: $e');
            final result = await _captureStatus();
            if (!completer.isCompleted) completer.complete(result);
          }
        },
        (FormError formError) async {
          debugPrint(
            '[ads] consent info update failed: '
            '${formError.errorCode} ${formError.message}',
          );
          final result = await _captureStatus();
          if (!completer.isCompleted) completer.complete(result);
        },
      );
    } catch (e) {
      debugPrint('[ads] consent request threw: $e');
      if (!completer.isCompleted) completer.complete(_last);
    }

    return completer.future;
  }

  /// Re-presents the UMP privacy options form so a user can change or
  /// withdraw consent after the initial flow. Only meaningful when
  /// [ConsentResult.isPrivacyOptionsRequired] is true.
  static Future<void> showPrivacyOptionsForm() async {
    final completer = Completer<void>();
    try {
      ConsentForm.showPrivacyOptionsForm((FormError? error) async {
        if (error != null) {
          debugPrint(
            '[ads] privacy options form dismissed with error: '
            '${error.errorCode} ${error.message}',
          );
        }
        await _captureStatus();
        if (!completer.isCompleted) completer.complete();
      });
    } catch (e) {
      debugPrint('[ads] privacy options form threw: $e');
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  static Future<ConsentResult> _captureStatus() async {
    try {
      final status = await ConsentInformation.instance.getConsentStatus();
      final canRequest = await ConsentInformation.instance.canRequestAds();
      final privacyRequirement = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      final result = ConsentResult(
        status: status,
        canRequestAds: canRequest,
        isPrivacyOptionsRequired:
            privacyRequirement == PrivacyOptionsRequirementStatus.required,
      );
      _last = result;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kStatusKey, status.index);
      debugPrint(
        '[ads] consent status=${status.name} '
        'canRequestAds=$canRequest '
        'privacyOptionsRequired=${privacyRequirement.name}',
      );
      return result;
    } catch (e) {
      debugPrint('[ads] consent capture failed: $e');
      return _last;
    }
  }
}
