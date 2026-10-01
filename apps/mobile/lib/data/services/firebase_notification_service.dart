import 'dart:async';
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

  FirebaseMessaging? get _firebaseMessaging {
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  final ProfileService _profileService = ProfileService();

  static Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

      final instance = FirebaseNotificationService();
      await instance._requestPermission();
      await instance._setupToken();
      instance._setupMessageListeners();
    } catch (e) {
      debugPrint("FirebaseNotificationService initialization error: $e");
    }
  }

  Future<void> _requestPermission() async {
    final fm = _firebaseMessaging;
    if (fm == null) return;
    NotificationSettings settings = await fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('User notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _setupToken() async {
    try {
      final fm = _firebaseMessaging;
      if (fm == null) return;
      String? token = await fm.getToken();
      if (token != null) {
        debugPrint("FCM Device Token: $token");
        await syncTokenToProfile(token);
      }

      // Listen for token refresh
      fm.onTokenRefresh.listen((newToken) async {
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
      final fm = _firebaseMessaging;
      final token = explicitToken ?? (fm != null ? await fm.getToken() : null);
      if (token != null && token.isNotEmpty) {
        await _profileService.updateFcmToken(uid, token);
      }
    } catch (e) {
      debugPrint("Error syncing FCM token to Supabase: $e");
    }
  }

  // Stream controller for broadcasting in-app notifications
  static final StreamController<Map<String, String>> _notificationStreamController =
      StreamController<Map<String, String>>.broadcast();
  static Stream<Map<String, String>> get onNotificationReceived =>
      _notificationStreamController.stream;

  static void emitInAppNotification({required String title, required String body, String? payload}) {
    _notificationStreamController.add({
      'title': title,
      'body': body,
      'payload': payload ?? '',
    });
  }

  void _setupMessageListeners() {
    // Foreground message handler
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground notification: ${message.notification?.title} - ${message.notification?.body}');
        final title = message.notification?.title ?? "Notifikasi Mpus";
        final body = message.notification?.body ?? "";
        emitInAppNotification(title: title, body: body, payload: message.data['otp']?.toString());
      });

      // When app is opened from a notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification clicked with payload: ${message.data}');
      });
    } catch (_) {}
  }
}
