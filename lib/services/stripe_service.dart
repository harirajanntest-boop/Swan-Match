import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Price ID for Swan Match Premium Monthly
  static const String premiumMonthlyPriceId = 'price_1TL780E3cPvEYcau4xKFmRA0'; 

  Future<void> startSubscription({
    required String priceId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final callable = _functions.httpsCallable('createCheckoutSession');
      final result = await callable.call({
        'priceId': priceId,
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
      });

      final String url = result.data['url'];
      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      rethrow;
    }
  }
}
