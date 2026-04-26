import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _UnwrapInterceptor(),
      if (kDebugMode) _LoggingInterceptor(),
    ]);
  }

  factory ApiClient() {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  // GET
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.get(path, queryParameters: queryParameters, options: options);

  // POST
  Future<Response> post(String path, {dynamic data, Options? options}) =>
      _dio.post(path, data: data, options: options);

  // PUT
  Future<Response> put(String path, {dynamic data, Options? options}) =>
      _dio.put(path, data: data, options: options);

  // PATCH
  Future<Response> patch(String path, {dynamic data, Options? options}) =>
      _dio.patch(path, data: data, options: options);

  // DELETE
  Future<Response> delete(String path, {dynamic data, Options? options}) =>
      _dio.delete(path, data: data, options: options);

  // Upload file
  Future<Response> uploadFile(
    String filePath, {
    String field = 'file',
    Map<String, dynamic>? extraFields,
  }) async {
    final formData = FormData.fromMap({
      field: await MultipartFile.fromFile(filePath),
      if (extraFields != null) ...extraFields,
    });
    return _dio.post(ApiEndpoints.upload, data: formData);
  }
}

// ──────────── Unwrap Backend Envelope ────────────
// Le backend encapsule toutes les réponses dans {statusCode, data, timestamp}.
// Cet intercepteur extrait response.data['data'] pour que les repositories
// lisent directement le payload métier.
class _UnwrapInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map<String, dynamic> &&
        body.containsKey('data') &&
        body.containsKey('statusCode') &&
        body.containsKey('timestamp')) {
      response.data = body['data'];
    }
    handler.next(response);
  }
}

// ──────────── Auth Interceptor ────────────
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try refresh token
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry original request
        final opts = err.requestOptions;
        final token = await SecureStorage.getAccessToken();
        opts.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await Dio().fetch(opts);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      }
    }
    handler.next(err);
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio(
        BaseOptions(baseUrl: AppConfig.apiBaseUrl),
      ).post(ApiEndpoints.refreshToken, data: {'refresh_token': refreshToken});

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Unwrap l'enveloppe backend {statusCode, data, timestamp}
        var data = response.data;
        if (data is Map<String, dynamic> &&
            data.containsKey('data') &&
            data.containsKey('statusCode')) {
          data = data['data'];
        }
        await SecureStorage.saveTokens(
          accessToken: data['access_token'] ?? data['accessToken'] ?? '',
          refreshToken: data['refresh_token'] ?? data['refreshToken'] ?? '',
        );
        return true;
      }
    } catch (_) {
      await SecureStorage.clearAuthSession();
    }
    return false;
  }
}

// ──────────── Logging Interceptor (Debug only) ────────────
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('✗ ${err.response?.statusCode} ${err.requestOptions.uri}');
    handler.next(err);
  }
}
