import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/error_mapper.dart';
import '../core/storage/secure_storage.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../services/chat_realtime_service.dart';
import '../services/push_notification_service.dart';

// Auth state
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final bool otpRequired;
  final String? otpPhone;
  final bool pinSetupRequired;
  final String? pinSetupPhone;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.otpRequired = false,
    this.otpPhone,
    this.pinSetupRequired = false,
    this.pinSetupPhone,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    bool? otpRequired,
    String? otpPhone,
    bool? pinSetupRequired,
    String? pinSetupPhone,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      otpRequired: otpRequired ?? false,
      otpPhone: otpPhone,
      pinSetupRequired: pinSetupRequired ?? false,
      pinSetupPhone: pinSetupPhone,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo = AuthRepository();

  AuthNotifier() : super(const AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final isLoggedIn = await SecureStorage.isLoggedIn();
    if (isLoggedIn) {
      try {
        final user = await _repo.getProfile();
        if (!user.isPhoneVerified) {
          debugPrint('[Auth] checkAuth: phone not verified → OTP required');
          await SecureStorage.clearAuthSession();
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
        state = AuthState(status: AuthStatus.authenticated, user: user);
        PushNotificationService().initialize().catchError((_) {});
        _connectRealtime(user.id);
      } catch (e) {
        final appError = mapException(e);
        if (appError.isOtpRequired) {
          debugPrint('[Auth] checkAuth: OTP required (code=${appError.code})');
        }
        await SecureStorage.clearAuthSession();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({required String phone, required String pinCode}) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final data = await _repo.login(phone: phone, pinCode: pinCode);
      await SecureStorage.saveLastLoginPhone(phone);
      final tokens = _extractTokens(data);
      await SecureStorage.saveTokens(
        accessToken: tokens.$1,
        refreshToken: tokens.$2,
      );
      final userMap = data['user'] as Map<String, dynamic>? ?? {};
      final role = (userMap['role'] ?? '').toString();
      debugPrint('[Auth] login role from backend: "$role"');
      if (role.isEmpty) {
        debugPrint(
          '[Auth] ⚠️ role is empty — check backend response structure',
        );
      }
      final userId = userMap['id']?.toString() ?? '';
      await SecureStorage.saveUserInfo(
        userId: userId,
        role: role.toLowerCase(),
      );

      final user = UserModel.fromJson(userMap);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      PushNotificationService().initialize().catchError((_) {});
      _connectRealtime(userId);
      return true;
    } catch (e) {
      final appError = mapException(e);
      debugPrint('[Auth] login error: $appError');

      // Détecter OTP requis via le code stable
      if (appError.isOtpRequired) {
        await SecureStorage.saveLastLoginPhone(phone);
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          otpRequired: true,
          otpPhone: phone,
          pinSetupRequired: false,
          pinSetupPhone: null,
        );
        return false;
      }

      if (appError.isPinSetupRequired) {
        await SecureStorage.saveLastLoginPhone(phone);
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          otpRequired: false,
          otpPhone: null,
          pinSetupRequired: true,
          pinSetupPhone: phone,
          error: null,
        );
        return false;
      }

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        otpRequired: false,
        otpPhone: null,
        pinSetupRequired: false,
        pinSetupPhone: null,
        error: appError.userMessage,
      );
      return false;
    }
  }

  Future<bool> registerArtisan({
    required String phone,
    required String pinCode,
    required String firstName,
    required String lastName,
    required String categoryId,
    required String subcategoryId,
    required String city,
    required String commune,
    double? latitude,
    double? longitude,
    String? businessName,
    String? email,
    String? description,
    int? experienceYears,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final data = await _repo.registerArtisan(
        phone: phone,
        pinCode: pinCode,
        firstName: firstName,
        lastName: lastName,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        businessName: businessName,
        city: city,
        commune: commune,
        latitude: latitude,
        longitude: longitude,
        email: email,
        description: description,
        experienceYears: experienceYears,
      );
      final tokens = _extractTokens(data);
      await SecureStorage.saveTokens(
        accessToken: tokens.$1,
        refreshToken: tokens.$2,
      );
      final userMap = data['user'] as Map<String, dynamic>? ?? {};
      final role = (userMap['role'] ?? 'ARTISAN').toString();
      debugPrint('[Auth] registerArtisan role from backend: "$role"');
      final userId = userMap['id']?.toString() ?? '';
      await SecureStorage.saveUserInfo(
        userId: userId,
        role: role.toLowerCase(),
      );

      final user = UserModel.fromJson(userMap);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      PushNotificationService().initialize().catchError((_) {});
      _connectRealtime(userId);
      return true;
    } catch (e) {
      final appError = mapException(e);
      debugPrint('[Auth] registerArtisan error: $appError');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: appError.userMessage,
      );
      return false;
    }
  }

  Future<bool> registerClient({
    required String phone,
    required String pinCode,
    required String firstName,
    required String lastName,
    required String city,
    required String commune,
    double? latitude,
    double? longitude,
    String? email,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final data = await _repo.registerClient(
        phone: phone,
        pinCode: pinCode,
        firstName: firstName,
        lastName: lastName,
        city: city,
        commune: commune,
        latitude: latitude,
        longitude: longitude,
        email: email,
      );
      final tokens = _extractTokens(data);
      await SecureStorage.saveTokens(
        accessToken: tokens.$1,
        refreshToken: tokens.$2,
      );
      final userMap = data['user'] as Map<String, dynamic>? ?? {};
      final role = (userMap['role'] ?? 'CLIENT').toString();
      debugPrint('[Auth] registerClient role from backend: "$role"');
      final userId = userMap['id']?.toString() ?? '';
      await SecureStorage.saveUserInfo(
        userId: userId,
        role: role.toLowerCase(),
      );

      final user = UserModel.fromJson(userMap);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      PushNotificationService().initialize().catchError((_) {});
      _connectRealtime(userId);
      return true;
    } catch (e) {
      final appError = mapException(e);
      debugPrint('[Auth] registerClient error: $appError');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: appError.userMessage,
      );
      return false;
    }
  }

  Future<void> sendOtp(String phone) async {
    await _repo.sendOtp(phone);
  }

  Future<bool> verifyOtp({required String phone, required String code}) async {
    try {
      await _repo.verifyOtp(phone: phone, code: code);
      if (state.user != null) {
        state = state.copyWith(
          user: state.user!.copyWith(isPhoneVerified: true),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setupPin({
    required String phone,
    required String code,
    required String pinCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final data = await _repo.setupPin(
        phone: phone,
        code: code,
        pinCode: pinCode,
      );

      await SecureStorage.saveLastLoginPhone(phone);
      final tokens = _extractTokens(data);
      await SecureStorage.saveTokens(
        accessToken: tokens.$1,
        refreshToken: tokens.$2,
      );

      final userMap = data['user'] as Map<String, dynamic>? ?? {};
      final role = (userMap['role'] ?? '').toString();
      final userId = userMap['id']?.toString() ?? '';
      await SecureStorage.saveUserInfo(
        userId: userId,
        role: role.toLowerCase(),
      );

      final user = UserModel.fromJson(userMap);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      PushNotificationService().initialize().catchError((_) {});
      _connectRealtime(user.id);
      return true;
    } catch (e) {
      final appError = mapException(e);
      debugPrint('[Auth] setupPin error: $appError');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: appError.userMessage,
      );
      return false;
    }
  }

  Future<void> logout() async {
    ChatRealtimeService().disconnect();
    await SecureStorage.clearAuthSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _connectRealtime(String userId) {
    if (userId.isEmpty) return;
    ChatRealtimeService().connect(userId: userId).catchError((_) {});
  }

  /// Extrait access_token et refresh_token depuis la réponse backend (déjà unwrappée).
  (String, String) _extractTokens(Map<String, dynamic> data) {
    final access =
        data['access_token']?.toString() ??
        data['accessToken']?.toString() ??
        '';
    final refresh =
        data['refresh_token']?.toString() ??
        data['refreshToken']?.toString() ??
        '';
    if (access.isEmpty) {
      debugPrint('[Auth] ⚠️ access_token is empty in response: ${data.keys}');
    }
    return (access, refresh);
  }
}
