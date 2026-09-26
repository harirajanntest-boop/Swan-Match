import 'package:cloud_firestore/cloud_firestore.dart';

/// A video-first "connection" request: `sender` records a topic-based video
/// response addressed to `receiver`; if accepted, a `chats/{id}` doc (same id)
/// is created and chat unlocks. Mirrors `InterestModel`'s style.
///
/// Firestore doc id convention: `sorted(senderId, receiverId).join('_')`,
/// same as the existing `matches`/`chats` id convention.
class ConnectionModel {
	final String id;
	final String senderId;
	final String receiverId;
	final String topic;
	final String videoUrl; // temporary — may be deleted by cleanup job by the time it's read
	final String videoThumbnailUrl; // JPEG preview frame, shown while videoUrl buffers/loads
	final String status; // 'pending' | 'accepted' | 'declined' | 'expired'
	final DateTime createdAt;
	final DateTime expiresAt;
	final DateTime? resolvedAt;
	final DateTime? reportedAt; // set when reported; blocks cleanup from deleting evidence

	const ConnectionModel({
		required this.id,
		required this.senderId,
		required this.receiverId,
		this.topic = '',
		this.videoUrl = '',
		this.videoThumbnailUrl = '',
		this.status = 'pending',
		required this.createdAt,
		required this.expiresAt,
		this.resolvedAt,
		this.reportedAt,
	});

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'senderId': senderId,
			'receiverId': receiverId,
			'topic': topic,
			'videoUrl': videoUrl,
			'videoThumbnailUrl': videoThumbnailUrl,
			'status': status,
			'createdAt': Timestamp.fromDate(createdAt),
			'expiresAt': Timestamp.fromDate(expiresAt),
			'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt!),
			'reportedAt': reportedAt == null ? null : Timestamp.fromDate(reportedAt!),
		};
	}

	factory ConnectionModel.fromMap(Map<String, dynamic> map) {
		DateTime read(dynamic value) {
			if (value is Timestamp) return value.toDate();
			return DateTime.now();
		}

		DateTime? readNullable(dynamic value) {
			if (value is Timestamp) return value.toDate();
			return null;
		}

		return ConnectionModel(
			id: (map['id'] ?? '') as String,
			senderId: (map['senderId'] ?? '') as String,
			receiverId: (map['receiverId'] ?? '') as String,
			topic: (map['topic'] ?? '') as String,
			videoUrl: (map['videoUrl'] ?? '') as String,
			videoThumbnailUrl: (map['videoThumbnailUrl'] ?? '') as String,
			status: (map['status'] ?? 'pending') as String,
			createdAt: read(map['createdAt']),
			expiresAt: read(map['expiresAt']),
			resolvedAt: readNullable(map['resolvedAt']),
			reportedAt: readNullable(map['reportedAt']),
		);
	}

	factory ConnectionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
		final data = doc.data() ?? <String, dynamic>{};
		data['id'] = doc.id;
		return ConnectionModel.fromMap(data);
	}
}
