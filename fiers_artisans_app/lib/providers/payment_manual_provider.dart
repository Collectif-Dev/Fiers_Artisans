import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/error_mapper.dart';
import '../data/models/manual_payment_model.dart';
import '../data/repositories/payment_manual_repository.dart';
import 'session_scope_provider.dart';
import '../services/chat_realtime_service.dart';

class PaymentManualState {
  final ManualPaymentModel? currentTransaction;
  final bool isLoading;
  final String? error;
  final bool hasSubmittedProof;
  final String? transientMessage;

  const PaymentManualState({
    this.currentTransaction,
    this.isLoading = false,
    this.error,
    this.hasSubmittedProof = false,
    this.transientMessage,
  });

  PaymentManualState copyWith({
    ManualPaymentModel? currentTransaction,
    bool clearCurrentTransaction = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? hasSubmittedProof,
    String? transientMessage,
    bool clearTransientMessage = false,
  }) {
    return PaymentManualState(
      currentTransaction: clearCurrentTransaction
          ? null
          : (currentTransaction ?? this.currentTransaction),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasSubmittedProof: hasSubmittedProof ?? this.hasSubmittedProof,
      transientMessage: clearTransientMessage
          ? null
          : (transientMessage ?? this.transientMessage),
    );
  }
}

final paymentManualProvider =
    StateNotifierProvider<PaymentManualNotifier, PaymentManualState>((ref) {
      ref.watch(sessionEpochProvider);
      return PaymentManualNotifier();
    });

class PaymentManualNotifier extends StateNotifier<PaymentManualState> {
  final PaymentManualRepositoryContract _repository;
  final Stream<ChatRealtimeEvent> _domainEvents;
  final Duration pollingInterval;

