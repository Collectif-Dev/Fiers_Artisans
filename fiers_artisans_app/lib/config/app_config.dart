import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration centralisée — les valeurs réseau sont lues depuis .env
///
/// Pour changer l'IP du backend :
///   1. Ouvrir fiers_artisans_app/.env
///   2. Modifier API_HOST=votre_nouvelle_ip
///   3. Hot restart (R) ou relancer l'app
///
/// Variables .env disponibles :
///   API_HOST        (source de vérité, recommandé)
///   API_HOST_WEB    (optionnel, fallback web)
///   API_HOST_MOBILE (optionnel, fallback mobile)
///   API_PORT       (défaut: 3000)
///   API_SCHEME     (défaut: http)
///   WS_SCHEME      (défaut: ws)
///   API_BASE_PATH  (défaut: /api/v1)
class AppConfig {
  static const String appName = 'Fiers Artisans';
  static const String appVersion = '1.0.0';

  // ── Réseau (lues depuis .env avec fallback sûr) ────────────────────
  static String get _apiHost {
    if (kIsWeb) {
      final webHost = _firstNonEmpty([dotenv.env['API_HOST_WEB']]);
      if (webHost != null) {
        return webHost;
      }

      final browserHost = Uri.base.host.trim();
      if (browserHost.isNotEmpty) {
        return browserHost;
      }

      final sharedHost = _firstNonEmpty([dotenv.env['API_HOST']]);
      if (sharedHost != null) {
        return sharedHost;
      }

      return 'localhost';
    }

    final sharedHost = _firstNonEmpty([dotenv.env['API_HOST']]);
    if (sharedHost != null) {
      return sharedHost;
    }

    return _firstNonEmpty([dotenv.env['API_HOST_MOBILE']]) ?? '10.0.2.2';
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static String get _apiPort => dotenv.env['API_PORT'] ?? '3000';
  static String get _apiScheme => dotenv.env['API_SCHEME'] ?? 'http';
  static String get _wsScheme => dotenv.env['WS_SCHEME'] ?? 'ws';
  static String get _apiBasePath => dotenv.env['API_BASE_PATH'] ?? '/api/v1';

  static String get apiBaseUrl => '$_apiScheme://$_apiHost:$_apiPort$_apiBasePath';
  static String get wsBaseUrl => '$_wsScheme://$_apiHost:$_apiPort';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // OTP
  static const int otpLength = 6;
  static const int otpResendDelay = 60; // seconds

  // Search
  static const double defaultSearchRadius = 10.0; // km
  static const double maxSearchRadius = 50.0; // km

  // Pagination
  static const int defaultPageSize = 20;

  // Subscription
  static const int subscriptionAmountFCFA = 5000;

  // Cache
  static const Duration imageCacheDuration = Duration(days: 7);

  // Côte d'Ivoire phone prefix
  static const String phonePrefix = '+225';
}
