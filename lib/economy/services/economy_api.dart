import 'dart:async';

import '../constants/economy_constants.dart';

/// Snapshot of the fields that get backend-synced (GDD §6.1).
/// Kept in this file so the API surface stays self-contained.
class EconomySyncPayload {
  final int coins;
  final int gems;
  final int killCount;
  final Map<String, int> powerUpInventory;

  const EconomySyncPayload({
    required this.coins,
    required this.gems,
    required this.killCount,
    required this.powerUpInventory,
  });
}

/// Backend stub for cloud sync. Production wires this to Cloud Functions
/// or Firestore. Today it's a no-op; the only behavior worth shipping is
/// the **debounce** — local writes are bursty (every coin pickup), and
/// we don't want to flood a real backend.
class EconomyApi {
  /// How long to wait for further updates before flushing. GDD locks this
  /// at 30 seconds.
  final Duration debounce;

  EconomySyncPayload? _pendingPayload;
  Timer? _flushTimer;
  Future<void> Function(EconomySyncPayload payload)? _onFlush;

  EconomyApi({this.debounce = EconomyConstants.backendSyncDebounce});

  /// Hook the network call. Called by [EconomyState] at construction;
  /// the production impl forwards to a Cloud Functions endpoint.
  void registerFlushHandler(
    Future<void> Function(EconomySyncPayload payload) handler,
  ) {
    _onFlush = handler;
  }

  /// Stages an updated payload. The most recent staged payload is what
  /// flushes after [debounce] elapses.
  void enqueue(EconomySyncPayload payload) {
    _pendingPayload = payload;
    _flushTimer?.cancel();
    _flushTimer = Timer(debounce, _flushNow);
  }

  /// Forces an immediate flush, ignoring the debounce window. Called on
  /// app background and at session-end.
  Future<void> flushNow() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flushNow();
  }

  Future<void> _flushNow() async {
    final payload = _pendingPayload;
    if (payload == null) return;
    _pendingPayload = null;
    final handler = _onFlush;
    if (handler != null) {
      await handler(payload);
    }
  }

  /// Releases the debounce timer. Safe to call multiple times.
  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
