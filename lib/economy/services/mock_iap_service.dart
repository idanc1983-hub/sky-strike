import '../constants/iap_catalog.dart';
import 'iap_service.dart';

/// Local-only IAP stub that grants instantly without any store call.
///
/// Used during development, in tests, and as the active service until the
/// real `package:in_app_purchase` SDK is wired in (see GDD §2.10 + the
/// build prompt's IAP section).
///
/// **Swap point for production:** replace [MockIapService] with
/// `InAppPurchaseService` wherever the [IapService] is constructed; the
/// rest of the economy stack is unchanged.
class MockIapService implements IapService {
  /// When true, every `requestPurchase` resolves with
  /// [IapPurchaseResult.failed]. Used to test the failure path.
  bool failureMode;

  /// When true, every `requestPurchase` resolves with
  /// [IapPurchaseResult.cancelled]. Used to test the cancel path.
  bool cancelMode;

  /// Latency injected before each resolution. Defaults to a small
  /// non-zero value so the UI's spinner is visible during dev.
  Duration latency;

  MockIapService({
    this.failureMode = false,
    this.cancelMode = false,
    this.latency = const Duration(milliseconds: 350),
  });

  @override
  Future<IapPurchaseOutcome> requestPurchase(String productId) async {
    await Future<void>.delayed(latency);
    if (!isAvailable(productId)) {
      return IapPurchaseOutcome(
        result: IapPurchaseResult.productUnknown,
        productId: productId,
        errorMessage: 'Unknown productId in mock catalog',
      );
    }
    if (cancelMode) {
      return IapPurchaseOutcome(
        result: IapPurchaseResult.cancelled,
        productId: productId,
      );
    }
    if (failureMode) {
      return IapPurchaseOutcome(
        result: IapPurchaseResult.failed,
        productId: productId,
        errorMessage: 'Mock failure mode active',
      );
    }
    return IapPurchaseOutcome(
      result: IapPurchaseResult.success,
      productId: productId,
    );
  }

  @override
  bool isAvailable(String productId) {
    return IapCatalog.allIds().contains(productId) ||
        productId == IapCatalog.removeAdsProductId;
  }

  @override
  void dispose() {
    // No resources to release in the mock.
  }
}
