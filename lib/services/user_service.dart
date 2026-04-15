import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/stream_utils.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUid => _auth.currentUser?.uid;

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
    await upsertUserProfile(uid: user.uid, data: updates);
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snapshot = await _userRef(uid).get();
    return snapshot.data();
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
        if (data == null) return null;
        return <String, dynamic>{...data, 'uid': uid};
      });
    });
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
    bool hasPhoto =
        has('photoUrl') || has('profileImageUrl') || has('imageUrl');
    if (!hasPhoto) {
      final photos = profile['photos'];
      if (photos is List && photos.isNotEmpty) hasPhoto = true;
    }

    final checks = [
      has('name'),
      has('gender'),
      has('dateOfBirth') || has('age'),
      has('religion'),
      has('caste'),
      has('motherTongue'),
      has('height'),
      has('educationDegree') || has('education'),
      has('occupation'),
      has('annualIncome') || has('income'),
      has('city') || has('state') || has('country'),
      hasPhoto,
      has('aboutMe'),
      has('partnerPreference') || has('partnerPreferences'),
      has('interests'),
      has('lifestyle'),
    ];

    final completed = checks.where((c) => c).length;
    final score = completed / checks.length;
    return score.clamp(0.0, 1.0);
  }

  Future<void> blockUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _userRef(currentUser.uid).update({
      'blockedUids': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> unblockUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _userRef(currentUser.uid).update({
      'blockedUids': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> ignoreUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Hide for 2 days
    final expiration = DateTime.now().add(const Duration(days: 2));
    await _userRef(
      currentUser.uid,
    ).update({'ignoredProfiles.$uid': Timestamp.fromDate(expiration)});
  }

  Future<void> unignoreUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _userRef(
      currentUser.uid,
    ).update({'ignoredProfiles.$uid': FieldValue.delete()});
  }

  bool isPremium(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final status = profile['subscriptionStatus']?.toString().toLowerCase();
    final plan = profile['subscriptionPlan']?.toString().toLowerCase();
    return status == 'active' || status == 'trialing' || plan == 'premium';
  }
}
