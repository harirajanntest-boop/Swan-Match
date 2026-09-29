import 'dart:io' show Platform;
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
import 'security_monitoring_service.dart';

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
        // Trigger secure background session tracking upon login/app start
        unawaited(SecurityMonitoringService.instance.logSessionActivity('app_start'));
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

      // iOS already shows the push itself while the app is open (see the
      // presentation options above); a local copy would show it twice.
      if (notification != null && !Platform.isIOS) {
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
    token = token.trim();

    final users = _firestore.collection('users').doc(user.uid);

    // Remove this device's PREVIOUS token (e.g. after a token refresh) before
    // adding the new one, so the user's fcmTokens array never accumulates
    // multiple tokens for the same device — that accumulation is what makes the
    // backend send (and the device receive) duplicate push notifications.
    //
    // update() (never set/merge): this runs the instant a new account signs
    // in, BEFORE signup has written the profile. A merge-set would create a
    // stub users/{uid} doc, turning the signup profile write into an update
    // that firestore.rules rejects (permission-denied), and making brand-new
    // Google/Apple users look like existing ones. If the profile doesn't
    // exist yet, skip — signup calls syncTokenForCurrentUser() once it does.
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString('fcm_token_local');
    try {
      if (previous != null && previous.isNotEmpty && previous != token) {
        await users.update(<String, dynamic>{
          'fcmTokens': FieldValue.arrayRemove([previous]),
        });
      }

      await users.update(<String, dynamic>{
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      rethrow;
    }

    await prefs.setString('fcm_token_local', token);
  }

  /// Saves this device's FCM token to the current user's profile. Call right
  /// after a new profile document is created (the auth-state listener skips
  /// users whose profile doesn't exist yet).
  Future<void> syncTokenForCurrentUser() async {
    try {
      await _persistToken();
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  /// Removes this device's token when signing out (call before [FirebaseAuth.signOut]).
  Future<void> clearTokenForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      // Still clear the legacy field below even if the token can't be read.
      debugPrint('Error getting FCM token for cleanup: $e');
    }
    token = token?.trim();

    try {
      // update(), not merge-set: never create a profile doc on sign-out.
      await _firestore.collection('users').doc(user.uid).update(<String, dynamic>{
        if (token != null && token.isNotEmpty)
          'fcmTokens': FieldValue.arrayRemove([token]),
        // The single legacy `fcmToken` field is also read by the push
        // functions. Leaving it after sign-out sent this account's pushes
        // (chat text included) to the next person signed in on this phone.
        // Other devices stay reachable through the fcmTokens array.
        'fcmToken': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
    // Forget the locally cached token so the next account on this phone
    // doesn't try to remove it from its own profile.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token_local');
    } catch (_) {}
  }
}
