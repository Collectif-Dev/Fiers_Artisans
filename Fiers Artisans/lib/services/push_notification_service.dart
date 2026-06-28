import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class PushNotificationService {
  static const String _notificationChannelId =
      'fiers_artisans_high_importance';
  static const String _notificationChannelName = 'Fiers Artisans';
  static const String _notificationChannelDescription = 'Alertes importantes';

  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final ApiClient _api = ApiClient();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  bool _isAppInForeground = true;

  /// Callback invoked when a verification-related push arrives.
  VoidCallback? onVerificationUpdate;
  VoidCallback? onReviewUpdate;
  VoidCallback? onSubscriptionUpdate;
  VoidCallback? onNotificationTapped;

  void setAppInForeground(bool inForeground) {
    _isAppInForeground = inForeground;
  }

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Already initialized or no google-services.json — skip
    }

    final messaging = FirebaseMessaging.instance;

    if (!_initialized) {
      // Request permission (iOS and Android 13+).
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM: User denied push permissions');
        return;
      }

      // Foreground: keep UX in-app only, avoid duplicated system banners.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      await _ensureLocalNotificationsInitialized();

      // Listen for token refresh
      messaging.onTokenRefresh.listen(_registerToken);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Open app from push tap (background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      _initialized = true;
    }

    // Always resync token after auth changes (same app process, different user).
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!_isAppInForeground) {
      return;
    }
    debugPrint('FCM foreground: ${message.notification?.title}');
    unawaited(_showForegroundAndroidNotification(message));
    final type = message.data['type'] as String?;
    if (type == 'DOCUMENT_APPROVED' || type == 'DOCUMENT_REJECTED') {
      onVerificationUpdate?.call();
      return;
    }

    if (type == 'REVIEW_UPDATED' ||
        type == 'REVIEW_CREATED' ||
        type == 'REVIEW_DELETED') {
      onReviewUpdate?.call();
      return;
    }

    if (type == 'SUBSCRIPTION_UPDATED' || type == 'PAYMENT_UPDATED') {
      onSubscriptionUpdate?.call();
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    onNotificationTapped?.call();
  }

  Future<void> _registerToken(String token) async {
    try {
      await _api.put(ApiEndpoints.updateFcmToken, data: {'fcmToken': token});
      debugPrint('FCM token registered');
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> unregisterCurrentUserToken() async {
    try {
      await _api.put(ApiEndpoints.updateFcmToken, data: {'fcmToken': ''});
      debugPrint('FCM token unregistered for current user');
    } catch (e) {
      debugPrint('FCM token unregister failed: $e');
    }
  }

  Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iOSSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) {
        onNotificationTapped?.call();
      },
    );

    const channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: _notificationChannelDescription,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _localNotificationsInitialized = true;
  }

  Future<void> _showForegroundAndroidNotification(RemoteMessage message) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final title = message.notification?.title;
    final body = message.notification?.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    try {
      await _ensureLocalNotificationsInitialized();
      await _localNotifications.show(
        message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title ?? 'Fiers Artisans',
        body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _notificationChannelId,
            _notificationChannelName,
            channelDescription: _notificationChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: message.data['type']?.toString(),
      );
    } catch (e) {
      debugPrint('FCM foreground local notification failed: $e');
    }
  }
}
