import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skystrike/config/invite_config.dart';
import 'package:skystrike/social/invite_state.dart';

const _cfg = InviteConfig(
  enabled: true,
  dailyCap: 2,
  cooldownHours: 24,
  rewardGems: 10,
  rewardCoins: 150,
  shareMessage: 'Come fly with me',
  shareUrl: 'https://example.com/app',
);

/// Test rig: captures grants and analytics, and lets each test drive the
/// share future's outcome.
class _Rig {
  int grantCount = 0;
  int grantedCoins = 0;
  int grantedGems = 0;
  final List<String> events = <String>[];
  final Map<String, Map<String, Object>?> lastParams = {};

  // Default: share succeeds immediately.
  Future<void> Function(String text) shareFn =
      (_) async {};

  InviteState build() => InviteState(
        config: _cfg,
        onGrant: ({required int coins, required int gems}) {
          grantCount++;
          grantedCoins += coins;
          grantedGems += gems;
        },
        logEvent: (name, {Map<String, Object>? params}) {
          events.add(name);
          lastParams[name] = params;
        },
        shareFn: (text) => shareFn(text),
      );
}

/// Lets the fire-and-forget [_load] / persistence microtasks settle.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads full allowance when prefs are empty', () async {
    final s = _Rig().build();
    await _settle();
    expect(s.remaining, 2);
    expect(s.canShare, isTrue);
    expect(s.isOnCooldown, isFalse);
    s.dispose();
  });

  test('single share grants once and keeps a remaining share', () async {
    final rig = _Rig();
    final s = rig.build();
    await _settle();

    await s.onSharePressed();

    expect(rig.grantCount, 1);
    expect(rig.grantedCoins, 150);
    expect(rig.grantedGems, 10);
    expect(s.remaining, 1);
    expect(s.isOnCooldown, isFalse);
    expect(s.canShare, isTrue, reason: 'single-share user keeps their share');
    expect(rig.events, containsAll(['invite_share_tapped', 'invite_share_completed']));
    expect(rig.events, isNot(contains('invite_cooldown_started')));
    s.dispose();
  });

  test('final share exhausts allowance and starts a cooldown', () async {
    final rig = _Rig();
    final s = rig.build();
    await _settle();

    await s.onSharePressed();
    await s.onSharePressed();

    expect(rig.grantCount, 2);
    expect(s.remaining, 0);
    expect(s.isOnCooldown, isTrue);
    expect(s.canShare, isFalse);
    // Cooldown anchored to this final share, ~24h out.
    final left = s.cooldownLeft;
    expect(left.inHours, inInclusiveRange(23, 24));
    expect(rig.events, contains('invite_cooldown_started'));
    expect(rig.lastParams['invite_cooldown_started'], {'cooldown_hours': 24});
    expect(rig.lastParams['invite_share_completed'], {
      'reward_gems': 10,
      'reward_coins': 150,
      'shares_used': 2,
    });
    s.dispose();
  });

  test('concurrent double-tap grants exactly once', () async {
    final rig = _Rig();
    final gate = Completer<void>();
    rig.shareFn = (_) => gate.future; // hold the first share in-flight
    final s = rig.build();
    await _settle();

    final first = s.onSharePressed();
    final second = s.onSharePressed(); // must no-op: canShare is false
    gate.complete();
    await Future.wait([first, second]);

    expect(rig.grantCount, 1);
    expect(s.remaining, 1);
    s.dispose();
  });

  test('share failure grants nothing and re-enables Share', () async {
    final rig = _Rig();
    rig.shareFn = (_) async => throw Exception('sheet dismissed with error');
    final s = rig.build();
    await _settle();

    await s.onSharePressed();

    expect(rig.grantCount, 0);
    expect(s.remaining, 2);
    expect(s.canShare, isTrue);
    expect(rig.events, isNot(contains('invite_share_completed')));
    s.dispose();
  });

  test('persisted state survives a restart while cooldown is active', () async {
    final future = DateTime.now().add(const Duration(hours: 5));
    SharedPreferences.setMockInitialValues({
      'invite__shares_used__v1': 2,
      'invite__cooldown_ends_at__v1': future.millisecondsSinceEpoch,
    });
    final s = _Rig().build();
    await _settle();

    expect(s.isOnCooldown, isTrue);
    expect(s.canShare, isFalse);
    expect(s.cooldownLeft.inHours, inInclusiveRange(4, 5));
    s.dispose();
  });

  test('an already-elapsed cooldown resets to full on load', () async {
    final past = DateTime.now().subtract(const Duration(minutes: 1));
    SharedPreferences.setMockInitialValues({
      'invite__shares_used__v1': 2,
      'invite__cooldown_ends_at__v1': past.millisecondsSinceEpoch,
    });
    final s = _Rig().build();
    await _settle();

    expect(s.isOnCooldown, isFalse);
    expect(s.remaining, 2);
    expect(s.canShare, isTrue);

    // And the reset was persisted.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('invite__shares_used__v1'), 0);
    expect(prefs.getInt('invite__cooldown_ends_at__v1'), 0);
    s.dispose();
  });

  test('disabled config never allows sharing', () async {
    final s = InviteState(
      config: const InviteConfig(
        enabled: false,
        dailyCap: 2,
        cooldownHours: 24,
        rewardGems: 10,
        rewardCoins: 150,
        shareMessage: 'x',
        shareUrl: 'y',
      ),
      onGrant: ({required int coins, required int gems}) {},
      logEvent: (name, {Map<String, Object>? params}) {},
      shareFn: (_) async {},
    );
    await _settle();
    expect(s.canShare, isFalse);
    s.dispose();
  });
}
