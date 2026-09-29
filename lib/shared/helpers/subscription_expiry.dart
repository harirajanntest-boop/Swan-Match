/// App Store / Google Play subscriptions are granted by the server with a
/// `billingPeriodEnd`. The server's refresh job records renewals and
/// downgrades cancelled / lapsed / refunded ones; until it has run, the app
/// also stops treating a store subscription as Premium once its paid period
/// ended more than [kStoreSubscriptionGrace] ago.
///
/// Mirrors `storeSubscriptionLapsed` in functions/iap_entitlements.js.
const Duration kStoreSubscriptionGrace = Duration(days: 3);

bool storeSubscriptionLapsed(Map<String, dynamic>? profile, {DateTime? now}) {
  if (profile == null) return false;
  // Stripe subscriptions are kept current by their own webhook.
  if ((profile['stripeSubscriptionId'] ?? '').toString().isNotEmpty) {
    return false;
  }
  final isStore = (profile['iapSource'] ?? '').toString().isNotEmpty ||
      (profile['iapProductId'] ?? '').toString().isNotEmpty;
  if (!isStore) return false;
  final end = _asDateTime(profile['billingPeriodEnd']);
  if (end == null) return false;
  return end.add(kStoreSubscriptionGrace).isBefore(now ?? DateTime.now());
}

/// Firestore Timestamp / DateTime / epoch millis → DateTime (duck-typed so
/// this helper needs no Firestore import).
DateTime? _asDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  try {
    final d = (v as dynamic).toDate();
    if (d is DateTime) return d;
  } catch (_) {}
  return null;
}
