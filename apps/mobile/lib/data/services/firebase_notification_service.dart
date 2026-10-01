import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/config/supabase_config.dart';
import 'profile_service.dart';

// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ProfileService _profileService = ProfileService();

  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final instance = FirebaseNotificationService();
      await instance._requestPermission();
      await instance._setupToken();
      instance._setupMessageListeners();
    } catch (e) {
      debugPrint("FirebaseNotificationService initialization error: $e");
    }
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('User notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _setupToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint("FCM Device Token: $token");
        await syncTokenToProfile(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        debugPrint("FCM Token refreshed: $newToken");
        await syncTokenToProfile(newToken);
      });
    } catch (e) {
      debugPrint("Error fetching FCM token: $e");
    }
  }

  Future<void> syncTokenToProfile([String? explicitToken]) async {
    final uid = SupabaseConfig.currentUserId;
    if (uid == null) return;

    try {
      final token = explicitToken ?? await _firebaseMessaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _profileService.updateFcmToken(uid, token);
      }
    } catch (e) {
      debugPrint("Error syncing FCM token to Supabase: $e");
    }
  }

  void _setupMessageListeners() {
    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground notification: ${message.notification?.title} - ${message.notification?.body}');
    });

    // When app is opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked with payload: ${message.data}');
    });
  }
}
