import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'user_service.dart';
import 'connection_service.dart';

enum UserTier { free, trial, premium }

/// Discover filter fields on the swipe screen.
class DiscoverFilterAccess {
  final UserTier tier;
  final bool allowGender;
  final bool allowAge;
  final bool allowInterests;
  final bool allowMotherTongue;

  const DiscoverFilterAccess({
    required this.tier,
    required this.allowGender,
    required this.allowAge,
    required this.allowInterests,
    required this.allowMotherTongue,
  });

  bool get allowAnyDiscoverFilter =>
      allowGender || allowAge || allowInterests || allowMotherTongue;

  static const DiscoverFilterAccess premium = DiscoverFilterAccess(
    tier: UserTier.premium,
    allowGender: true,
    allowAge: true,
    allowInterests: true,
    allowMotherTongue: true,
  );

  static const DiscoverFilterAccess trial = DiscoverFilterAccess(
    tier: UserTier.trial,
    allowGender: true,
    allowAge: true,
    allowInterests: false,
    allowMotherTongue: false,
  );

  static const DiscoverFilterAccess free = DiscoverFilterAccess(
    tier: UserTier.free,
    allowGender: false,
    allowAge: false,
    allowInterests: false,
    allowMotherTongue: false,
  );

  static DiscoverFilterAccess forTier(UserTier tier) {
    switch (tier) {
      case UserTier.premium:
        return premium;
      case UserTier.trial:
        return trial;
      case UserTier.free:
        return free;
    }
  }

  /// Strips filter values the current tier is not allowed to use (server-side safe).
  ({
    String genderFilter,
    RangeValues ageRange,
    List<String> selectedInterestTags,
    String motherTongueFilter,
  }) sanitize({
    required String genderFilter,
    required RangeValues ageRange,
    required List<String> selectedInterestTags,
    required String motherTongueFilter,
  }) {
    return (
      genderFilter: allowGender ? genderFilter : 'All',
      ageRange: allowAge ? ageRange : const RangeValues(18, 70),
      selectedInterestTags:
          allowInterests ? List<String>.from(selectedInterestTags) : <String>[],
      motherTongueFilter: allowMotherTongue ? motherTongueFilter : '',
    );
  }

  String get filterUpgradeMessage {
    switch (tier) {
      case UserTier.premium:
        return '';
      case UserTier.trial:
        return 'Interests and Mother Tongue filters are Premium features. '
            'Your trial includes Gender and Age filters.';
      case UserTier.free:
        return 'Discover filters are a Premium feature. '
            'Upgrade to filter by gender, age, interests, and mother tongue.';
    }
  }
}

class LimitCheck {
  final bool allowed;
  final String? reason;

  const LimitCheck({required this.allowed, this.reason});
}

/// Enforces free / trial / paid premium usage limits in Firestore meta doc.
class SubscriptionLimitsService {
  SubscriptionLimitsService._();
  static final SubscriptionLimitsService instance = SubscriptionLimitsService._();

  static const int freeSwipesPerDay = 3;

