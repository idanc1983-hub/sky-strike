/// Outcome of an IAP purchase request.
enum IapPurchaseResult { success, cancelled, failed, productUnknown }

/// Outcome record passed back to the caller. Carries the result tag plus
/// (on success) the productId so the caller can apply the matching grant
/// from [IapCatalog].
class IapPurchaseOutcome {
  final IapPurchaseResult result;
  final String productId;
  final String? errorMessage;

  const IapPurchaseOutcome({
    required this.result,
    required this.productId,
    this.errorMessage,
  });
}

/// Backend-agnostic surface for IAP purchases. The real implementation
/// (`InAppPurchaseService`) wraps `package:in_app_purchase` once the
/// store certs are in place. The mock implementation grants instantly
/// without any network/store call.
abstract class IapService {
  /// Issues a purchase request for [productId]. Resolves when the store
  /// reports success, cancellation, or failure.
  Future<IapPurchaseOutcome> requestPurchase(String productId);

  /// Whether [productId] is currently visible in stores. The mock returns
  /// true for every id in [IapCatalog.allIds]; the real implementation
  /// checks the platform's `queryProductDetails`.
  bool isAvailable(String productId);

  /// Releases any subscriptions/listeners held by the implementation.
  void dispose();
}
