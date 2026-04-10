import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/app_notification_service.dart';
import '../services/chat_service.dart';
import '../models/interest_model.dart';

enum InterestSendResult {
	sent,
	pending,
	alreadyAccepted,
}

class InterestService {
	InterestService._();

	static final InterestService instance = InterestService._();

	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	CollectionReference<Map<String, dynamic>> get _interests =>
			_firestore.collection('interests');

	Future<InterestSendResult> sendInterest({required String toUserId}) async {
		final user = _auth.currentUser;
		if (user == null || toUserId.isEmpty || toUserId == user.uid) {
			return InterestSendResult.pending;
		}

		final existingSnapshot = await _interests
				.where('fromUserId', isEqualTo: user.uid)
				.where('toUserId', isEqualTo: toUserId)
				.get();

		if (existingSnapshot.docs.isNotEmpty) {
			final pendingDoc = existingSnapshot.docs.where((doc) {
				final status = (doc.data()['status'] ?? '').toString().toLowerCase();
				return status == 'pending';
			}).toList();

			if (pendingDoc.isNotEmpty) {
				return InterestSendResult.pending;
			}

			final acceptedDoc = existingSnapshot.docs.where((doc) {
				final status = (doc.data()['status'] ?? '').toString().toLowerCase();
				return status == 'accepted' || status == 'replied';
			}).toList();

			if (acceptedDoc.isNotEmpty) {
				return InterestSendResult.alreadyAccepted;
			}

			final docToReuse = existingSnapshot.docs.first;
			await _interests.doc(docToReuse.id).update(<String, dynamic>{
				'status': 'pending',
				'updatedAt': FieldValue.serverTimestamp(),
			});

			await _notifyInterestSent(toUserId: toUserId, interestId: docToReuse.id, senderId: user.uid);
			return InterestSendResult.sent;
		}

		final id = _interests.doc().id;
		final now = DateTime.now();

		final model = InterestModel(
			id: id,
			fromUserId: user.uid,
			toUserId: toUserId,
			createdAt: now,
			updatedAt: now,
		);

		await _interests.doc(id).set(model.toMap());
		await _notifyInterestSent(toUserId: toUserId, interestId: id, senderId: user.uid);
		return InterestSendResult.sent;
	}

	Future<void> _notifyInterestSent({
		required String toUserId,
		required String interestId,
		required String senderId,
	}) async {
		final senderProfile = await _firestore.collection('users').doc(senderId).get();
		final senderName = (senderProfile.data()?['name'] ?? 'Someone').toString();
		await AppNotificationService.instance.createNotification(
			toUserId: toUserId,
			title: senderName,
			message: 'sent you an interest',
			type: 'interaction',
			meta: <String, dynamic>{
				'interestId': interestId,
				'event': 'interest_sent',
			},
		);
	}

	Future<void> updateInterestStatus({
		required String interestId,
		required String status,
	}) async {
		final doc = await _interests.doc(interestId).get();
		final data = doc.data();
		if (data == null) return;

		await _interests.doc(interestId).update(<String, dynamic>{
			'status': status,
			'updatedAt': FieldValue.serverTimestamp(),
		});

		final fromUserId = (data['fromUserId'] ?? '').toString();
		final toUserId = (data['toUserId'] ?? '').toString();
		if (fromUserId.isEmpty || toUserId.isEmpty) return;

		final currentUserId = _auth.currentUser?.uid ?? '';
		if (currentUserId == toUserId && status.toLowerCase() == 'accepted') {
			await ChatService.instance.ensureChatThread(
					firstUserId: fromUserId,
					secondUserId: toUserId,
					seedMessage: 'Interest accepted. You can now start chatting.',
					lastSenderId: toUserId,
			);
		}

		final receiverProfile = await _firestore.collection('users').doc(toUserId).get();
		final receiverName = (receiverProfile.data()?['name'] ?? 'A member').toString();
		final normalized = status.toLowerCase();
		final message = normalized == 'accepted'
				? 'accepted your interest. You can now message.'
				: 'updated your interest status to $status';
		await AppNotificationService.instance.createNotification(
			toUserId: fromUserId,
			title: receiverName,
			message: message,
			type: 'interaction',
			meta: <String, dynamic>{
				'interestId': interestId,
				'event': 'interest_$normalized',
			},
		);
	}

	Stream<List<InterestModel>> watchMySentInterests() {
		final user = _auth.currentUser;
		if (user == null) return const Stream<List<InterestModel>>.empty();

		return _interests
				.where('fromUserId', isEqualTo: user.uid)
				.snapshots()
				.map(
					(snapshot) {
						final items = snapshot.docs
								.map((doc) => InterestModel.fromMap(doc.data()))
								.toList();
						items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
						return items;
					},
				);
	}

	Stream<Set<String>> watchMyPendingSentInterestUserIds() {
		return watchMySentInterests().map((items) {
			return items
					.where((item) => item.status.toLowerCase() == 'pending')
					.map((item) => item.toUserId)
					.toSet();
		});
	}

	Stream<Map<String, String>> watchMySentInterestStatusByUserId() {
		return watchMySentInterests().map((items) {
			final latestByUser = <String, InterestModel>{};
			for (final item in items) {
				final previous = latestByUser[item.toUserId];
				if (previous == null || item.updatedAt.isAfter(previous.updatedAt)) {
					latestByUser[item.toUserId] = item;
				}
			}

			return latestByUser.map(
				(userId, model) => MapEntry(userId, model.status.toLowerCase()),
			);
		});
	}

	Stream<List<InterestModel>> watchInterestsForMe() {
		final user = _auth.currentUser;
		if (user == null) return const Stream<List<InterestModel>>.empty();

		return _interests
				.where('toUserId', isEqualTo: user.uid)
				.snapshots()
				.map(
					(snapshot) {
						final items = snapshot.docs
								.map((doc) => InterestModel.fromMap(doc.data()))
								.toList();
						items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
						return items;
					},
				);
	}
}
