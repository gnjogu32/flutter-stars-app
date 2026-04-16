import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

// Top-level handler required by FCM for background/terminated messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '[FCM background] ${message.notification?.title}: '
    '${message.notification?.body}',
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'starpage_notifications';
  static const _channelName = 'Starpage Notifications';
  static const _channelDesc = 'Likes, comments, follows and messages.';

  static final AndroidNotificationChannel _channel =
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
      );

  /// Call once after Firebase.initializeApp()
  static Future<void> initialize({
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    // 1️⃣ Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2️⃣ Create Android high-importance channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // 3️⃣ Init flutter_local_notifications (used for foreground display)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings: initSettings);

    // 4️⃣ Request permission (Android 13+, iOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5️⃣ Force on-screen notifications while app is foregrounded
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // 6️⃣ Handle foreground messages manually with local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: _payloadFromMessage(message),
        );
      }
    });

    // 7️⃣ Notification tapped while app was in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationPayload(_payloadFromMessage(message), navigatorKey);
    });

    // 8️⃣ Notification tapped from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationPayload(
        _payloadFromMessage(initialMessage),
        navigatorKey,
      );
    }

    // 9️⃣ Persist FCM token for the current user
    await _saveFcmToken();

    // Token may refresh — keep Firestore up to date
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _persistToken(token);
    });
  }

  // ─── helpers ────────────────────────────────────────────────────────────

  static String? _payloadFromMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != null) {
      return '${data['type']};${data['postId'] ?? ''};${data['senderId'] ?? ''}';
    }
    return null;
  }

  static void _handleNotificationPayload(
    String? payload,
    GlobalKey<NavigatorState>? navigatorKey,
  ) {
    if (payload == null || navigatorKey == null) return;
    final parts = payload.split(';');
    final type = parts.isNotEmpty ? parts[0] : '';
    // Navigate to notifications tab (index 4)
    if (type == 'follow' ||
        type == 'like_post' ||
        type == 'comment' ||
        type == 'mention_followers') {
      navigatorKey.currentState?.pushNamed('/notifications');
    }
    // DM — navigate to messages tab
    if (type == 'message') {
      navigatorKey.currentState?.pushNamed('/messages');
    }
  }

  static Future<void> _saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _persistToken(token);
  }

  /// Call after login/signup to ensure the current user's token is stored.
  static Future<void> syncTokenForCurrentUser() async {
    await _saveFcmToken();
  }

  static Future<void> _persistToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': token, 'fcmTokenUpdatedAt': DateTime.now()},
      );
    } catch (e) {
      debugPrint('[FCM] token persist failed: $e');
    }
  }

  /// Call when a user logs out to clear the token so they stop receiving
  /// notifications for the signed-out account.
  static Future<void> clearToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': FieldValue.delete()},
      );
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[FCM] clearToken failed: $e');
    }
  }
}
