import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _persistToken();

    _messaging.onTokenRefresh.listen((_) async {
      await _persistToken();
    });

    FirebaseMessaging.onMessage.listen((_) {});
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});
    await _messaging.getInitialMessage();
  }

  Future<void> _persistToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;

    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