  Timer? _pollingTimer;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  PaymentManualNotifier({
    PaymentManualRepositoryContract? repository,
    ChatRealtimeService? realtime,
    Stream<ChatRealtimeEvent>? domainEvents,
    this.pollingInterval = const Duration(seconds: 30),
  }) : _repository = repository ?? PaymentManualRepository(),
       _domainEvents =
           domainEvents ?? (realtime ?? ChatRealtimeService()).domainEvents,
       super(const PaymentManualState()) {
    _realtimeSub = _domainEvents.listen((event) {
      if (event.event == 'manualPaymentUpdated') {
        unawaited(_handleManualPaymentUpdated(event.payload));
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> loadCurrentTransaction({bool refresh = false}) async {
    if (!refresh && state.currentTransaction != null) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tx = await _repository.fetchCurrentTransaction();
      state = state.copyWith(
        currentTransaction: tx,
        clearCurrentTransaction: tx == null,
        isLoading: false,
        hasSubmittedProof: tx?.isPendingAdmin == true,
      );

      if (tx != null && _shouldPoll(tx)) {
        _startPolling();
      } else {
        _pollingTimer?.cancel();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _toUserFacingError(e));
    }
  }

  Future<void> initiatePayment({required String provider}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tx = await _repository.initiatePayment(provider: provider);
      state = state.copyWith(
        currentTransaction: tx,
        isLoading: false,
        hasSubmittedProof: false,
      );
      if (_shouldPoll(tx)) {
        _startPolling();
      } else {
        _pollingTimer?.cancel();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _toUserFacingError(e));
    }
  }

  Future<void> fetchStatus() async {
    final txId = state.currentTransaction?.transactionId;
    if (txId == null || txId.isEmpty) return;

    try {
      final tx = await _repository.fetchStatus(transactionId: txId);
      state = state.copyWith(
        currentTransaction: tx,
        hasSubmittedProof: tx.status == 'REJECTED'
            ? false
            : state.hasSubmittedProof,
      );
      if (!_shouldPoll(tx)) {
        _pollingTimer?.cancel();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _toUserFacingError(e));
    }
  }

  Future<void> _handleManualPaymentUpdated(Map<String, dynamic> payload) async {
    final txId = payload['transactionId']?.toString();
    final previousStatus = state.currentTransaction?.status;
    final payloadStatus = payload['status']?.toString();
    final payloadReason = payload['rejectionReason']?.toString();
    final payloadRefundDone = payload['refundDone'] == true;
    final payloadRefundRequired = payload['refundRequired'] == true;

    if (txId != null && txId.isNotEmpty) {
      try {
        final latest = await _repository.fetchStatus(transactionId: txId);
        final statusChanged =
            previousStatus == null || previousStatus != latest.status;
        state = state.copyWith(
          currentTransaction: latest,
          hasSubmittedProof: latest.status == 'REJECTED'
              ? false
              : state.hasSubmittedProof,
          transientMessage: statusChanged
              ? _statusMessage(
                  latest.status,
                  rejectionReason: latest.rejectionReason ?? payloadReason,
                  refundDone: latest.refundDoneAt != null || payloadRefundDone,
                  refundRequired: latest.refundRequired,
                  amountFcfa: latest.amountFcfa,
                  cooldownActive: latest.isCooldownActive,
                  cooldownRemainingSeconds: latest.cooldownRemainingSeconds,
                )
              : null,
        );
        if (_shouldPoll(latest)) {
          _startPolling();
        } else {
          _pollingTimer?.cancel();
        }
        return;
      } catch (_) {
        // Fallback to payload-only status message when API refresh fails.
      }
    }

    if (payloadStatus != null && payloadStatus.isNotEmpty) {
      state = state.copyWith(
        transientMessage: _statusMessage(
          payloadStatus,
          rejectionReason: payloadReason,
          refundDone: payloadRefundDone,
          refundRequired: payloadRefundRequired,
          cooldownActive: false,
          cooldownRemainingSeconds: 0,
        ),
      );
    }
  }

  Future<void> submitProof({
    required String filePath,
    required String senderNumber,
    DateTime? declaredPaymentTime,
  }) async {
    var txId = state.currentTransaction?.transactionId;
    if (txId == null || txId.isEmpty) {
      await loadCurrentTransaction(refresh: true);
      txId = state.currentTransaction?.transactionId;
      if (txId == null || txId.isEmpty) {
        state = state.copyWith(error: 'Transaction introuvable.');
        return;
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.submitProof(
        transactionId: txId,
        filePath: filePath,
        senderNumber: senderNumber,
        declaredPaymentTime: declaredPaymentTime,
      );
      state = state.copyWith(isLoading: false, hasSubmittedProof: true);
      await fetchStatus();
      _startPolling();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _toUserFacingError(e));
    }
  }

  void reset() {
    _pollingTimer?.cancel();
    state = const PaymentManualState();
  }

  void clearTransientMessage() {
    state = state.copyWith(clearTransientMessage: true);
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(pollingInterval, (_) {
      fetchStatus();
    });
  }

  bool _shouldPoll(ManualPaymentModel tx) => tx.isPending || tx.isPendingAdmin;

  String _toUserFacingError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final transportMessage = (error.message ?? '').toLowerCase();
      final payloadText = data == null ? '' : data.toString().toLowerCase();

      String backendCode = '';
      String backendMessage = '';

      if (data is Map) {
        final rawCode = data['code'];
        if (rawCode != null) {
          backendCode = rawCode.toString();
        }

        final rawMessage = data['message'];
        if (rawMessage is List && rawMessage.isNotEmpty) {
          backendMessage = rawMessage.first.toString();
        } else if (rawMessage != null) {
          backendMessage = rawMessage.toString();
        }
      }

      final signature =
          '${backendCode.toLowerCase()} ${backendMessage.toLowerCase()} $transportMessage $payloadText';

      String formatRetryAfter(String secondsRaw) {
        final seconds = int.tryParse(secondsRaw.trim());
        if (seconds == null || seconds <= 0) {
          return 'Trop de tentatives en peu de temps. Patientez un moment puis reessayez.';
        }
        if (seconds < 60) {
          return 'Trop de tentatives. Reessayez dans ${seconds}s.';
        }
        final minutes = (seconds / 60).ceil();
        if (minutes < 60) {
          return 'Trop de tentatives. Reessayez dans $minutes minute(s).';
        }
        final hours = (minutes / 60).ceil();
        return 'Trop de tentatives. Reessayez dans $hours heure(s).';
      }

      if (status == 429 ||
          signature.contains('too many requests') ||
          signature.contains('rate_limit') ||
          backendCode == 'PAYMENT_MANUAL_DAILY_UPLOAD_LIMIT' ||
          backendCode == 'PAYMENT_MANUAL_SUBMIT_RATE_LIMIT' ||
          backendCode == 'PAYMENT_MANUAL_REJECTED_COOLDOWN' ||
          backendCode == 'PAYMENT_MANUAL_COOLDOWN_ACTIVE') {
        if (backendCode == 'PAYMENT_MANUAL_DAILY_UPLOAD_LIMIT' &&
            backendMessage.trim().isNotEmpty) {
          return backendMessage;
        }
        if (backendCode == 'PAYMENT_MANUAL_SUBMIT_RATE_LIMIT' &&
            backendMessage.trim().isNotEmpty) {
          return backendMessage;
        }
        if (backendCode == 'PAYMENT_MANUAL_REJECTED_COOLDOWN' &&
            backendMessage.trim().isNotEmpty) {
          return backendMessage;
        }
        if (backendCode == 'PAYMENT_MANUAL_COOLDOWN_ACTIVE' &&
            backendMessage.trim().isNotEmpty) {
          return backendMessage;
        }
        final retryAfter = error.response?.headers.value('retry-after');
        if ((retryAfter ?? '').trim().isNotEmpty) {
          return formatRetryAfter(retryAfter!);
        }
        return 'Trop de tentatives en peu de temps. Patientez un moment puis reessayez.';
      }

      if (signature.contains('socketexception') &&
          signature.contains('too many requests')) {
        return 'Trop de tentatives en peu de temps. Patientez un moment puis reessayez.';
      }

      if (backendCode == 'PAYMENT_MANUAL_MAX_ATTEMPTS') {
        return 'Vous avez atteint la limite de tentatives pour cette transaction.';
      }

      if (backendCode == 'PAYMENT_MANUAL_REFUND_PENDING') {
        return backendMessage.trim().isNotEmpty
            ? backendMessage
            : 'Un remboursement est en cours. Vous ne pouvez pas creer une nouvelle demande.';
      }

      if (signature.contains('type de fichier invalide') ||
          signature.contains('mime') ||
          signature.contains('format non pris en charge')) {
        return 'La capture selectionnee n\'est pas valide. Utilisez une image JPG, PNG ou WEBP.';
      }

      if (signature.contains('heic') || signature.contains('heif')) {
        return 'Le format HEIC/HEIF n\'est pas pris en charge. Convertissez la capture en JPG ou PNG puis reessayez.';
      }

      if (signature.contains('image trop lourde') ||
          signature.contains('max 5 mo')) {
        return 'La capture est trop lourde. Taille maximale: 5 Mo.';
      }

      if (signature.contains('resolution insuffisante')) {
        return 'La capture est trop petite ou peu lisible. Prenez une image plus claire.';
      }

      if (signature.contains('image corrompue') ||
          signature.contains('illisible')) {
        return 'La capture est illisible. Reprenez une capture nette.';
      }

      if (signature.contains('expediteur') ||
          signature.contains('sender_number')) {
        return 'Le numero expediteur est invalide. Saisissez un numero ivoirien valide (07, 05 ou 01 + 8 chiffres).';
      }

      if (status == 401 || status == 403) {
        return 'Votre session a expire. Reconnectez-vous puis reessayez.';
      }

      if (kDebugMode) {
        debugPrint(
          '[payment_manual_provider] raw error: status=$status code=$backendCode message=$backendMessage',
        );
      }
    }

    return mapException(error).userMessage;
  }

