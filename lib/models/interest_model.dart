import 'package:cloud_firestore/cloud_firestore.dart';

class InterestModel {
	final String id;
	final String fromUserId;
	final String toUserId;
	final String status;
	final DateTime createdAt;
	final DateTime updatedAt;

	const InterestModel({
		required this.id,
		required this.fromUserId,
		required this.toUserId,
		this.status = 'pending',
		required this.createdAt,
		required this.updatedAt,
	});

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'fromUserId': fromUserId,
			'toUserId': toUserId,
			'status': status,
			'createdAt': Timestamp.fromDate(createdAt),
			'updatedAt': Timestamp.fromDate(updatedAt),
		};
	}

	factory InterestModel.fromMap(Map<String, dynamic> map) {
		DateTime read(dynamic value) {
			if (value is Timestamp) return value.toDate();
			return DateTime.now();
		}

		return InterestModel(
			id: (map['id'] ?? '') as String,
			fromUserId: (map['fromUserId'] ?? '') as String,
			toUserId: (map['toUserId'] ?? '') as String,
			status: (map['status'] ?? 'pending') as String,
			createdAt: read(map['createdAt']),
			updatedAt: read(map['updatedAt']),
		);
	}
}
