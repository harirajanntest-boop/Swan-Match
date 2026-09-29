import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../shared/helpers/subscription_expiry.dart';
import 'user_service.dart';

/// Tracks free-trial usage limits stored in Firestore under
///   users/{uid}/trialUsage (a sub-document).
///
/// Limits reset every 24 hours automatically.
/// Premium users bypass all limits.
class TrialService {
  TrialService._();
  static final TrialService instance = TrialService._();

  static const int freeProfileViewsPerDay = 10;
  static const int freeInterestSendsPerDay = 3;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Internal helpers ─────────────────────────────────────────────────────

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _usageRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('trialUsage');
  }

  Future<Map<String, dynamic>> _getOrResetUsage() async {
    try {
      final ref = _usageRef;
      if (ref == null) return {};

      final snap = await ref.get();
      if (!snap.exists) {
        final initial = _blankUsage();
        await ref.set(initial);
        return initial;
      }

      final data = snap.data()!;
      final lastReset =
          (data['lastResetAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final hoursSinceReset = DateTime.now().difference(lastReset).inHours;

      if (hoursSinceReset >= 24) {
        final reset = _blankUsage();
        await ref.set(reset);
        return reset;
      }

      return data;
    } catch (e) {
      // In case of permission-denied or other errors, return a blank usage gracefully.
      return _blankUsage();
    }
  }

  Map<String, dynamic> _blankUsage() => {
    'profileViews': 0,
    'interestsSent': 0,
    'lastResetAt': FieldValue.serverTimestamp(),
  };

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Returns true if the user is premium and should bypass all limits.
  Future<bool> _checkPremium() async {
    final profile = await UserService.instance.getCurrentUserProfile();
    return UserService.instance.isPremium(profile);
  }

  // ─── Trial Status (Free Trial) ──────────────────────────────────────────

  static Future<TrialStatus> checkTrialStatus(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) return TrialStatus.free;

    final data = doc.data() ?? <String, dynamic>{};
    final plan = (data['subscriptionPlan'] ?? 'free').toString().toLowerCase();
    final status = (data['subscriptionStatus'] ?? 'free')
        .toString()
        .toLowerCase();

    // Paid Premium subscriber
    if ((plan == 'premium' || plan == 'gold') &&
        status == 'active' &&
        !storeSubscriptionLapsed(data)) {
      return TrialStatus.premium;
    }

    // Check if trial is active
    if (plan == 'trial' && status == 'trialing') {
      final endsAt = data['freeTrialEndsAt'] as Timestamp?;
      if (endsAt == null) return TrialStatus.free;

      final now = DateTime.now();
      final trialEnd = endsAt.toDate();
      final daysLeft = trialEnd.difference(now).inDays;

      if (trialEnd.isAfter(now)) {
        if (daysLeft <= 1) {
          return TrialStatus.trialExpiringSoon;
        }
        return TrialStatus.trial;
      } else {
        // Trial expired — update Firestore. Only rules-permitted fields:
        // 'subscriptionName' is backend-only in firestore.rules, so deleting it
        // here got the whole write denied (thrown every 10s by the dashboard
        // timer). Best-effort: the returned status is correct regardless.
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'subscriptionStatus': 'expired',
            'subscriptionPlan': 'free',
          });
        } catch (e) {
          debugPrint('Trial expiry write failed: $e');
        }
        return TrialStatus.trialExpired;
      }
    }

    return TrialStatus.free;
  }

  static Future<int?> getTrialDaysLeft(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) return null;
    final data = doc.data() ?? <String, dynamic>{};
    final plan = (data['subscriptionPlan'] ?? 'free').toString().toLowerCase();
    final status = (data['subscriptionStatus'] ?? 'free')
        .toString()
        .toLowerCase();

    if (plan != 'trial' || status != 'trialing') return null;

    final endsAt = data['freeTrialEndsAt'] as Timestamp?;
    if (endsAt == null) return null;

    final now = DateTime.now();
    final trialEnd = endsAt.toDate();
    if (!trialEnd.isAfter(now)) return 0;
    return trialEnd.difference(now).inDays;
  }

  static bool isPremiumAccess(TrialStatus status) {
    return status == TrialStatus.trial ||
        status == TrialStatus.trialExpiringSoon ||
        status == TrialStatus.premium;
  }

  /// Check whether the user can view one more profile.
  /// Returns a [TrialCheck] with `allowed` and remaining count.
  Future<TrialCheck> canViewProfile() async {
    if (await _checkPremium()) {
      return const TrialCheck(allowed: true, remaining: 999, reason: null);
    }
    final usage = await _getOrResetUsage();
    final views = (usage['profileViews'] as int?) ?? 0;
    final remaining = freeProfileViewsPerDay - views;
    return TrialCheck(
      allowed: remaining > 0,
      remaining: remaining.clamp(0, freeProfileViewsPerDay),
      reason: remaining <= 0
          ? 'You\'ve reached your $freeProfileViewsPerDay free profile views for today. '
                'Upgrade to Premium for unlimited access.'
          : null,
    );
  }

  /// Record a profile view (call after canViewProfile returns allowed=true).
  Future<void> recordProfileView() async {
    if (await _checkPremium()) return;
    final ref = _usageRef;
    if (ref == null) return;
    await ref.set({
      'profileViews': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Check whether the user can send one more interest today.
  Future<TrialCheck> canSendInterest() async {
    if (await _checkPremium()) {
      return const TrialCheck(allowed: true, remaining: 999, reason: null);
    }
    final usage = await _getOrResetUsage();
    final sent = (usage['interestsSent'] as int?) ?? 0;
    final remaining = freeInterestSendsPerDay - sent;
    return TrialCheck(
      allowed: remaining > 0,
      remaining: remaining.clamp(0, freeInterestSendsPerDay),
      reason: remaining <= 0
          ? 'You\'ve used all $freeInterestSendsPerDay free connections for today. '
                'Upgrade to Premium to send unlimited interests.'
          : null,
    );
  }

  /// Record an interest send.
  Future<void> recordInterestSent() async {
    if (await _checkPremium()) return;
    final ref = _usageRef;
    if (ref == null) return;
    await ref.set({
      'interestsSent': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Check whether the user can send a chat message.
  /// Chat is only allowed for accepted/connected pairs (handled by ChatService),
  /// but premium gate blocks free users entirely from sending first messages.
  Future<TrialCheck> canSendMessage() async {
    if (await _checkPremium()) {
      return const TrialCheck(allowed: true, remaining: 999, reason: null);
    }
    // Free users can only message in existing accepted interest threads.
    // We allow it but let ChatService verify the interest status.
    // A blanket block here is intentional for this app's model.
    return const TrialCheck(
      allowed: false,
      remaining: 0,
      reason:
          'Messaging is a Premium feature. '
          'Upgrade to connect with your matches.',
    );
  }

  /// Returns current daily usage stats (for UI display).
  Future<TrialUsageSummary> getUsageSummary() async {
    final isPremium = await _checkPremium();
    if (isPremium) {
      return const TrialUsageSummary(
        isPremium: true,
        profileViews: 0,
        interestsSent: 0,
      );
    }
    final usage = await _getOrResetUsage();
    return TrialUsageSummary(
      isPremium: false,
      profileViews: (usage['profileViews'] as int?) ?? 0,
      interestsSent: (usage['interestsSent'] as int?) ?? 0,
    );
  }
}

enum TrialStatus { free, trial, trialExpiringSoon, trialExpired, premium }

// ─── Value objects ────────────────────────────────────────────────────────────

class TrialCheck {
  final bool allowed;
  final int remaining;
  final String? reason; // non-null when not allowed

  const TrialCheck({
    required this.allowed,
    required this.remaining,
    required this.reason,
  });
}

class TrialUsageSummary {
  final bool isPremium;
  final int profileViews;
  final int interestsSent;

  const TrialUsageSummary({
    required this.isPremium,
    required this.profileViews,
    required this.interestsSent,
  });

  int get remainingViews =>
      (TrialService.freeProfileViewsPerDay - profileViews).clamp(0, 999);
  int get remainingInterests =>
      (TrialService.freeInterestSendsPerDay - interestsSent).clamp(0, 999);
}
