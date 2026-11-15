import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('[FCM] Background push notification received: ${message.messageId}');
  } catch (e) {
    debugPrint('[FCM] Background message error: $e');
  }
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  FirebaseMessaging? _messaging;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();
      _isInitialized = true;
      debugPrint('[FirebaseService] Firebase initialized successfully');

      // 2. Setup Cloud Messaging (FCM)
      await _setupMessaging();
    } catch (e) {
      debugPrint('[FirebaseService] Initialization notice: $e');
      // Non-blocking: App proceeds even if Firebase is unavailable offline
    }
  }

  Future<void> _setupMessaging() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permission (Android 13+ & iOS)
      final settings = await _messaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Permission granted: ${settings?.authorizationStatus}');

      // Subscribe to global topics for instant broadcast updates
      await _messaging?.subscribeToTopic('all_users');
      await _messaging?.subscribeToTopic('updates');
      await _messaging?.subscribeToTopic('new_movies');

      // Handle notifications when the app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground notification received: ${message.notification?.title}');
      });

      // Handle user tapping on notification to open app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification opened: ${message.data}');
      });

      // Get device registration token
      // ignore: deprecated_member_use
      _fcmToken = await _messaging?.getToken();
      debugPrint('[FCM] Registered Device Token: $_fcmToken');
    } catch (e) {
      debugPrint('[FCM] Messaging setup notice: $e');
    }
  }
}
