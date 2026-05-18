import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/stream_utils.dart';
import '../services/app_notification_service.dart';
import '../models/interest_model.dart';
import 'chat_service.dart';
import 'subscription_limits_service.dart';

enum InterestSendResult {
	sent,
	pending,
	alreadyAccepted,
	trialLimitReached,  // Free user daily limit hit
	premiumRequired,    // Feature needs premium
}

class InterestService {
	InterestService._();

	static final InterestService instance = InterestService._();

	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	CollectionReference<Map<String, dynamic>> get _interests =>
			_firestore.collection('interests');

	Stream<String?> get _uidStream =>
			_auth.authStateChanges().map((u) => u?.uid).distinct();

	Future<InterestSendResult> sendInterest({required String toUserId}) async {
		final user = _auth.currentUser;
		if (user == null || toUserId.isEmpty || toUserId == user.uid) {
			return InterestSendResult.pending;
		}

		// ── Premium / trial gate ──────────────────────────────────────────────
		final limitCheck =
				await SubscriptionLimitsService.instance.canSendInterest();
		if (!limitCheck.allowed) {
			return InterestSendResult.trialLimitReached;
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
		// Record trial usage
		await SubscriptionLimitsService.instance.recordInterestSent();
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

		final fromUserId = (data['fromUserId'] ?? '').toString();
		final toUserId = (data['toUserId'] ?? '').toString();
		if (fromUserId.isEmpty || toUserId.isEmpty) return;

		final normalized = status.toLowerCase();
		final currentUserId = _auth.currentUser?.uid ?? '';

		if (normalized == 'accepted' && currentUserId == toUserId) {
			final acceptCheck =
					await SubscriptionLimitsService.instance.canAcceptInterest();
			if (!acceptCheck.allowed) {
				throw Exception(acceptCheck.reason ?? 'Accept limit reached');
			}
		}

		await _interests.doc(interestId).update(<String, dynamic>{
			'status': status,
			'updatedAt': FieldValue.serverTimestamp(),
		});

		// Disconnect / decline — clear chat, likes, and sync both interest directions
		// so the other user can see them again on Discover.
		if (normalized == 'declined' || normalized == 'blocked') {
			await _clearConnectionBetween(fromUserId, toUserId, status: normalized);
		}

		if (currentUserId == toUserId && normalized == 'accepted') {
			await SubscriptionLimitsService.instance.recordAccept();
			final chatBlocked = await SubscriptionLimitsService.instance
					.isChatBlockedForFreeUser(otherUserId: fromUserId);
			if (!chatBlocked) {
				await ChatService.instance.ensureChatThread(
						firstUserId: fromUserId,
						secondUserId: toUserId,
						seedMessage: 'Interest accepted. You can now start chatting.',
						lastSenderId: toUserId,
				);
			}
		}

		final receiverProfile = await _firestore.collection('users').doc(toUserId).get();
		final receiverName = (receiverProfile.data()?['name'] ?? 'A member').toString();
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
		return switchMap(_uidStream, (uid) {
			if (uid == null) {
				return Stream.value(<InterestModel>[]);
			}

			return _interests
					.where('fromUserId', isEqualTo: uid)
					.snapshots()
					.map(
						(snapshot) {
							final items = snapshot.docs
									.map(
										(doc) => InterestModel.fromMap({
											...doc.data(),
											'id': doc.id,
										}),
									)
									.toList();
							items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
							return items;
						},
					);
		});
	}

	Stream<Set<String>> watchMyPendingSentInterestUserIds() {
		return watchMySentInterests().map((items) {
			return items
					.where((item) => item.status.toLowerCase() == 'pending')
					.map((item) => item.toUserId)
					.toSet();
		});
	}

	/// Returns the set of userIds to whom the current user sent an interest
	/// that was accepted (or replied). Used to disable the Connect button.
	Stream<Set<String>> watchMyAcceptedSentInterestUserIds() {
		return watchMySentInterests().map((items) {
			return items
					.where((item) {
						final s = item.status.toLowerCase();
						return s == 'accepted' || s == 'replied';
					})
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

	/// Declines/blocks all interest docs between two users and removes swipe likes.
	Future<void> _clearConnectionBetween(
		String userA,
		String userB, {
		required String status,
	}) async {
		try {
			await ChatService.instance.deleteChatThreadBetween(userA, userB);
		} catch (_) {}

		final sent = await _interests
				.where('fromUserId', isEqualTo: userA)
				.where('toUserId', isEqualTo: userB)
				.get();
		final received = await _interests
				.where('fromUserId', isEqualTo: userB)
				.where('toUserId', isEqualTo: userA)
				.get();

		final batch = _firestore.batch();
		final now = FieldValue.serverTimestamp();
		for (final doc in [...sent.docs, ...received.docs]) {
			batch.update(doc.reference, {
				'status': status,
				'updatedAt': now,
			});
		}

		// Swipe stores likes separately — remove so profile reappears on Discover.
		batch.delete(
			_firestore
					.collection('likes')
					.doc(userA)
					.collection('likedUsers')
					.doc(userB),
		);
		batch.delete(
			_firestore
					.collection('likes')
					.doc(userB)
					.collection('likedUsers')
					.doc(userA),
		);

		final matchId = userA.compareTo(userB) < 0
				? '${userA}_$userB'
				: '${userB}_$userA';
		batch.delete(_firestore.collection('matches').doc(matchId));

		await batch.commit();
	}

	Stream<List<InterestModel>> watchInterestsForMe() {
		return switchMap(_uidStream, (uid) {
			if (uid == null) {
				return Stream.value(<InterestModel>[]);
			}

			return _interests
					.where('toUserId', isEqualTo: uid)
					.snapshots()
					.map(
						(snapshot) {
							final items = snapshot.docs
									.map(
										(doc) => InterestModel.fromMap({
											...doc.data(),
											'id': doc.id,
										}),
									)
									.toList();
							items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
							return items;
						},
					);
		});
	}
}
