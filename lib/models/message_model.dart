import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
	final String id;
	final String chatId;
	final String senderId;
	final String receiverId;
	final String text;
	final DateTime sentAt;

	const MessageModel({
		required this.id,
		required this.chatId,
		required this.senderId,
		required this.receiverId,
		required this.text,
		required this.sentAt,
	});

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'chatId': chatId,
			'senderId': senderId,
			'receiverId': receiverId,
			'text': text,
			'sentAt': Timestamp.fromDate(sentAt),
		};
	}

	factory MessageModel.fromMap(Map<String, dynamic> map) {
		return MessageModel(
			id: (map['id'] ?? '') as String,
			chatId: (map['chatId'] ?? '') as String,
			senderId: (map['senderId'] ?? '') as String,
			receiverId: (map['receiverId'] ?? '') as String,
			text: (map['text'] ?? '') as String,
			sentAt: map['sentAt'] is Timestamp
					? (map['sentAt'] as Timestamp).toDate()
					: DateTime.now(),
		);
	}
}
