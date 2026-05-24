import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupportService {
  SupportService._();

  static final SupportService instance = SupportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> submitSupportQuery({
    required String userName,
    required String userEmail,
    required String subject,
    required String message,
    required Map<String, dynamic> deviceInfo,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Must be signed in to submit a support query.');
    }

    await _firestore.collection('support_queries').add({
      'userId': currentUser.uid,
      'userName': userName,
      'userEmail': userEmail,
      'subject': subject,
      'message': message,
      'deviceInfo': deviceInfo,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
