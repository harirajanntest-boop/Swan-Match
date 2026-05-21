import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swam_match_app/firebase_options.dart';

import 'chat_presence_service.dart';

/// Background/terminated handler — must be top-level and registered once in main().
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final activeChatUid = prefs.getString('active_chat_uid') ?? '';
  final senderId = message.data['senderId']?.toString() ??
      message.data['fromUserId']?.toString() ??
      '';
  if (activeChatUid.isNotEmpty && activeChatUid == senderId) {
    return;
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<User?>? _authSubscription;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _messaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _persistToken();
      }
    });

    await _persistToken();

    _messaging.onTokenRefresh.listen((_) async {
      await _persistToken();
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      final senderId = message.data['senderId']?.toString() ??
          message.data['fromUserId']?.toString();
      if (senderId != null &&
          ChatPresenceService.instance.isInChatWith(senderId)) {
        debugPrint('Notification suppressed: user is in chat with $senderId');
        return;
      }

      if (notification != null) {
        _localNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) {});

    await _messaging.getInitialMessage();
  }

  /// Saves the device FCM token on the signed-in user document.
  Future<void> _persistToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? token;
    try {
      token = await _messaging.getToken().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return;
    }
    if (token == null || token.trim().isEmpty) return;

    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes this device's token when signing out (call before [FirebaseAuth.signOut]).
  Future<void> clearTokenForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token for cleanup: $e');
      return;
    }
    if (token == null || token.trim().isEmpty) return;

    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'fcmTokens': FieldValue.arrayRemove([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
