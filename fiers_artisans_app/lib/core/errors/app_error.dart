/// Source de l'erreur : réseau/transport vs serveur/API.
enum AppErrorSource {
  /// Erreur de transport : DNS, timeout, connexion refusée, réseau inaccessible, etc.
  /// Le backend n'a jamais reçu la requête.
  network,

  /// Le backend a répondu avec une erreur HTTP (4xx, 5xx).
  server,

  /// Erreur locale (parsing, stockage, logique client).
  local,
}

/// Codes internes stables pour le diagnostic.
///
/// Les codes `NETWORK_*` sont déterminés côté mobile (transport).
/// Les codes `AUTH_*`, `VALIDATION_*`, `SERVER_*` proviennent du backend via le champ `code`.
enum AppErrorCode {
  // ── Transport / réseau (mobile-only) ──────────────────────────
  networkUnreachable,
  dnsLookupFailed,
  connectionRefused,
  connectTimeout,
  sendTimeout,
  receiveTimeout,
  tlsHandshakeFailed,
  cleartextNotPermitted,
  requestCancelled,
  unknownNetworkError,

  // ── Serveur / backend ─────────────────────────────────────────
  // Auth
  authInvalidCredentials,
  authAccountDisabled,
  authOtpRequired,
  authPinSetupRequired,
  authPinBlocked,
  authInvalidToken,
  authPhoneAlreadyUsed,

  // Validation
  validationError,

  // Générique serveur
  serverError,
  internalError,
  notFound,
  forbidden,
  conflict,

  // ── Inconnu ───────────────────────────────────────────────────
  unknown,
}

class AppError implements Exception {
  /// Code stable pour piloter la logique applicative.
  final AppErrorCode code;

  /// Source de l'erreur.
  final AppErrorSource source;

  /// Message destiné à l'utilisateur final.
  final String userMessage;

  /// Message technique pour les logs debug (non affiché à l'utilisateur).
  final String? debugMessage;

  /// Code HTTP si disponible (null pour les erreurs réseau pures).
  final int? httpStatus;

  const AppError({
    required this.code,
    required this.source,
    required this.userMessage,
    this.debugMessage,
    this.httpStatus,
  });

  /// Indique si l'erreur nécessite une vérification OTP.
  bool get isOtpRequired => code == AppErrorCode.authOtpRequired;
  bool get isPinSetupRequired => code == AppErrorCode.authPinSetupRequired;

  @override
  String toString() =>
      'AppError(code: $code, source: $source, httpStatus: $httpStatus, '
      'userMessage: "$userMessage", debugMessage: "$debugMessage")';
}
