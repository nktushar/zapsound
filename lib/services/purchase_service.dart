import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'preferences_service.dart';
class PurchaseService {
  static const productId = 'zapsound_premium_lifetime';
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
static Future<void> init() async {
    _sub = _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.productID == productId) {
          if (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored) {
            await PrefsService.setPremium(true);
          }
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
        }
      }
    });
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

static Future<void> buy() async {
    final product = await getProduct();
    if (product == null) return;
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }
static Future<void> restore() async {
    await _iap.restorePurchases();
  }

  static Future<bool> restoreAndCheck() async {
    await restore();
    // The premium flag is set asynchronously by the purchaseStream listener,
    // so poll instead of guessing a fixed delay.
    for (var i = 0; i < 10; i++) {
      if (await PrefsService.isPremium()) return true;
      await Future.delayed(const Duration(milliseconds: 400));
    }
    return PrefsService.isPremium();
  }

  static Future<void> restoreSilently() async {
    final available = await _iap.isAvailable();
    if (!available) return;
    await _iap.restorePurchases();
  }

static void dispose() => _sub?.cancel();
}
