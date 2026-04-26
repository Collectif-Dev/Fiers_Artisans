import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'app_error.dart';

/// Mapping des codes métier backend → [AppErrorCode].
const _serverCodeMap = <String, AppErrorCode>{
  'AUTH_INVALID_CREDENTIALS': AppErrorCode.authInvalidCredentials,
  'AUTH_ACCOUNT_DISABLED': AppErrorCode.authAccountDisabled,
  'AUTH_OTP_REQUIRED': AppErrorCode.authOtpRequired,
  'AUTH_PIN_SETUP_REQUIRED': AppErrorCode.authPinSetupRequired,
  'AUTH_PIN_BLOCKED': AppErrorCode.authPinBlocked,
  'AUTH_INVALID_TOKEN': AppErrorCode.authInvalidToken,
  'AUTH_PHONE_ALREADY_USED': AppErrorCode.authPhoneAlreadyUsed,
  'INTERNAL_ERROR': AppErrorCode.internalError,
};

/// Mapping HTTP status → code par défaut (quand le backend ne fournit pas de `code`).
AppErrorCode _fallbackCodeFromStatus(int? status) {
  switch (status) {
    case 400:
      return AppErrorCode.validationError;
    case 401:
      return AppErrorCode.authInvalidCredentials;
    case 403:
      return AppErrorCode.forbidden;
    case 404:
      return AppErrorCode.notFound;
    case 409:
      return AppErrorCode.conflict;
    case 500:
      return AppErrorCode.serverError;
    default:
      return AppErrorCode.serverError;
  }
}

/// Messages utilisateur par défaut pour chaque code.
String _defaultUserMessage(AppErrorCode code) {
  switch (code) {
    // Réseau
    case AppErrorCode.networkUnreachable:
      return 'Réseau inaccessible. Vérifiez votre connexion Wi-Fi ou données mobiles.';
    case AppErrorCode.dnsLookupFailed:
      return 'Impossible de résoudre l\'adresse du serveur. Vérifiez votre connexion internet.';
    case AppErrorCode.connectionRefused:
      return 'Le serveur est injoignable. Veuillez réessayer dans quelques instants.';
    case AppErrorCode.connectTimeout:
    case AppErrorCode.sendTimeout:
      return 'Le serveur met trop de temps à répondre. Réessayez.';
    case AppErrorCode.receiveTimeout:
      return 'La réponse du serveur est trop lente. Réessayez.';
    case AppErrorCode.tlsHandshakeFailed:
      return 'Erreur de sécurité de la connexion. Contactez le support si le problème persiste.';
    case AppErrorCode.cleartextNotPermitted:
      return 'Connexion non sécurisée bloquée par l\'appareil.';
    case AppErrorCode.requestCancelled:
      return 'Requête annulée.';
    case AppErrorCode.unknownNetworkError:
      return 'Impossible de joindre le serveur. Vérifiez votre connexion réseau.';

    // Auth
    case AppErrorCode.authInvalidCredentials:
      return 'Numero de telephone ou code PIN incorrect.';
    case AppErrorCode.authAccountDisabled:
      return 'Ce compte a été désactivé.';
    case AppErrorCode.authOtpRequired:
      return 'Vérification du téléphone requise.';
    case AppErrorCode.authPinSetupRequired:
      return 'Veuillez configurer votre code PIN pour terminer la migration de votre compte.';
    case AppErrorCode.authPinBlocked:
      return 'Trop de tentatives PIN. Réessayez plus tard.';
    case AppErrorCode.authInvalidToken:
      return 'Session expirée. Veuillez vous reconnecter.';
    case AppErrorCode.authPhoneAlreadyUsed:
      return 'Ce numéro de téléphone est déjà utilisé.';

    // Validation / serveur
    case AppErrorCode.validationError:
      return 'Données invalides. Vérifiez les champs.';
    case AppErrorCode.serverError:
    case AppErrorCode.internalError:
      return 'Erreur interne du serveur. Réessayez plus tard.';
    case AppErrorCode.notFound:
      return 'Ressource introuvable.';
    case AppErrorCode.forbidden:
      return 'Accès refusé.';
    case AppErrorCode.conflict:
      return 'Conflit : cette ressource existe déjà.';
    case AppErrorCode.unknown:
      return 'Une erreur est survenue.';
  }
}

/// Convertit n'importe quelle exception en [AppError].
///
/// Doit être utilisé comme point d'entrée unique de mapping d'erreur.
AppError mapException(dynamic e) {
  if (e is AppError) return e;

  if (e is DioException) {
    return _mapDioException(e);
  }

  return AppError(
    code: AppErrorCode.unknown,
    source: AppErrorSource.local,
    userMessage: _defaultUserMessage(AppErrorCode.unknown),
    debugMessage: e.toString(),
  );
}

/// Mapping spécialisé Dio.
AppError _mapDioException(DioException e) {
  _logDioError(e);

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
      return AppError(
        code: AppErrorCode.connectTimeout,
        source: AppErrorSource.network,
        userMessage: _defaultUserMessage(AppErrorCode.connectTimeout),
        debugMessage: '${e.type} → ${e.message}',
      );

    case DioExceptionType.receiveTimeout:
      return AppError(
        code: AppErrorCode.receiveTimeout,
        source: AppErrorSource.network,
        userMessage: _defaultUserMessage(AppErrorCode.receiveTimeout),
        debugMessage: '${e.type} → ${e.message}',
      );

    case DioExceptionType.connectionError:
      return _mapConnectionError(e);

    case DioExceptionType.badResponse:
      return _mapBadResponse(e);

    case DioExceptionType.cancel:
      return AppError(
        code: AppErrorCode.requestCancelled,
        source: AppErrorSource.network,
        userMessage: _defaultUserMessage(AppErrorCode.requestCancelled),
        debugMessage: e.message,
      );

    case DioExceptionType.badCertificate:
      return AppError(
        code: AppErrorCode.tlsHandshakeFailed,
        source: AppErrorSource.network,
        userMessage: _defaultUserMessage(AppErrorCode.tlsHandshakeFailed),
        debugMessage: e.message,
      );

    case DioExceptionType.unknown:
      return _mapUnknownDioError(e);
  }
}

