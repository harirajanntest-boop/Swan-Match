import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

/// Holds price details fetched from the Stripe API via the
/// `getStripePrices` Cloud Function. All formatting is done server-side.
class StripePriceInfo {
  final String id;

  /// Human-readable total price, e.g. "$19.99".
  final String formattedAmount;

  /// Human-readable per-month price, e.g. "$9.99/month".
  final String formattedPerMonth;

  /// Product name from Stripe Dashboard.
  final String productName;

  /// Raw numeric amount in major currency units (e.g. 19.99).
  final double amount;

  /// ISO 4217 currency code, uppercase (e.g. "USD").
  final String currency;

  /// Billing interval, e.g. "month" or "year".
  final String? interval;

  /// Number of intervals per billing cycle.
  final int? intervalCount;

  const StripePriceInfo({
    required this.id,
    required this.formattedAmount,
    required this.formattedPerMonth,
    required this.productName,
    required this.amount,
    required this.currency,
    this.interval,
    this.intervalCount,
  });

  factory StripePriceInfo.fromMap(Map<String, dynamic> map) {
    return StripePriceInfo(
      id: map['id'] as String,
      formattedAmount: map['formattedAmount'] as String? ?? '',
      formattedPerMonth: map['formattedPerMonth'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?)?.toUpperCase() ?? 'USD',
      interval: map['interval'] as String?,
      intervalCount: (map['intervalCount'] as num?)?.toInt(),
    );
  }
}

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Swan Match Premium — Stripe price IDs
  static const String premiumMonthlyPriceId = 'price_1TKOrRE3Rb5ApPY7fOuscBJK';
  static const String premium6MonthPriceId = 'price_1TQBjHE3Rb5ApPY7CSk2jPPy';
  static const String premium1YearPriceId = 'price_1TQBknE3Rb5ApPY7oldut4en';

  /// Deep-link return URLs so the app reopens after Stripe checkout.
  static const String _successUrl = 'swanmatch://payment-success';
  static const String _cancelUrl = 'swanmatch://payment-cancel';

  /// Opens the Stripe hosted checkout page in the system browser.
  Future<void> startSubscription({
    required String priceId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'You must be logged in to start a subscription.';
      }
      await user.getIdToken(true); // Force token refresh to ensure valid auth context

      final callable = _functions.httpsCallable(
        'createCheckoutSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable
          .call<Map<String, dynamic>>(<String, dynamic>{
            'priceId': priceId,
            'successUrl': successUrl ?? _successUrl,
            'cancelUrl': cancelUrl ?? _cancelUrl,
          });

      final dynamic urlRaw = result.data['url'];
      if (urlRaw == null || urlRaw.toString().trim().isEmpty) {
        throw 'No checkout URL returned from server. Please try again.';
      }

      final Uri uri = Uri.parse(urlRaw.toString().trim());

      // Do NOT use canLaunchUrl for HTTPS URLs — it requires declaring 'https'
      // in LSApplicationQueriesSchemes which is unnecessary. Just launch directly.
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // open in Safari / Chrome
      );

      if (!launched) {
        throw 'Could not open Stripe checkout. Please ensure you have a browser installed.';
      }
    } on FirebaseFunctionsException catch (e) {
      throw 'Payment error (${e.code}): ${e.message}';
    } catch (e) {
      rethrow;
    }
  }

  /// Calls `verifySubscription` Cloud Function which queries Stripe directly
  /// and writes the authoritative status back to Firestore.
  ///
  /// Returns `true` if the user has an active/trialing subscription.
  Future<bool> verifyAndActivatePremium() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }
      await user.getIdToken(true);

      final callable = _functions.httpsCallable(
        'verifySubscription',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call<Map<String, dynamic>>();
      return result.data['isPremium'] as bool? ?? false;
    } on FirebaseFunctionsException catch (e) {
      throw 'Verification error (${e.code}): ${e.message}';
    } catch (e) {
      rethrow;
    }
  }

  /// Safely converts any Map to Map<String, dynamic> regardless of
  /// whether Firebase returns Map<String, dynamic> or Map<Object?, Object?>.
  static Map<String, dynamic> _toStringMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    throw TypeError();
  }

  /// Fetches price details from Stripe for a list of [priceIds].
  /// Calls the `getStripePrices` Cloud Function which returns a map
  /// keyed by price ID with pre-formatted amount strings.
  Future<Map<String, StripePriceInfo>> fetchPrices(
    List<String> priceIds,
  ) async {
    try {
      // While fetchPrices might not strictly require auth depending on the backend, 
      // it's an authenticated function in this app, so we should ensure auth state.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);
      }

      final callable = _functions.httpsCallable(
        'getStripePrices',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'priceIds': priceIds},
      );

      final dynamic pricesRaw = result.data['prices'];
      final Map<String, dynamic> rawPrices = _toStringMap(pricesRaw);

      final Map<String, StripePriceInfo> parsed = {};
      rawPrices.forEach((key, value) {
        final map = _toStringMap(value);
        parsed[key] = StripePriceInfo.fromMap(map);
      });

      return parsed;
    } on FirebaseFunctionsException catch (e) {
      throw 'Price fetch error (${e.code}): ${e.message}';
    } catch (e) {
      rethrow;
    }
  }

  /// Opens the Stripe Customer Portal to manage or cancel subscription
  Future<void> createPortalSession({String? returnUrl}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'You must be logged in to manage your subscription.';
      }
      await user.getIdToken(true);

      final callable = _functions.httpsCallable(
        'createPortalSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'returnUrl': returnUrl ?? _cancelUrl,
      });

      final dynamic urlRaw = result.data['url'];
      if (urlRaw == null || urlRaw.toString().trim().isEmpty) {
        throw 'No portal URL returned from server. Please try again.';
      }

      final Uri uri = Uri.parse(urlRaw.toString().trim());

      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw 'Could not open Stripe portal. Please ensure you have a browser installed.';
      }
    } on FirebaseFunctionsException catch (e) {
      throw 'Portal error (${e.code}): ${e.message}';
    } catch (e) {
      rethrow;
    }
  }
}
