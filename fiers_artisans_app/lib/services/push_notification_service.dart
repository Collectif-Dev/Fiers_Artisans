import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final ApiClient _api = ApiClient();
  bool _initialized = false;
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
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Already initialized or no google-services.json — skip
    }

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS)
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

    // Get token and register with backend
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

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

  void _handleForegroundMessage(RemoteMessage message) {
    if (!_isAppInForeground) {
      return;
    }
    debugPrint('FCM foreground: ${message.notification?.title}');
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
}
