import 'package:flutter_test/flutter_test.dart';
import 'package:swam_match_app/shared/helpers/subscription_expiry.dart';

void main() {
  final now = DateTime(2026, 9, 29, 12);
  Map<String, dynamic> store(DateTime? end, {Map<String, dynamic> extra = const {}}) => {
        'subscriptionPlan': 'premium',
        'subscriptionStatus': 'active',
        'iapSource': 'app_store',
        'iapProductId': 'swan_premium_monthly',
        if (end != null) 'billingPeriodEnd': end,
        ...extra,
      };

  test('active store subscription is not lapsed', () {
    expect(storeSubscriptionLapsed(store(now.add(const Duration(days: 10))), now: now), isFalse);
  });

  test('within the 3-day grace after the period ends: still Premium', () {
    expect(storeSubscriptionLapsed(store(now.subtract(const Duration(days: 2))), now: now), isFalse);
  });

  test('more than 3 days past the period end: lapsed', () {
    expect(storeSubscriptionLapsed(store(now.subtract(const Duration(days: 4))), now: now), isTrue);
  });

  test('Stripe subscribers are never affected', () {
    expect(
      storeSubscriptionLapsed(
        store(now.subtract(const Duration(days: 30)), extra: {'stripeSubscriptionId': 'sub_1'}),
        now: now,
      ),
      isFalse,
    );
  });

  test('non-store users (free / trial / legacy without end date) are never affected', () {
    expect(storeSubscriptionLapsed({'subscriptionPlan': 'free'}, now: now), isFalse);
    expect(storeSubscriptionLapsed({'subscriptionPlan': 'trial', 'subscriptionStatus': 'trialing'}, now: now), isFalse);
    expect(storeSubscriptionLapsed(store(null), now: now), isFalse);
    expect(storeSubscriptionLapsed(null, now: now), isFalse);
  });

  test('manual grant (iapProductId only) expires after its end date + grace', () {
    final manual = {
      'subscriptionPlan': 'premium',
      'subscriptionStatus': 'active',
      'iapProductId': 'swan_premium_monthly',
      'iapTransactionId': 'manual-grant',
      'billingPeriodEnd': DateTime(2026, 10, 28),
    };
    expect(storeSubscriptionLapsed(manual, now: DateTime(2026, 10, 30)), isFalse);
    expect(storeSubscriptionLapsed(manual, now: DateTime(2026, 11, 1)), isTrue);
  });

  test('epoch-millis end dates are understood', () {
    final end = now.subtract(const Duration(days: 5)).millisecondsSinceEpoch;
    expect(storeSubscriptionLapsed(store(null, extra: {'billingPeriodEnd': end}), now: now), isTrue);
  });
}
