import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

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

  FirebaseAnalytics? _analytics;
  FirebaseAnalytics? get analytics => _analytics;

  Future<void> init() async {
    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();
      _isInitialized = true;
      debugPrint('[FirebaseService] Firebase initialized successfully');

      // 2. Setup Firebase Analytics
      await _setupAnalytics();

      // 3. Setup Cloud Messaging (FCM)
      await _setupMessaging();
    } catch (e) {
      debugPrint('[FirebaseService] Initialization notice: $e');
      // Non-blocking: App proceeds even if Firebase is unavailable offline
    }
  }

  Future<void> _setupAnalytics() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics?.setAnalyticsCollectionEnabled(true);
      await _analytics?.logAppOpen();
      debugPrint('[Analytics] Firebase Analytics active & AppOpen logged');
    } catch (e) {
      debugPrint('[Analytics] Setup notice: $e');
    }
  }

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics?.logScreenView(screenName: screenName);
    } catch (_) {}
  }

  Future<void> logMovieView({required String title, required String id, String? category}) async {
    try {
      await _analytics?.logEvent(
        name: 'movie_view',
        parameters: {
          'movie_title': title,
          'movie_id': id,
          'category': category ?? 'general',
        },
      );
    } catch (_) {}
  }

  Future<void> logStreamStart({required String title, required String server}) async {
    try {
      await _analytics?.logEvent(
        name: 'stream_start',
        parameters: {
          'movie_title': title,
          'server_name': server,
        },
      );
    } catch (_) {}
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
