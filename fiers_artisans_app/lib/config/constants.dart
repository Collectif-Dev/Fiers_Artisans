class AppConstants {
  AppConstants._();

  // Storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyLastLoginPhone = 'last_login_phone';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLocale = 'locale';
  static const String keyOnboardingCompleted = 'onboarding_completed';

  // User roles
  static const String roleArtisan = 'artisan';
  static const String roleClient = 'client';
  static const String roleAdmin = 'admin';

  // Verification status
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  // Subscription status
  static const String subActive = 'active';
  static const String subExpired = 'expired';
  static const String subPending = 'pending';

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animSplash = Duration(milliseconds: 800);

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusRound = 100.0;
}
