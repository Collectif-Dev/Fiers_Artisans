class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String registerArtisan = '/auth/register/artisan';
  static const String registerClient = '/auth/register/client';
  static const String refreshToken = '/auth/refresh';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String setupPin = '/auth/setup-pin';

  // Profiles
  static const String artisanProfile = '/artisan/profile';
  static const String artisanStats = '/artisan/stats';
  static const String clientProfile = '/client/profile';
  static String artisanById(String id) => '/artisan/$id';
  static const String clientFavorites = '/client/favorites';
  static String clientFavoriteByArtisanUser(String artisanUserId) =>
      '/client/favorites/$artisanUserId';
  static String clientFavoriteStatus(String artisanUserId) =>
      '/client/favorites/$artisanUserId/status';

  // Categories
  static const String categories = '/categories';
  static String categoryBySlug(String slug) => '/categories/$slug';

  // Search
  static const String search = '/search/artisans';

  // Reviews
  static const String reviews = '/reviews';
  static String reviewReply(String reviewId) => '/reviews/$reviewId/reply';
  static String reviewsByArtisan(String artisanId) =>
      '/artisan/$artisanId/reviews';

  // Portfolio
  static const String portfolio = '/portfolio';
  static String portfolioByArtisan(String artisanId) =>
      '/artisan/$artisanId/portfolio';

  // Subscription
  static const String subscriptionInitiate = '/subscription/initiate';
  static const String subscriptionStatus = '/subscription/status';

  // Verification
  static const String verificationSubmit = '/verification/submit';
  static const String verificationStatus = '/verification/status';

  // Chat
  static const String conversations = '/chat/conversations';
  static String messages(String conversationId) =>
      '/chat/conversations/$conversationId/messages';
  static String conversationRead(String conversationId) =>
      '/chat/conversations/$conversationId/read';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';

  // Media
  static const String upload = '/media/upload';

  // Analytics
  static const String analyticsLog = '/analytics/log';

  // Users
  static const String updateFcmToken = '/users/fcm-token';
  static const String updateUserLocation = '/users/location';

  // Health
  static const String health = '/health';
}
