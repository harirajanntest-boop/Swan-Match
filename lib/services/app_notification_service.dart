import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createNotification({
    required String toUserId,
    required String title,
    required String message,
    String type = 'interaction',
    Map<String, dynamic>? meta,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (toUserId.isEmpty || currentUserId == null || toUserId == currentUserId) {
      return;
    }

    final id = _firestore.collection('notifications').doc().id;
    await _firestore.collection('notifications').doc(id).set(<String, dynamic>{
      'id': id,
      'toUserId': toUserId,
      'fromUserId': currentUserId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'isSystem': false,
      'createdAt': FieldValue.serverTimestamp(),
      'action': message,
      'name': title,
      'meta': meta ?? <String, dynamic>{},
    });
  }
}
