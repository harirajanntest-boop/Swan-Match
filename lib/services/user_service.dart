import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/stream_utils.dart';
import 'chat_service.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUid => _auth.currentUser?.uid;

  /// True when admin set `account` to `Suspended` on the user document.
  bool isAccountSuspended(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final status = (profile['account'] ?? '').toString().trim().toLowerCase();
    return status == 'suspended';
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<String?> get _uidStream =>
      _auth.authStateChanges().map((u) => u?.uid).distinct();

  Future<void> upsertUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final payload = <String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Security: Ensure password is never stored in Firestore
    payload.remove('password');
    payload.remove('confirmPassword');

    if (!(data.containsKey('createdAt'))) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await _userRef(uid).set(payload, SetOptions(merge: true));
  }

  Future<void> updateCurrentUserProfile(Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) return;
    _invalidateCache(user.uid);
    await upsertUserProfile(uid: user.uid, data: updates);
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _userRef(user.uid).set({
        'isOnline': isOnline,
        'online': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  Future<void> syncAuthProviders() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final providers = user.providerData
          .map((info) => info.providerId)
          .toList();
      // Ensure 'password' is added if the user has an email and didn't exclusively use OAuth
      // (providerData might contain 'password' automatically, but it's good to just sync what Firebase reports)

      await _userRef(
        user.uid,
      ).set({'providers': providers}, SetOptions(merge: true));
    } catch (e) {
      print('Error syncing auth providers: $e');
    }
  }

  /// In-memory cache: uid → profile data.
  /// Eliminates redundant Firestore reads for the same profile within a session.
  final Map<String, Map<String, dynamic>> _profileCache = {};

  /// Invalidate cache entry when a profile is updated.
  void _invalidateCache(String uid) => _profileCache.remove(uid);

  Future<Map<String, dynamic>?> getUserProfile(String uid, {bool forceRefresh = false}) async {
    if (!forceRefresh && _profileCache.containsKey(uid)) return _profileCache[uid];
    final snapshot = await _userRef(uid).get();
    final data = snapshot.data();
    if (data != null) {
      _profileCache[uid] = <String, dynamic>{...data, 'uid': uid};
    } else {
      _profileCache.remove(uid);
    }
    return _profileCache[uid];
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final profile = await getUserProfile(user.uid);
    if (profile == null) return null;
    return <String, dynamic>{...profile, 'uid': user.uid};
  }

  Future<Map<String, dynamic>?> getUserProfileByEmail(String email) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty) return null;
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: trimmedEmail)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }

  Future<bool> doesEmailExist(String email) async {
    final profile = await getUserProfileByEmail(email);
    return profile != null;
  }

  Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    return _userRef(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return <String, dynamic>{...data, 'uid': uid};
    });
  }

  Stream<Map<String, dynamic>?> watchCurrentUserProfile() {
    return switchMap(_uidStream, (uid) {
      if (uid == null) {
        return Stream.value(null);
      }
      return _userRef(uid).snapshots().map((doc) {
        final data = doc.data();
        if (data == null) {
          _profileCache.remove(uid);
          return null;
        }
        final profile = <String, dynamic>{...data, 'uid': uid};
        _profileCache[uid] = profile;
        return profile;
      });
    });
  }

  void invalidateCurrentUserCache() {
    final uid = _auth.currentUser?.uid;
    if (uid != null) _profileCache.remove(uid);
  }

  Future<void> updatePartnerPreferences(
    Map<String, dynamic> preferences,
  ) async {
    await updateCurrentUserProfile(<String, dynamic>{
      'partnerPreference': preferences,
      'partnerPreferences': preferences,
    });
  }

  Future<void> updateInterests(List<String> interests) async {
    await updateCurrentUserProfile(<String, dynamic>{'interests': interests});
  }

  Future<void> updateLifestyle({
    required String eatingHabits,
    required String smokingHabits,
    required String drinkingHabits,
  }) async {
    await updateCurrentUserProfile(<String, dynamic>{
      'lifestyle': <String, dynamic>{
        'eatingHabits': eatingHabits,
        'smokingHabits': smokingHabits,
        'drinkingHabits': drinkingHabits,
      },
    });
  }

  Future<void> setSubscriptionPlan(String plan) async {
    await updateCurrentUserProfile(<String, dynamic>{
      'subscriptionPlan': plan,
      'registrationCompleted': true,
    });
  }

  Future<void> deleteCurrentUserCompletely() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    await _deleteKnownUserSubcollections(uid);
    await _deleteInterests(uid);
    await _deleteNotifications(uid);
    await _deleteProfileViews(uid);
    await _deleteChats(uid);
    await _deleteQueryDocs(
      _firestore.collection('chats').where('senderId', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore.collection('chats').where('receiverId', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore.collection('users').where('uid', isEqualTo: uid),
    );
    await _userRef(uid).delete();
    await _deleteStorageFolder('users/$uid');

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await user.delete();
    await _auth.signOut();
  }

  Future<void> _deleteKnownUserSubcollections(String uid) async {
    final subcollections = <String>['partnerPreference'];
    for (final name in subcollections) {
      await _deleteSubcollection(_userRef(uid).collection(name));
    }
  }

  Future<void> _deleteInterests(String uid) async {
    await _deleteQueryDocs(
      _firestore.collection('interests').where('fromUid', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore.collection('interests').where('toUid', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore.collection('interests').where('fromUserId', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore.collection('interests').where('toUserId', isEqualTo: uid),
    );
  }

  Future<void> _deleteNotifications(String uid) async {
    await _deleteQueryDocs(
      _firestore.collection('notifications').where('fromUid', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore.collection('notifications').where('toUid', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore
          .collection('notifications')
          .where('fromUserId', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore.collection('notifications').where('toUserId', isEqualTo: uid),
    );
  }

  Future<void> _deleteChats(String uid) async {
    final chats = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    for (final chatDoc in chats.docs) {
      await _deleteSubcollection(chatDoc.reference.collection('messages'));
      await chatDoc.reference.delete();
    }
  }

  Future<void> _deleteProfileViews(String uid) async {
    await _deleteQueryDocs(
      _firestore.collection('profileViews').where('fromUserId', isEqualTo: uid),
    );
    await _deleteQueryDocs(
      _firestore.collection('profileViews').where('toUserId', isEqualTo: uid),
    );
  }

  Future<void> _deleteQueryDocs(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(200).get();
      if (snapshot.docs.isEmpty) break;

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (snapshot.docs.length < 200) break;
    }
  }

  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(200).get();
      if (snapshot.docs.isEmpty) break;

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (snapshot.docs.length < 200) break;
    }
  }

  Future<void> _deleteStorageFolder(String path) async {
    try {
      final ref = _storage.ref(path);
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        await item.delete();
      }

      for (final prefix in listResult.prefixes) {
        await _deleteStorageFolder(prefix.fullPath);
      }
    } catch (_) {}
  }

  double calculateProfileCompletion(Map<String, dynamic> profile) {
    bool has(String k) {
      final val = profile[k];
      if (val == null) return false;
      if (val is List) return val.isNotEmpty;
      if (val is Map) return val.isNotEmpty;
      final text = val.toString().trim().toLowerCase();
      return text.isNotEmpty &&
          text != 'not specified' &&
          text != '+ add details' &&
          text != 'null';
    }

    // Comprehensive photo check
    bool hasPhoto = false;
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) hasPhoto = true;

    final checks = [
      has('firstName') || has('name'),
      has('gender'),
      has('dateOfBirth') || has('age'),
      has('partnerPreference'),
      has('city') && has('country'),
      has('highestQualification') || has('educationDegree') || has('education'),
      has('profession') || has('occupation'),
      has('lookingFor'),
      has('drinking') || has('smoking') || has('workout') || has('pets'),
      has('communicationStyle') ||
          has('loveLanguage') ||
          has('educationLevel') ||
          has('zodiac'),
      has('interests'),
      hasPhoto,
      has('bio') || has('aboutMe'),
    ];

    final completed = checks.where((c) => c).length;
    final score = completed / checks.length;
    return score.clamp(0.0, 1.0);
  }

  /// Checks text against the server-side spam/escort/scam keyword blocklist.
  /// Returns a warning message if flagged, or null if clean.
  /// Fails open (returns null) if the Cloud Function is unavailable.
  Future<String?> checkContentFilter(String text, String context) async {
    if (text.trim().isEmpty) return null;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('checkContentFilter')
          .call(<String, dynamic>{'text': text, 'context': context});
      final data = result.data as Map<String, dynamic>;
      if (data['flagged'] == true) {
        return 'Your text contains prohibited content. Please revise and try again.';
      }
      return null;
    } catch (_) {
      // Fail open — don't block user if filter is unavailable
      return null;
    }
  }

  Future<void> blockUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _userRef(currentUser.uid).update({
      'blockedUids': FieldValue.arrayUnion([uid]),
    });
    // Remove from connections (interests) immediately
    await _removeFromConnections(currentUser.uid, uid);
  }

  /// Reports a user via Cloud Function (rate limited: 5/hr per user).
  Future<void> reportUser(String targetUid, {String reason = '', String category = ''}) async {
    final functions = FirebaseFunctions.instance;
    await functions.httpsCallable('submitReport').call({
      'reportedUid': targetUid,
      'reason': reason,
      'category': category,
    });
  }

  /// Marks all interest documents between [myUid] and [otherUid] as 'blocked'
  /// so they disappear from the Connections / Matches tab immediately.
  Future<void> _removeFromConnections(String myUid, String otherUid) async {
    // Interests I sent to them
    final sent = await _firestore
        .collection('interests')
        .where('fromUserId', isEqualTo: myUid)
        .where('toUserId', isEqualTo: otherUid)
        .get();
    // Interests they sent to me
    final received = await _firestore
        .collection('interests')
        .where('fromUserId', isEqualTo: otherUid)
        .where('toUserId', isEqualTo: myUid)
        .get();

    final batch = _firestore.batch();
    for (final doc in [...sent.docs, ...received.docs]) {
      batch.update(doc.reference, {
        'status': 'blocked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 1. Remove from likes collection (both directions)
    batch.delete(
      _firestore
          .collection('likes')
          .doc(myUid)
          .collection('likedUsers')
          .doc(otherUid),
    );
    batch.delete(
      _firestore
          .collection('likes')
          .doc(otherUid)
          .collection('likedUsers')
          .doc(myUid),
    );

    // 2. Remove match document
    final matchId = myUid.compareTo(otherUid) < 0
        ? '${myUid}_$otherUid'
        : '${otherUid}_$myUid';
    batch.delete(_firestore.collection('matches').doc(matchId));

    await batch.commit();

    // Ensure we delete any existing chat thread between the two users
    try {
      await ChatService.instance.deleteChatThreadBetween(myUid, otherUid);
    } catch (_) {
      // Best-effort cleanup
    }
  }

  Future<void> unblockUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    // Only remove from blockedUids — reportedUids stays forever
    await _userRef(currentUser.uid).update({
      'blockedUids': FieldValue.arrayRemove([uid]),
      'ignoredMatchIds': FieldValue.arrayRemove([uid]),
    });

    try {
      final batch = _firestore.batch();
      batch.delete(
        _firestore
            .collection('likes')
            .doc(currentUser.uid)
            .collection('likedUsers')
            .doc(uid),
      );
      batch.delete(
        _firestore
            .collection('likes')
            .doc(uid)
            .collection('likedUsers')
            .doc(currentUser.uid),
      );
      await batch.commit();
    } catch (_) {}
  }

  Future<void> ignoreUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _userRef(currentUser.uid).update({
      'ignoredMatchIds': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> unignoreUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _userRef(currentUser.uid).update({
      'ignoredMatchIds': FieldValue.arrayRemove([uid]),
    });
  }

  /// In-app 7-day free trial (not a Stripe subscription).
  bool isOnFreeTrial(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final plan = profile['subscriptionPlan']?.toString().toLowerCase();
    final status = profile['subscriptionStatus']?.toString().toLowerCase();
    if (plan != 'trial' || status != 'trialing') return false;

    final endsAt = profile['freeTrialEndsAt'];
    if (endsAt is Timestamp) {
      return endsAt.toDate().isAfter(DateTime.now());
    }
    return true;
  }

  /// Paid Stripe premium (excludes in-app free trial).
  bool isPaidPremium(Map<String, dynamic>? profile) {
    if (profile == null || isOnFreeTrial(profile)) return false;

    final plan = profile['subscriptionPlan']?.toString().toLowerCase() ?? '';
    final topStatus = profile['subscriptionStatus']?.toString().toLowerCase() ?? '';

    final statuses = <String>[];
    if (topStatus.isNotEmpty) statuses.add(topStatus);
    final sub = profile['subscription'];
    if (sub is Map) {
      final nestedStatus = sub['status']?.toString().toLowerCase();
      if (nestedStatus != null && nestedStatus.isNotEmpty) {
        statuses.add(nestedStatus);
      }
    }

    final hasStripeSub =
        (profile['stripeSubscriptionId']?.toString() ?? '').isNotEmpty;
    final hasPaidPlan = plan == 'premium' || plan == 'gold';
    final hasStripePrice = sub is Map &&
        (sub['priceId']?.toString() ?? '').isNotEmpty;

    for (final status in statuses) {
      if (status != 'active' && status != 'trialing') continue;
      if (hasStripeSub || hasPaidPlan || hasStripePrice) return true;
    }

    if (hasStripeSub &&
        (topStatus == 'active' || topStatus == 'trialing')) {
      return true;
    }

    return false;
  }

  /// Premium access for limits/features (paid OR in-app trial).
  bool isPremium(Map<String, dynamic>? profile) {
    return isPaidPremium(profile) || isOnFreeTrial(profile);
  }

  /// Clears in-app trial fields only after a paid Stripe plan is confirmed.
  Future<void> endTrialAfterPaidUpgrade() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    invalidateCurrentUserCache();
    final profile = await getUserProfile(uid);
    if (!isPaidPremium(profile)) return;

    final hadTrialFields = isOnFreeTrial(profile) ||
        profile?['freeTrialEndsAt'] != null ||
        profile?['freeTrialStartedAt'] != null;
    if (!hadTrialFields) return;

    _invalidateCache(uid);
    await _userRef(uid).set({
      'subscriptionPlan': 'premium',
      'subscriptionStatus': profile?['subscriptionStatus'] ?? 'active',
      'freeTrialEndsAt': FieldValue.delete(),
      'freeTrialStartedAt': FieldValue.delete(),
      'trialEndedAt': FieldValue.serverTimestamp(),
      'trialEndedReason': 'upgraded_to_premium',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Count users by relationship goal (lookingFor field)
  Stream<Map<String, int>> watchUserCountsByRelationshipGoal() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final counts = <String, int>{
        'Ready to Marry': 0,
        'Something Serious': 0,
        'Long-term Partner': 0,
        'Just Browsing': 0,
        'Let Love Lead': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lookingFor = data['lookingFor']?.toString();
        if (lookingFor != null) {
          // Exact matching with case-insensitive comparison
          final normalized = lookingFor.toLowerCase().trim();
          if (normalized == 'ready to marry' ||
              normalized == 'ready to Marry') {
            counts['Ready to Marry'] = (counts['Ready to Marry'] ?? 0) + 1;
          } else if (normalized == 'something serious') {
            counts['Something Serious'] =
                (counts['Something Serious'] ?? 0) + 1;
          } else if (normalized == 'long-term partner' ||
              normalized == 'long term partner') {
            counts['Long-term Partner'] =
                (counts['Long-term Partner'] ?? 0) + 1;
          } else if (normalized == 'just browsing') {
            counts['Just Browsing'] = (counts['Just Browsing'] ?? 0) + 1;
          } else if (normalized == 'let love lead') {
            counts['Let Love Lead'] = (counts['Let Love Lead'] ?? 0) + 1;
          }
        }
      }

      return counts;
    });
  }

  /// Get users by relationship goal
  Stream<List<Map<String, dynamic>>> getUsersByRelationshipGoal(
    String goalTitle,
  ) {
    // Convert goal title to lowercase for matching
    final goalLower = goalTitle.toLowerCase();

    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lookingFor = data['lookingFor']?.toString();
        if (lookingFor != null) {
          final normalized = lookingFor.toLowerCase().trim();

          bool matches = false;
          if (goalLower.contains('ready to marry') &&
              (normalized == 'ready to marry' ||
                  normalized == 'ready to Marry')) {
            matches = true;
          } else if (goalLower.contains('something serious') &&
              normalized == 'something serious') {
            matches = true;
          } else if (goalLower.contains('long-term') &&
              (normalized == 'long-term partner' ||
                  normalized == 'long term partner')) {
            matches = true;
          } else if (goalLower.contains('just browsing') &&
              normalized == 'just browsing') {
            matches = true;
          } else if (goalLower.contains('let love lead') &&
              normalized == 'let love lead') {
            matches = true;
          }

          if (matches && 
              data['registrationCompleted'] == true && 
              data['profileApprovalStatus'] == 'approved') {
            users.add(<String, dynamic>{...data, 'uid': doc.id});
          }
        }
      }

      return users;
    });
  }
}
