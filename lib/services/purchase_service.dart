import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'preferences_service.dart';

/// Outcome of a purchase flow, pushed to [PurchaseService.events] so the
/// paywall can react (the billing flow itself returns before it finishes).
enum PurchaseOutcome { purchased, pending, canceled, error }

class PurchaseEvent {
  final PurchaseOutcome outcome;
  final String? message;
  const PurchaseEvent(this.outcome, [this.message]);
}

/// Result of [PurchaseService.buy] starting the billing flow.
enum BuyStart { launched, storeUnavailable, alreadyOwned, failed }

class PurchaseService {
  static const productId = 'zapsound_premium_lifetime';
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static final _events = StreamController<PurchaseEvent>.broadcast();

  static Stream<PurchaseEvent> get events => _events.stream;

  static Future<void> init() async {
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      _events.add(PurchaseEvent(PurchaseOutcome.error, '$e'));
    });
  }

  static Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await PrefsService.setPremium(true);
          _events.add(const PurchaseEvent(PurchaseOutcome.purchased));
        case PurchaseStatus.pending:
          _events.add(const PurchaseEvent(PurchaseOutcome.pending));
        case PurchaseStatus.canceled:
          _events.add(const PurchaseEvent(PurchaseOutcome.canceled));
        case PurchaseStatus.error:
          _events.add(PurchaseEvent(PurchaseOutcome.error, p.error?.message));
      }
      // Must acknowledge, or Google Play refunds the purchase after 3 days.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  static Future<ProductDetails?> getProduct() async {
    final available = await _iap.isAvailable();
    if (!available) return null;
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isNotEmpty) {
      return response.productDetails.first;
    }
    return null;
  }

  /// Starts the Play billing flow. The final outcome arrives on [events].
  static Future<BuyStart> buy() async {
    final product = await getProduct();
    if (product == null) return BuyStart.storeUnavailable;
    final launched = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (launched) return BuyStart.launched;
    // Play refuses to launch the flow when the item is already owned (e.g.
    // bought on another device or app data was cleared): restore instead.
    return await restoreAndCheck() ? BuyStart.alreadyOwned : BuyStart.failed;
  }

  static Future<void> restore() async {
    await _iap.restorePurchases();
  }

  static Future<bool> restoreAndCheck() async {
    await syncWithStore();
    if (await PrefsService.isPremium()) return true;
    await restore();
    // The premium flag is set asynchronously by the purchaseStream listener,
    // so poll instead of guessing a fixed delay.
    for (var i = 0; i < 10; i++) {
      if (await PrefsService.isPremium()) return true;
      await Future.delayed(const Duration(milliseconds: 400));
    }
    return PrefsService.isPremium();
  }

  /// Makes the local premium flag match what Google Play says is owned:
  /// grants it for purchases completed while the app was closed (e.g. a
  /// pending cash/carrier payment that cleared later), acknowledges them, and
  /// revokes it after a refund. Leaves the flag alone if Play can't be
  /// reached, so offline users keep premium.
  static Future<void> syncWithStore() async {
    try {
      if (!await _iap.isAvailable()) return;
      final android = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await android.queryPastPurchases();
      if (response.error != null) return;

      final owned = response.pastPurchases.where(
        (p) => p.productID == productId && p.status == PurchaseStatus.purchased,
      );
      await PrefsService.setPremium(owned.isNotEmpty);
      for (final p in owned) {
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      }
    } catch (_) {
      // Billing unavailable (emulator without Play, etc.): keep current state.
    }
  }

  static void dispose() => _sub?.cancel();
}