  String _statusMessage(
    String status, {
    String? rejectionReason,
    required bool refundDone,
    required bool refundRequired,
    int? amountFcfa,
    required bool cooldownActive,
    required int cooldownRemainingSeconds,
  }) {
    if (refundDone) {
      final amount = amountFcfa ?? 5000;
      return 'Votre remboursement de $amount FCFA a ete confirme. Vous pouvez maintenant creer une nouvelle demande.';
    }

    switch (status) {
      case 'COMPLETED':
        return 'Votre paiement a ete valide. Abonnement actif.';
      case 'REJECTED':
        if (cooldownActive) {
          final hours = cooldownRemainingSeconds ~/ 3600;
          final minutes = (cooldownRemainingSeconds % 3600) ~/ 60;
          final seconds = cooldownRemainingSeconds % 60;
          return 'Blocage temporaire actif. Nouvelle soumission possible dans ${hours}h ${minutes.toString().padLeft(2, '0')}min ${seconds.toString().padLeft(2, '0')}s.';
        }
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty) {
          return 'Preuve rejetee : ${rejectionReason.trim()}';
        }
        return 'Votre preuve a ete rejetee.';
      case 'EXPIRED':
        return refundRequired
            ? 'Votre demande a expire. Un remboursement est necessaire.'
            : 'Votre demande a expire.';
      case 'PENDING_ADMIN':
        return 'Votre demande de paiement est en attente de validation par nos equipes.';
      case 'PENDING':
        return 'Transaction initiee - veuillez soumettre votre preuve.';
      default:
        return 'Statut de paiement mis a jour.';
    }
  }
}
