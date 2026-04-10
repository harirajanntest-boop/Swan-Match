import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchService {
	MatchService._();

	static final MatchService instance = MatchService._();

	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	CollectionReference<Map<String, dynamic>> get _profileViews =>
			_firestore.collection('profileViews');

	Stream<List<Map<String, dynamic>>> watchRecommendedMatches({int limit = 25}) {
		final user = _auth.currentUser;
		if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();

		return _firestore
				.collection('users')
				.where('registrationCompleted', isEqualTo: true)
				.snapshots()
				.map(
					(snapshot) => snapshot.docs
							.map((doc) => <String, dynamic>{...doc.data(), 'uid': doc.id})
							.where((profile) => (profile['uid'] ?? '').toString() != user.uid)
							.where(_isVisibleToEveryone)
							.take(limit)
							.toList(),
				);
	}

		Stream<List<Map<String, dynamic>>> watchAllMatches() {
			final user = _auth.currentUser;
			if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();

			return _firestore
					.collection('users')
					.where('registrationCompleted', isEqualTo: true)
					.snapshots()
					.map(
						(snapshot) => snapshot.docs
								.map((doc) => <String, dynamic>{...doc.data(), 'uid': doc.id})
								.where((profile) => (profile['uid'] ?? '').toString() != user.uid)
								.where(_isVisibleToEveryone)
								.toList(),
					);
		}

	Stream<List<Map<String, dynamic>>> watchNewMatches({int days = 7}) {
		final user = _auth.currentUser;
		final cutoff = DateTime.now().subtract(Duration(days: days));
		return _firestore
				.collection('users')
				.where('registrationCompleted', isEqualTo: true)
				.snapshots()
				.map(
					(snapshot) {
						final items = snapshot.docs
								.map((doc) => <String, dynamic>{...doc.data(), 'uid': doc.id})
								.where((profile) => (profile['uid'] ?? '').toString() != (user?.uid ?? ''))
								.where(_isVisibleToEveryone)
								.where((profile) {
									final createdAt = profile['createdAt'];
									if (createdAt == null) return true;
									if (createdAt.runtimeType.toString() == 'Timestamp') {
										try {
											return (createdAt.toDate() as DateTime).isAfter(cutoff);
										} catch (_) {
											return true;
										}
									}
									if (createdAt is DateTime) {
										return createdAt.isAfter(cutoff);
									}
									return true;
								})
								.toList();

						items.sort((a, b) {
							DateTime parse(dynamic raw) {
								if (raw is DateTime) return raw;
								if (raw != null && raw.runtimeType.toString() == 'Timestamp') {
									try {
										return raw.toDate() as DateTime;
									} catch (_) {
										return DateTime.fromMillisecondsSinceEpoch(0);
									}
								}
								return DateTime.fromMillisecondsSinceEpoch(0);
							}

							return parse(b['createdAt']).compareTo(parse(a['createdAt']));
						});

						return items;
					},
				);
	}

	bool _isVisibleToEveryone(Map<String, dynamic> profile) {
		return profile['showProfileToEveryone'] != false;
	}

	Future<void> recordProfileView({required String viewedUserId}) async {
		final user = _auth.currentUser;
		if (user == null || viewedUserId.isEmpty || viewedUserId == user.uid) return;

		final id = '${user.uid}_$viewedUserId';
		await _profileViews.doc(id).set(<String, dynamic>{
			'id': id,
			'fromUserId': user.uid,
			'toUserId': viewedUserId,
			'updatedAt': FieldValue.serverTimestamp(),
			'createdAt': FieldValue.serverTimestamp(),
		}, SetOptions(merge: true));
	}

	Stream<List<Map<String, dynamic>>> watchViewedYouMatches() {
		final user = _auth.currentUser;
		if (user == null) return const Stream<List<Map<String, dynamic>>>.empty();

		return _profileViews
				.where('toUserId', isEqualTo: user.uid)
				.orderBy('updatedAt', descending: true)
				.snapshots()
				.asyncMap((snapshot) async {
					final viewerIds = snapshot.docs
							.map((doc) => (doc.data()['fromUserId'] ?? '').toString())
							.where((id) => id.isNotEmpty)
							.toList();
					if (viewerIds.isEmpty) return <Map<String, dynamic>>[];

					final usersSnapshot = await _firestore
							.collection('users')
							.where(FieldPath.documentId, whereIn: viewerIds.take(10).toList())
							.get();

					final usersById = {
						for (final doc in usersSnapshot.docs)
							doc.id: <String, dynamic>{...doc.data(), 'uid': doc.id},
					};

					final ordered = <Map<String, dynamic>>[];
					for (final id in viewerIds) {
						final profile = usersById[id];
						if (profile != null && _isVisibleToEveryone(profile)) {
							ordered.add(profile);
						}
					}
					return ordered;
				});
	}
}
