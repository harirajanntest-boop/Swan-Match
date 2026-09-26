import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Handles native in-app subscriptions (Apple App Store / Google Play).
///
/// The two stores model tiered plans differently, so this service speaks in
/// platform-agnostic PLAN KEYS ([monthlyId] / [sixMonthId] / [yearlyId]) and
/// maps each to the right store product underneath:
///
///  • iOS    — three separate products, all inside ONE Subscription Group
///             (`swan_premium_monthly` / `_6month` / `_yearly`). The group makes
///             them mutually exclusive (switching = upgrade/downgrade).
///  • Android — ONE subscription `swan_premium` with three BASE PLANS whose ids
///             ARE the plan keys (`monthly` / `sixmonth` / `yearly`). Querying it
///             returns one [GooglePlayProductDetails] per base plan; buying that
///             product purchases that specific base plan (offer token embedded).
///
/// On a successful/restored purchase the receipt is verified server-side by the
/// `verifyIapPurchase` Cloud Function, which validates it with Apple/Google and
/// writes the subscription fields to Firestore (so app + admin keep reading the
/// same `subscriptionPlan` / `subscriptionStatus` model as before).
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  // Lazy getter (NOT a field initializer): constructing the singleton must never
  // touch the platform instance, so accessing IapService.instance during a
  // widget build can't throw even if the plugin/platform isn't ready.
  InAppPurchase get _iap => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _initialized = false;

  // ─── Platform-agnostic plan keys (what the UI selects) ────────────────────
  static const String monthlyId = 'monthly';
  static const String sixMonthId = 'sixmonth';
  static const String yearlyId = 'yearly';

  // Android: single subscription product; base plan ids == the plan keys above.
  static const String _androidProductId = 'swan_premium';

  // iOS: separate product ids (all inside the "Swan Match Pro" group).
  static const Map<String, String> _iosProductIds = <String, String>{
    monthlyId: 'swan_premium_monthly',
    sixMonthId: 'swan_premium_6month',
    yearlyId: 'swan_premium_yearly',
  };

  /// The store ids to query for this platform.
  Set<String> get _queryIds => Platform.isIOS
      ? _iosProductIds.values.toSet()
      : <String>{_androidProductId};

  // Resolved store product for each plan key (filled by [loadProducts]).
  final Map<String, ProductDetails> _byPlan = <String, ProductDetails>{};

  // ─── Observable state for the UI ──────────────────────────────────────────
  final ValueNotifier<bool> storeAvailable = ValueNotifier<bool>(false);
  final ValueNotifier<List<ProductDetails>> products =
      ValueNotifier<List<ProductDetails>>(<ProductDetails>[]);
  final ValueNotifier<bool> purchasePending = ValueNotifier<bool>(false);

  /// Fired after a purchase is verified server-side (so the UI can refresh /
  /// show the congrats screen). Set by whoever opens the subscription page.
  Future<void> Function()? onPremiumActivated;

  /// Fired on a purchase error with a human-readable message.
  void Function(String message)? onError;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    storeAvailable.value = await _iap.isAvailable();
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) => debugPrint('IAP stream error: $e'),
    );
    if (storeAvailable.value) {
      await loadProducts();
      // Silently sync any subscription the store account ALREADY owns, so an
      // existing entitlement is verified server-side and premium is granted even
      // if the user never taps "Restore" (e.g. Play says "already subscribed").
      try {
        await _iap.restorePurchases();
      } catch (e) {
        debugPrint('IAP auto-restore failed: $e');
      }
    }
  }

  Future<void> loadProducts() async {
    final ProductDetailsResponse resp =
        await _iap.queryProductDetails(_queryIds);
    if (resp.error != null) {
      debugPrint('IAP queryProductDetails error: ${resp.error}');
    }
    if (resp.notFoundIDs.isNotEmpty) {
      debugPrint('IAP products not found: ${resp.notFoundIDs}');
    }
    _byPlan.clear();
    for (final ProductDetails pd in resp.productDetails) {
      final String? plan = _planForProduct(pd);
      if (plan != null) _byPlan[plan] = pd;
    }
    products.value = resp.productDetails;
  }

  /// Maps a store product back to one of our plan keys.
  String? _planForProduct(ProductDetails pd) {
    if (Platform.isIOS) {
      for (final MapEntry<String, String> e in _iosProductIds.entries) {
        if (e.value == pd.id) return e.key;
      }
      return null;
    }
    // Android: the base plan id IS the plan key.
    if (pd is GooglePlayProductDetails) {
      final offers = pd.productDetails.subscriptionOfferDetails;
      final int? idx = pd.subscriptionIndex;
      if (offers != null && idx != null && idx >= 0 && idx < offers.length) {
        return offers[idx].basePlanId;
      }
    }
    return null;
  }

  /// Store product for a plan key (used for price display + buying).
  ProductDetails? productFor(String planKey) => _byPlan[planKey];

  /// Starts the native purchase sheet for [planKey]. Returns false if the plan
  /// isn't loaded (e.g. store unavailable / agreement not signed yet).
  Future<bool> buy(String planKey) async {
    final ProductDetails? pd = _byPlan[planKey];
    if (pd == null) {
      onError?.call('This plan is not available right now. Please try again.');
      return false;
    }
    purchasePending.value = true;
    // Auto-renewable subscriptions are bought as non-consumables. For Android,
    // [pd] is the specific base-plan product, so its offer token is used.
    final PurchaseParam param = PurchaseParam(productDetails: pd);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Restores previously bought subscriptions (required by both stores).
  Future<void> restore() async {
    purchasePending.value = true;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails p in purchases) {
      // Whether it's safe to tell the store "handled" for this event. Stays
      // true for statuses that don't go through server verification (pending/
      // error/canceled) — only the purchased/restored path can flip it false.
      bool verified = true;
      switch (p.status) {
        case PurchaseStatus.pending:
          purchasePending.value = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          verified = await _verifyAndDeliver(p);
          break;
        case PurchaseStatus.error:
          purchasePending.value = false;
          debugPrint('IAP purchase error: ${p.error}');
          onError?.call('Purchase failed. You were not charged.');
          break;
        case PurchaseStatus.canceled:
          purchasePending.value = false;
          break;
      }

      // Complete a purchase the store is waiting on ONLY once we know it's
      // safe to: if verifyIapPurchase failed, leave it incomplete so the
      // store redelivers it (via the next restorePurchases()/app launch)
      // instead of silently dropping a purchase we never actually verified
      // or granted premium for.
      if (p.pendingCompletePurchase && verified) {
        await _iap.completePurchase(p);
      }
    }
  }

  /// Verifies the purchase SERVER-SIDE (Apple/Google) via the `verifyIapPurchase`
  /// Cloud Function, which grants premium only after the receipt is validated.
  /// Premium is never granted on the client — this is the secure path.
  ///
  /// Returns true if verification succeeded (premium granted) and it's safe
  /// to complete the purchase; false if it failed, so the caller leaves the
  /// purchase incomplete and lets the store redeliver it for another attempt.
  Future<bool> _verifyAndDeliver(PurchaseDetails p) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('verifyIapPurchase')
          .call(<String, dynamic>{
        'productId': p.productID,
        'source': p.verificationData.source, // 'app_store' | 'google_play'
        'verificationData': p.verificationData.serverVerificationData,
        'transactionId': p.purchaseID,
      });
      await onPremiumActivated?.call();
      return true;
    } catch (e) {
      debugPrint('IAP verification error: $e');
      onError?.call(
        'We received your purchase but activation is taking a moment. '
        'It will appear shortly — or tap Restore Purchases.',
      );
      return false;
    } finally {
      purchasePending.value = false;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
