import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/stream_utils.dart';
import '../models/message_model.dart';
import 'subscription_limits_service.dart';

class ChatService {
	ChatService._();

	static final ChatService instance = ChatService._();

	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	Stream<String?> get _uidStream =>
			_auth.authStateChanges().map((u) => u?.uid).distinct();

	String chatIdFor(String first, String second) {
		final ids = [first, second]..sort();
		return ids.join('_');
	}

	CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) {
		return _firestore.collection('chats').doc(chatId).collection('messages');
	}

	Future<void> ensureChatThread({
		required String firstUserId,
		required String secondUserId,
		String? seedMessage,
		String? lastSenderId,
	}) async {
		final chatId = chatIdFor(firstUserId, secondUserId);
		await _firestore.collection('chats').doc(chatId).set(<String, dynamic>{
			'id': chatId,
			'participants': [firstUserId, secondUserId],
			'lastMessage': (seedMessage ?? '').trim(),
			'lastMessageSenderId': (lastSenderId ?? firstUserId),
			'lastMessageAt': FieldValue.serverTimestamp(),
		}, SetOptions(merge: true));
	}

	Future<bool> sendMessage({
		required String receiverId,
		required String text,
	}) async {
		final sender = _auth.currentUser;
		if (sender == null || text.trim().isEmpty) return false;

		final check =
				await SubscriptionLimitsService.instance.canSendMessageTo(receiverId);
		if (!check.allowed) return false;

		// ── Block gate: don't deliver if receiver has blocked this sender ──
		if (await _isBlockedByReceiver(sender.uid, receiverId)) return false;

		final chatId = chatIdFor(sender.uid, receiverId);
		final id = _messagesRef(chatId).doc().id;
		final now = DateTime.now();

		final message = MessageModel(
			id: id,
			chatId: chatId,
			senderId: sender.uid,
			receiverId: receiverId,
			text: text.trim(),
			sentAt: now,
		);

		// Chat thread first: firestore.rules only accept a message into a chat
		// doc that already exists with both users as participants.
		await ensureChatThread(
				firstUserId: sender.uid,
				secondUserId: receiverId,
				seedMessage: text.trim(),
				lastSenderId: sender.uid,
		);

		await _messagesRef(chatId).doc(id).set(message.toMap());

		await SubscriptionLimitsService.instance.recordMessagePartner(receiverId);
		// Chat push is sent by Cloud Function `onMessageCreated` on the message doc.
		return true;
	}

	/// Marks every message the other user sent to me as "seen". Call this when
	/// the current user opens the conversation, so the SENDER's app flips its
	/// sent messages from a single tick (delivered) to a double tick (seen).
	Future<void> markMessagesSeen(String otherUserId) async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		final chatId = chatIdFor(uid, otherUserId);
		try {
			// Messages addressed TO me (sent by the other user). Single-field
			// filter avoids needing a composite index; we skip already-seen ones.
			final snap =
					await _messagesRef(chatId).where('receiverId', isEqualTo: uid).get();
			final unseen =
					snap.docs.where((d) => d.data()['seen'] != true).toList();
			if (unseen.isEmpty) return;
			// Firestore caps a batch at 500 writes — commit in chunks.
			for (var i = 0; i < unseen.length; i += 450) {
				final batch = _firestore.batch();
				for (final d in unseen.skip(i).take(450)) {
					batch.update(d.reference, {'seen': true});
				}
				await batch.commit();
			}
		} catch (_) {
			// best-effort — never block the UI on read-receipt writes
		}
	}

	/// Deletes the entire chat thread (messages subcollection and chat doc)
	/// between two users. Safe to call whether or not the chat exists.
	Future<void> deleteChatThreadBetween(String firstUserId, String secondUserId) async {
		final chatId = chatIdFor(firstUserId, secondUserId);
		final chatDoc = _firestore.collection('chats').doc(chatId);
		try {
			// Delete messages subcollection
			final msgsSnap = await chatDoc.collection('messages').get();
			for (final m in msgsSnap.docs) {
				await m.reference.delete();
			}
			// Delete the chat document
			await chatDoc.delete();
		} catch (_) {
			// ignore errors — best effort cleanup
		}
	}

	Stream<List<Map<String, dynamic>>> watchMyChats() {
		return switchMap(_uidStream, (uid) {
			if (uid == null) {
				return Stream.value(<Map<String, dynamic>>[]);
			}

			// Watch current user's blocked/reported lists reactively
			final profileStream = _firestore
					.collection('users')
					.doc(uid)
					.snapshots()
					.map((snap) => snap.data() ?? <String, dynamic>{});

			return switchMap(profileStream, (myProfile) {
				final blockedUids = Set<String>.from(myProfile['blockedUids'] ?? []);
				final reportedUids = Set<String>.from(myProfile['reportedUids'] ?? []);
				final hiddenUids = {...blockedUids, ...reportedUids};

				return _firestore
						.collection('chats')
						.where('participants', arrayContains: uid)
						.orderBy('lastMessageAt', descending: true)
						.snapshots()
						.map((snapshot) => snapshot.docs
								.map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
								.where((chat) {
									final participants =
											(chat['participants'] as List<dynamic>? ?? [])
													.map((e) => e.toString())
													.toList();
									final otherUid = participants.firstWhere(
										(p) => p != uid,
										orElse: () => '',
									);
									return otherUid.isNotEmpty && !hiddenUids.contains(otherUid);
								})
								.toList());
			});
		});
	}

	/// Blocks message delivery if the receiver has blocked the sender.
	Future<bool> _isBlockedByReceiver(String senderId, String receiverId) async {
		final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
		final blockedUids = List<String>.from(receiverDoc.data()?['blockedUids'] ?? []);
		return blockedUids.contains(senderId);
	}

	Stream<List<MessageModel>> watchMessages(String otherUserId, {int limitCount = 40}) {
		return switchMap(_uidStream, (uid) {
			if (uid == null) {
				return Stream.value(<MessageModel>[]);
			}

			final chatId = chatIdFor(uid, otherUserId);
			return _messagesRef(chatId)
					.orderBy('sentAt', descending: true)
					.limit(limitCount)
					// includeMetadataChanges: true → locally-written docs appear immediately
					// with hasPendingWrites=true before the server confirms them.
					.snapshots(includeMetadataChanges: true)
					.map(
						(snapshot) {
							final messages = snapshot.docs
								.map((doc) => MessageModel.fromMap(
											doc.data(),
											hasPendingWrites: doc.metadata.hasPendingWrites,
										))
								.toList();
							final seen = <String>{};
							return messages.where((m) => seen.add(m.id)).toList();
						}
					);
		});
	}
}