  static const int trialSwipesPerDay = 5;
  static const int trialMessagePartners = 3;
  static const int trialActiveChatPartners = 1;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _usageRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('meta').doc('subscriptionUsage');
  }

  Future<UserTier> currentTier() async {
    final profile = await UserService.instance.getCurrentUserProfile();
    if (UserService.instance.isPaidPremium(profile)) return UserTier.premium;
    if (UserService.instance.isOnFreeTrial(profile)) return UserTier.trial;
    return UserTier.free;
  }

  Future<DiscoverFilterAccess> discoverFilterAccess() async {
    return DiscoverFilterAccess.forTier(await currentTier());
  }

  Future<LimitCheck> canOpenDiscoverFilters() async {
    final access = await discoverFilterAccess();
    if (access.allowAnyDiscoverFilter) {
      return const LimitCheck(allowed: true);
    }
    return LimitCheck(
      allowed: false,
      reason: access.filterUpgradeMessage,
    );
  }

  Future<Map<String, dynamic>> _getOrResetUsage() async {
    final ref = _usageRef;
    if (ref == null) return {};

    final tier = await currentTier();
    final snap = await ref.get();
    if (!snap.exists) {
      final initial = _blankUsage();
      await ref.set(initial);
      return initial;
    }

    final data = snap.data() ?? {};
    final lastReset =
        (data['lastResetAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
    final hoursSince = DateTime.now().difference(lastReset).inHours;

    if (tier == UserTier.trial) {
      if (hoursSince >= 24) {
        // lastResetAt is shared with the server's daily Connect counter, so
        // a new window resets both.
        await ref.set({
          'dailySwipes': 0,
          'dailyConnects': 0,
          'lastResetAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final refreshed = await ref.get();
        return refreshed.data() ?? data;
      }
      return data;
    }

    if (hoursSince >= 24) {
      final reset = _blankUsage();
      await ref.set(reset);
      return reset;
    }

    return data;
  }

  Map<String, dynamic> _blankUsage() => {
        'dailySwipes': 0,
        'dailyConnects': 0,
        'dailyInterests': 0,
        'dailyAccepts': 0,
        'totalInterestsSent': 0,
        'totalAccepts': 0,
        'messagePartnerIds': <String>[],
        'lastResetAt': FieldValue.serverTimestamp(),
      };

  Future<LimitCheck> canSwipe() async {
    final tier = await currentTier();
    if (tier == UserTier.premium) {
      return const LimitCheck(allowed: true);
    }

    final usage = await _getOrResetUsage();
    final swipes = (usage['dailySwipes'] as int?) ?? 0;
    final limit = tier == UserTier.trial ? trialSwipesPerDay : freeSwipesPerDay;

    if (swipes < limit) return const LimitCheck(allowed: true);
    return LimitCheck(
      allowed: false,
      reason: tier == UserTier.trial
          ? 'You\'ve used all $trialSwipesPerDay trial swipes for today. Upgrade to Premium for unlimited swipes.'
          : 'You\'ve used all $freeSwipesPerDay free swipes for today. Upgrade to Premium for unlimited swipes.',
    );
  }

  Future<void> recordSwipe() async {
    if (await currentTier() == UserTier.premium) return;
    final ref = _usageRef;
    if (ref == null) return;
    // Only count the swipe. lastResetAt marks the start of the 24h window
    // and is moved only by _getOrResetUsage; bumping it here on every swipe
    // meant the window never ended and the daily allowance never came back.
    await ref.set({
      'dailySwipes': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  List<String> _partnerIds(Map<String, dynamic> usage) {
    final raw = usage['messagePartnerIds'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  /// Human-readable fallback reason shown when there's no accepted
  /// connection between the current user and [otherUserId] yet. Replaces the
  /// richer `chatUnlockStatus` reason string that `JourneyService` used to
  /// return — `ConnectionService.hasAcceptedConnection` is a plain boolean,
  /// so this is synthesized here instead of coming from the gate itself.
  static const String _noConnectionReason =
      'Accept a connection request to start chatting.';

  /// Whether [otherUserId] can receive a new message thread from the current user.
  Future<LimitCheck> canSendMessageTo(String otherUserId) async {
    final hasConnection =
        await ConnectionService.instance.hasAcceptedConnection(otherUserId);
    if (!hasConnection) {
      return const LimitCheck(allowed: false, reason: _noConnectionReason);
    }

    final tier = await currentTier();
    if (tier == UserTier.premium) {
      return const LimitCheck(allowed: true);
    }

    if (tier == UserTier.free) {
      return const LimitCheck(
        allowed: false,
        reason:
            'Messaging is a Premium feature. Upgrade to start chatting with your matches.',
      );
    }

    // Trial: up to 3 partners in list, only 1 active chat partner can send.
    final usage = await _getOrResetUsage();
    final partners = _partnerIds(usage);

    if (partners.contains(otherUserId)) {
      final activeId = partners.isNotEmpty ? partners.first : '';
      if (activeId == otherUserId) return const LimitCheck(allowed: true);
      return const LimitCheck(
        allowed: false,
        reason:
            'Trial allows messaging one profile at a time. Upgrade to Premium for unlimited chats.',
      );
    }

    if (partners.length >= trialMessagePartners) {
      return LimitCheck(
        allowed: false,
        reason:
            'You\'ve reached the $trialMessagePartners profile messaging limit on trial. Upgrade to Premium for unlimited chats.',
      );
    }

    if (partners.isEmpty) return const LimitCheck(allowed: true);

    return const LimitCheck(
      allowed: false,
      reason:
          'Trial allows messaging one profile at a time. Upgrade to Premium for unlimited chats.',
    );
  }

  Future<void> recordMessagePartner(String otherUserId) async {
    if (await currentTier() != UserTier.trial) return;
    final ref = _usageRef;
    if (ref == null) return;
    final usage = await _getOrResetUsage();
    final partners = _partnerIds(usage);
    if (partners.contains(otherUserId)) return;
    await ref.set({
      'messagePartnerIds': FieldValue.arrayUnion([otherUserId]),
    }, SetOptions(merge: true));
  }

  /// Free user received interest/messages from a paid premium sender — can accept but not chat.
  Future<bool> isChatBlockedForFreeUser({
    required String otherUserId,
  }) async {
    final tier = await currentTier();
    if (tier != UserTier.free) return false;

    final other =
        await UserService.instance.getUserProfile(otherUserId);
    if (!UserService.instance.isPaidPremium(other)) return false;

    return true;
  }

  /// Open chat UI — blocked until an accepted `connections` doc exists
  /// between the two users, then gated by subscription tier as before.
  Future<LimitCheck> canOpenChat(String otherUserId) async {
    final hasConnection =
        await ConnectionService.instance.hasAcceptedConnection(otherUserId);
    if (!hasConnection) {
      return const LimitCheck(allowed: false, reason: _noConnectionReason);
    }

    if (await isChatBlockedForFreeUser(otherUserId: otherUserId)) {
      return const LimitCheck(
        allowed: false,
        reason:
            'Someone messaged you! Upgrade to Premium to read and reply to messages from Premium members.',
      );
    }

    final tier = await currentTier();
    if (tier == UserTier.free) {
      return const LimitCheck(
        allowed: false,
        reason: 'Messaging is a Premium feature. Upgrade to start chatting.',
      );
    }

    if (tier == UserTier.premium) {
      return const LimitCheck(allowed: true);
    }

    return canSendMessageTo(otherUserId);
  }
}
