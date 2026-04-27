import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_presence_service.dart';

// ─── Background/Terminated message handler ──────────────────────────────────
// NOTE: FCM 'notification' messages are shown automatically by the OS when
// the app is in background/terminated. To suppress them for an active chat
// screen the server should send DATA-ONLY messages. This handler fires for
// data-only background messages and checks SharedPreferences to decide
// whether to show a local notification.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only suppress if the app was foregrounded in that chat (stored in prefs).
  final prefs = await SharedPreferences.getInstance();
  final activeChatUid = prefs.getString('active_chat_uid') ?? '';
  final senderId = message.data['senderId']?.toString() ??
      message.data['fromUserId']?.toString() ?? '';
  if (activeChatUid.isNotEmpty && activeChatUid == senderId) {
    // User was actively in this chat — skip local notification.
    return;
  }
  // For data-only messages: show a local notification manually.
  // For regular notification messages the OS shows them automatically.
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

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    // Required to display a heads up notification in the foreground on iOS
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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle foreground notification tap
      },
    );

    // Create an Android Notification Channel for heads up notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _persistToken();

    _messaging.onTokenRefresh.listen((_) async {
      await _persistToken();
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      // Suppress chat message notifications if user is already in that chat
      final senderId = message.data['senderId']?.toString() ??
                      message.data['fromUserId']?.toString();
      if (senderId != null && ChatPresenceService.instance.isInChatWith(senderId)) {
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

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handles notification tap when app is in the background
    });

    // Handles notification tap when app is terminated
    await _messaging.getInitialMessage();
  }

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
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
