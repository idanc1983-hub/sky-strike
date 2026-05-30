import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants/iap_catalog.dart';
import 'iap_service.dart';

/// Real `package:in_app_purchase` implementation of [IapService].
///
/// This is the production path — replaces [MockIapService] in release
/// builds. It:
///
/// 1. Queries the platform store for every product id in [IapCatalog]
///    at construction time and caches the resulting [ProductDetails].
/// 2. Subscribes to `InAppPurchase.purchaseStream` and routes each
///    [PurchaseDetails] update back to the awaiting [requestPurchase]
///    caller by productId.
/// 3. Calls `completePurchase` on every terminal update so the platform
///    stops re-delivering it on next launch.
///
/// **Pre-flight required before this can ship**: configure store
/// products in App Store Connect / Play Console with the IDs declared
/// in [IapCatalog], and verify the build is signed with the correct
/// certs. With that done, swap [MockIapService] for this class in
/// [main.dart].
///
/// **Receipt verification is NOT done here** — that belongs on a
/// backend (when [EconomyApi._flushToBackend] is implemented). Server-
/// side verification is the only way to detect refund-after-grant and
/// fully-replayed receipts. Until then, treat this class as best-effort.
class StoreIapService implements IapService {
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Cached product details keyed by productId. Populated by
  /// [initialize]; empty until the first store query completes.
  final Map<String, ProductDetails> _products = {};

  /// Pending purchase completers keyed by productId. A purchase request
  /// adds its completer here; the stream listener resolves it when the
  /// matching [PurchaseDetails] update arrives.
  final Map<String, Completer<IapPurchaseOutcome>> _pending = {};

  bool _initialized = false;

  StoreIapService({InAppPurchase? store})
      : _store = store ?? InAppPurchase.instance;

  /// Queries the store for every catalog id and subscribes to the
  /// purchase stream. Idempotent.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final available = await _store.isAvailable();
    if (!available) {
      debugPrint('[iap] store unavailable on this device');
      return;
    }

    _subscription = _store.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object err) {
        debugPrint('[iap] purchaseStream error: $err');
      },
    );

    final ids = IapCatalog.allIds().toSet()
      ..add(IapCatalog.removeAdsProductId);
    final response = await _store.queryProductDetails(ids);
    if (response.error != null) {
      debugPrint('[iap] queryProductDetails error: ${response.error}');
    }
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[iap] products not found: ${response.notFoundIDs}');
    }
  }

  @override
  bool isAvailable(String productId) => _products.containsKey(productId);

  @override
  Future<IapPurchaseOutcome> requestPurchase(String productId) async {
    if (!_initialized) await initialize();
    final product = _products[productId];
    if (product == null) {
      return IapPurchaseOutcome(
        result: IapPurchaseResult.productUnknown,
        productId: productId,
        errorMessage: 'Product not configured in store catalog',
      );
    }

    // Reject overlapping requests for the same product — the platform
    // SDK does not enforce this and double-taps can otherwise spawn two
    // billing dialogs.
    final existing = _pending[productId];
    if (existing != null) return existing.future;

    final completer = Completer<IapPurchaseOutcome>();
    _pending[productId] = completer;

    final param = PurchaseParam(productDetails: product);
    final isConsumable = _isConsumable(productId);
    try {
      if (isConsumable) {
        await _store.buyConsumable(purchaseParam: param);
      } else {
        await _store.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      _pending.remove(productId);
      return IapPurchaseOutcome(
        result: IapPurchaseResult.failed,
        productId: productId,
        errorMessage: e.toString(),
      );
    }
    return completer.future;
  }

  /// Coin packs are consumables (granted then forgotten); main gem
  /// packs and remove-ads are non-consumables. Match the store
  /// configuration exactly — a mismatch causes the SDK to throw.
  bool _isConsumable(String productId) {
    if (productId == IapCatalog.removeAdsProductId) return false;
    if (IapCatalog.mainPackIds.contains(productId)) return false;
    return true; // coin packs + contextual coin packs
  }

  void _onPurchaseUpdates(List<PurchaseDetails> updates) {
    for (final update in updates) {
      final completer = _pending.remove(update.productID);
      switch (update.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          completer?.complete(IapPurchaseOutcome(
            result: IapPurchaseResult.success,
            productId: update.productID,
          ));
          break;
        case PurchaseStatus.canceled:
          completer?.complete(IapPurchaseOutcome(
            result: IapPurchaseResult.cancelled,
            productId: update.productID,
          ));
          break;
        case PurchaseStatus.error:
          completer?.complete(IapPurchaseOutcome(
            result: IapPurchaseResult.failed,
            productId: update.productID,
            errorMessage: update.error?.message,
          ));
          break;
        case PurchaseStatus.pending:
          // Platform reports pending while billing UI is up — don't
          // resolve the completer yet. A follow-up update will.
          if (completer != null) _pending[update.productID] = completer;
          continue;
      }
      if (update.pendingCompletePurchase) {
        // Fire-and-forget — failure to ack only delays the next-launch
        // re-delivery, never breaks the current flow.
        _store.completePurchase(update);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete(const IapPurchaseOutcome(
          result: IapPurchaseResult.failed,
          productId: '',
          errorMessage: 'Service disposed',
        ));
      }
    }
    _pending.clear();
  }
}
