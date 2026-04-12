import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/stream_utils.dart';
import 'app_notification_service.dart';
import '../models/message_model.dart';

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

	Future<void> sendMessage({
		required String receiverId,
		required String text,
	}) async {
		final sender = _auth.currentUser;
		if (sender == null || text.trim().isEmpty) return;

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

		await _messagesRef(chatId).doc(id).set(message.toMap());

		await ensureChatThread(
				firstUserId: sender.uid,
				secondUserId: receiverId,
				seedMessage: text.trim(),
				lastSenderId: sender.uid,
		);

		final senderProfile = await _firestore.collection('users').doc(sender.uid).get();
		final senderName = (senderProfile.data()?['name'] ?? 'Someone').toString();
		await AppNotificationService.instance.createNotification(
			toUserId: receiverId,
			title: senderName,
			message: text.trim(),
			type: 'interaction',
			meta: <String, dynamic>{
				'chatId': chatId,
				'event': 'new_message',
			},
		);
	}

	Stream<List<Map<String, dynamic>>> watchMyChats() {
		return switchMap(_uidStream, (uid) {
			if (uid == null) {
				return Stream.value(<Map<String, dynamic>>[]);
			}

			return _firestore
					.collection('chats')
					.where('participants', arrayContains: uid)
					.orderBy('lastMessageAt', descending: true)
					.snapshots()
					.map(
						(snapshot) => snapshot.docs
								.map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
								.toList(),
					);
		});
	}

	Stream<List<MessageModel>> watchMessages(String otherUserId) {
		return switchMap(_uidStream, (uid) {
			if (uid == null) {
				return Stream.value(<MessageModel>[]);
			}

			final chatId = chatIdFor(uid, otherUserId);
			return _messagesRef(chatId)
					.orderBy('sentAt', descending: true)
					.snapshots()
					.map(
						(snapshot) => snapshot.docs
								.map((doc) => MessageModel.fromMap(doc.data()))
								.toList(),
					);
		});
	}
}
