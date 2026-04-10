import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
	UserService._();

	static final UserService instance = UserService._();

	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	DocumentReference<Map<String, dynamic>> _userRef(String uid) {
		return _firestore.collection('users').doc(uid);
	}

	Future<void> upsertUserProfile({
		required String uid,
		required Map<String, dynamic> data,
	}) async {
		final payload = <String, dynamic>{
			...data,
			'updatedAt': FieldValue.serverTimestamp(),
		};

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
		final user = _auth.currentUser;
		if (user == null) {
			return const Stream<Map<String, dynamic>?>.empty();
		}
		return _userRef(user.uid).snapshots().map((doc) {
			final data = doc.data();
			if (data == null) return null;
			return <String, dynamic>{...data, 'uid': user.uid};
		});
	}

	Future<void> updatePartnerPreferences(Map<String, dynamic> preferences) async {
		await updateCurrentUserProfile(<String, dynamic>{
			'partnerPreferences': preferences,
		});
	}

	Future<void> updateInterests(List<String> interests) async {
		await updateCurrentUserProfile(<String, dynamic>{
			'interests': interests,
		});
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

		await _deleteInterests(uid);
		await _deleteNotifications(uid);
		await _deleteChats(uid);
		await _deleteQueryDocs(
				_firestore.collection('users').where('uid', isEqualTo: uid),
		);
		await _userRef(uid).delete();

		await user.delete();
		await _auth.signOut();
	}

	Future<void> _deleteInterests(String uid) async {
		await _deleteQueryDocs(
				_firestore.collection('interests').where('fromUserId', isEqualTo: uid),
		);
		await _deleteQueryDocs(
				_firestore.collection('interests').where('toUserId', isEqualTo: uid),
		);
	}

	Future<void> _deleteNotifications(String uid) async {
		await _deleteQueryDocs(
				_firestore.collection('notifications').where('fromUserId', isEqualTo: uid),
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
}
