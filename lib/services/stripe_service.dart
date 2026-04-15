import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Price ID for Swan Match Premium Monthly
  // TODO: Verify this Price ID with the new Stripe account (sk_test_51TKO...)
  static const String premiumMonthlyPriceId = 'price_1TKOcEE3Rb5ApPY7...'; 

  Future<void> startSubscription({
    required String priceId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    try {
      // Default URLs if not provided
      final String finalSuccessUrl = successUrl ?? 'https://swan-match.firebaseapp.com/payment-success';
      final String finalCancelUrl = cancelUrl ?? 'https://swan-match.firebaseapp.com/payment-cancel';

      final callable = _functions.httpsCallable('createCheckoutSession');
      final result = await callable.call({
        'priceId': priceId,
        'successUrl': finalSuccessUrl,
        'cancelUrl': finalCancelUrl,
      });

      final String url = result.data['url'];
      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Stripe Service Error: $e');
      rethrow;
    }
  }
}

