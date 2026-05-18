import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/presentation/pages/payment_status_page.dart';
import 'stripe_service.dart';
import 'user_service.dart';

/// Tracks Stripe checkout → congratulations screen flow across app restarts.
class PaymentFlowService {
  PaymentFlowService._();

  static const String pendingCheckoutKey = 'pending_stripe_checkout';
  static const String successShownKey = 'payment_success_shown';
  /// Set when congrats UI is on screen; cleared when user taps Back to Home.
  static const String successDisplayedKey = 'payment_success_displayed';

  static GlobalKey<NavigatorState>? navigatorKey;
  static bool congratsScreenVisible = false;
  static bool _isPresenting = false;

  static void setCongratsVisible(bool visible) {
    congratsScreenVisible = visible;
  }

  static Future<void> markCheckoutStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pendingCheckoutKey, true);
    await prefs.setBool(successShownKey, false);
    await prefs.setBool(successDisplayedKey, false);
  }

  static Future<bool> isCheckoutPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(pendingCheckoutKey) ?? false;
  }

  static Future<void> clearCheckoutPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingCheckoutKey);
  }

  static Future<bool> hasShownSuccessScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(successShownKey) ?? false;
  }

  static Future<bool> hasDisplayedSuccessScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(successDisplayedKey) ?? false;
  }

  /// Call when congratulations UI is built (survives hot reload).
  static Future<void> markCongratulationsDisplayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(successDisplayedKey, true);
  }

  static Future<void> markSuccessScreenShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(successShownKey, true);
    await prefs.remove(pendingCheckoutKey);
    await prefs.remove(successDisplayedKey);
  }

  /// Clears stale flags after payment was already acknowledged.
  static Future<void> reconcileCheckoutState() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(successShownKey) == true) {
      await prefs.remove(pendingCheckoutKey);
      await prefs.remove(successDisplayedKey);
    }
  }

  /// True only for a fresh checkout return that has not shown congrats yet.
  static Future<bool> shouldPresentCongratulations() async {
    await reconcileCheckoutState();
    if (await hasShownSuccessScreen()) return false;
    if (await hasDisplayedSuccessScreen()) return false;
    if (!await isCheckoutPending()) return false;
    return true;
  }

  /// Syncs Stripe → Firestore after payment. Does not navigate.
  static Future<bool> syncPaidSubscription() async {
    try {
      await StripeService.instance.verifyAndActivatePremium();
      UserService.instance.invalidateCurrentUserCache();
      await UserService.instance.endTrialAfterPaidUpgrade();
      final profile = await UserService.instance.getCurrentUserProfile();
      return UserService.instance.isPaidPremium(profile);
    } catch (_) {
      return false;
    }
  }

  /// Shows congratulations once after checkout (app resume / return from browser).
  static Future<void> presentCongratulationsIfPaid() async {
    if (_isPresenting || congratsScreenVisible) return;
    if (!await shouldPresentCongratulations()) return;

    _isPresenting = true;
    try {
      final isPaid = await syncPaidSubscription();
      if (!isPaid) return;
      if (!await shouldPresentCongratulations()) return;

      final nav = navigatorKey?.currentState;
      if (nav == null || congratsScreenVisible) return;

      await markCongratulationsDisplayed();
      congratsScreenVisible = true;
      await nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const PaymentStatusPage(isSuccess: true),
        ),
        (route) => false,
      );
    } finally {
      _isPresenting = false;
    }
  }

  /// Deep link `swanmatch://payment-success` — verify then open congrats route.
  static Future<void> handlePaymentSuccessDeepLink() async {
    if (_isPresenting || congratsScreenVisible) return;
    if (await hasShownSuccessScreen()) {
      await clearCheckoutPending();
      return;
    }

    _isPresenting = true;
    try {
      await syncPaidSubscription();

      if (congratsScreenVisible || await hasDisplayedSuccessScreen()) return;
      if (!await isCheckoutPending() && await hasShownSuccessScreen()) return;

      final nav = navigatorKey?.currentState;
      if (nav == null) return;

      await markCongratulationsDisplayed();
      congratsScreenVisible = true;
      await nav.pushNamedAndRemoveUntil(
        '/payment-success',
        (route) => false,
      );
    } finally {
      _isPresenting = false;
    }
  }
}
