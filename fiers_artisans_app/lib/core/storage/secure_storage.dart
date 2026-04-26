import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/constants.dart';
import 'web_local_storage_stub.dart'
    if (dart.library.js_interop) 'web_local_storage_web.dart'
    as web_storage;

class SecureStorage {
    static bool _looksLikePhone(String? value) {
      final normalized = value?.trim() ?? '';
      if (normalized.isEmpty) return false;
      return RegExp(r'^\+?[0-9]{6,20}$').hasMatch(normalized);
    }

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Tokens
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _storage.write(
        key: AppConstants.keyAccessToken,
        value: accessToken,
      );
      await _storage.write(
        key: AppConstants.keyRefreshToken,
        value: refreshToken,
      );
    } catch (_) {}

    await web_storage.writeWebLocalStorage(
      AppConstants.keyAccessToken,
      accessToken,
    );
    await web_storage.writeWebLocalStorage(
      AppConstants.keyRefreshToken,
      refreshToken,
    );
  }

  static Future<String?> getAccessToken() async {
    try {
      final value = await _storage.read(key: AppConstants.keyAccessToken);
      if ((value ?? '').isNotEmpty) return value;
    } catch (_) {}
    return web_storage.readWebLocalStorage(AppConstants.keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    try {
      final value = await _storage.read(key: AppConstants.keyRefreshToken);
      if ((value ?? '').isNotEmpty) return value;
    } catch (_) {}
    return web_storage.readWebLocalStorage(AppConstants.keyRefreshToken);
  }

  // User info
  static Future<void> saveUserInfo({
    required String userId,
    required String role,
  }) async {
    try {
      await _storage.write(key: AppConstants.keyUserId, value: userId);
      await _storage.write(key: AppConstants.keyUserRole, value: role);
    } catch (_) {}

    await web_storage.writeWebLocalStorage(AppConstants.keyUserId, userId);
    await web_storage.writeWebLocalStorage(AppConstants.keyUserRole, role);
  }

  static Future<String?> getUserId() async {
    try {
      final value = await _storage.read(key: AppConstants.keyUserId);
      if ((value ?? '').isNotEmpty) return value;
    } catch (_) {}
    return web_storage.readWebLocalStorage(AppConstants.keyUserId);
  }

  static Future<String?> getUserRole() async {
    try {
      final value = await _storage.read(key: AppConstants.keyUserRole);
      if ((value ?? '').isNotEmpty) return value;
    } catch (_) {}
    return web_storage.readWebLocalStorage(AppConstants.keyUserRole);
  }

  // Login identifier (phone only, no password)
  static Future<void> saveLastLoginPhone(String phone) async {
    final normalized = phone.replaceAll(' ', '').trim();
    if (normalized.isEmpty) return;

    if (kIsWeb) {
      await web_storage.writeWebLocalStorage(
        AppConstants.keyLastLoginPhone,
        normalized,
      );
      return;
    }

    try {
      await _storage.write(
        key: AppConstants.keyLastLoginPhone,
        value: normalized,
      );
    } catch (_) {}

    await web_storage.writeWebLocalStorage(
      AppConstants.keyLastLoginPhone,
      normalized,
    );
  }

  static Future<String?> getLastLoginPhone() async {
    if (kIsWeb) {
      final webValue =
          web_storage.readWebLocalStorage(AppConstants.keyLastLoginPhone);
      if (_looksLikePhone(webValue)) {
        return webValue!.trim();
      }
      return null;
    }

    String? secureValue;
    try {
      secureValue = await _storage.read(key: AppConstants.keyLastLoginPhone);
    } catch (_) {}

    if (_looksLikePhone(secureValue)) {
      return secureValue!.trim();
    }

    final webValue =
        web_storage.readWebLocalStorage(AppConstants.keyLastLoginPhone);
    if (_looksLikePhone(webValue)) {
      return webValue!.trim();
    }

    return null;
  }

  static Future<void> clearAuthSession({bool preserveLastPhone = true}) async {
    final keys = <String>[
      AppConstants.keyAccessToken,
      AppConstants.keyRefreshToken,
      AppConstants.keyUserId,
      AppConstants.keyUserRole,
      if (!preserveLastPhone) AppConstants.keyLastLoginPhone,
    ];

    try {
      for (final key in keys) {
        await _storage.delete(key: key);
      }
    } catch (_) {}

    for (final key in keys) {
      await web_storage.deleteWebLocalStorage(key);
    }
  }

  // Clear all
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    await web_storage.clearWebLocalStorage();
  }

  // Check if logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