/// Analyse fine des erreurs de connexion (DNS, réseau, refus, TLS, cleartext).
AppError _mapConnectionError(DioException e) {
  final inner = e.error;
  final msg = inner?.toString() ?? '';

  if (inner is SocketException) {
    final osMsg = inner.osError?.message ?? '';
    if (osMsg.contains('Network is unreachable') ||
        msg.contains('Network is unreachable')) {
      return _networkError(AppErrorCode.networkUnreachable, e);
    }
    if (osMsg.contains('Connection refused') ||
        msg.contains('Connection refused') ||
        msg.contains('ECONNREFUSED')) {
      return _networkError(AppErrorCode.connectionRefused, e);
    }
    if (osMsg.contains('Connection timed out')) {
      return _networkError(AppErrorCode.connectTimeout, e);
    }
  }

  if (msg.contains('Failed host lookup') || msg.contains('getaddrinfo')) {
    return _networkError(AppErrorCode.dnsLookupFailed, e);
  }
  if (msg.contains('Connection refused') || msg.contains('ECONNREFUSED')) {
    return _networkError(AppErrorCode.connectionRefused, e);
  }
  if (msg.contains('Network is unreachable')) {
    return _networkError(AppErrorCode.networkUnreachable, e);
  }
  if (msg.contains('Cleartext HTTP traffic not permitted') ||
      msg.contains('CLEARTEXT')) {
    return _networkError(AppErrorCode.cleartextNotPermitted, e);
  }
  if (inner is HandshakeException ||
      inner is TlsException ||
      msg.contains('HandshakeException') ||
      msg.contains('CERTIFICATE_VERIFY_FAILED')) {
    return _networkError(AppErrorCode.tlsHandshakeFailed, e);
  }

  return _networkError(AppErrorCode.unknownNetworkError, e);
}

/// Mapping des réponses HTTP d'erreur (4xx, 5xx).
AppError _mapBadResponse(DioException e) {
  final statusCode = e.response?.statusCode;
  var data = e.response?.data;

  // Unwrap enveloppe backend {statusCode, data, timestamp} si présente
  if (data is Map<String, dynamic> &&
      data.containsKey('data') &&
      data.containsKey('statusCode') &&
      data.containsKey('timestamp')) {
    data = data['data'];
  }

  String? backendCode;
  String? backendMessage;

  if (data is Map<String, dynamic>) {
    backendCode = data['code']?.toString();
    final msg = data['message'];
    if (msg is List && msg.isNotEmpty) {
      backendMessage = msg.join(', ');
    } else if (msg is String) {
      backendMessage = msg;
    }
  }

  // Résoudre le code applicatif
  AppErrorCode code;
  if (backendCode != null && _serverCodeMap.containsKey(backendCode)) {
    code = _serverCodeMap[backendCode]!;
  } else {
    code = _fallbackCodeFromStatus(statusCode);
  }

  final backendMessageTrimmed = backendMessage?.trim();
  final hasBackendMessage =
      backendMessageTrimmed != null && backendMessageTrimmed.isNotEmpty;

  // Pour AUTH_INVALID_CREDENTIALS, on conserve un wording UX local stable
  // afin d'éviter les variantes backend génériques ou ambiguës.
  final userMessage = code == AppErrorCode.authInvalidCredentials
      ? _defaultUserMessage(code)
      : (hasBackendMessage
            ? backendMessageTrimmed
            : _defaultUserMessage(code));

  return AppError(
    code: code,
    source: AppErrorSource.server,
    userMessage: userMessage,
    httpStatus: statusCode,
    debugMessage:
        'HTTP $statusCode | code=$backendCode | msg=$backendMessage',
  );
}

/// Fallback pour Dio unknown (inclut SocketException wrappées, etc.).
AppError _mapUnknownDioError(DioException e) {
  final inner = e.error;
  if (inner is SocketException) {
    // Re-route vers la logique de connexion
    return _mapConnectionError(e);
  }
  return AppError(
    code: AppErrorCode.unknownNetworkError,
    source: AppErrorSource.network,
    userMessage: _defaultUserMessage(AppErrorCode.unknownNetworkError),
    debugMessage: '${e.type} → ${e.error} → ${e.message}',
  );
}

/// Helper pour créer une erreur réseau avec debug info.
AppError _networkError(AppErrorCode code, DioException e) {
  return AppError(
    code: code,
    source: AppErrorSource.network,
    userMessage: _defaultUserMessage(code),
    debugMessage:
        '${e.requestOptions.method} ${e.requestOptions.uri} | '
        '${e.type} | ${e.error}',
  );
}

/// Logs debug détaillés (debug mode uniquement).
void _logDioError(DioException e) {
  if (!kDebugMode) return;
  debugPrint(
    '[ErrorMapper] ${e.requestOptions.method} ${e.requestOptions.uri}\n'
    '  type=${e.type}\n'
    '  statusCode=${e.response?.statusCode}\n'
    '  error=${e.error}\n'
    '  message=${e.message}',
  );
}
