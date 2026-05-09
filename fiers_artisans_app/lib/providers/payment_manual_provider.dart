import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/manual_payment_model.dart';
import '../data/repositories/payment_manual_repository.dart';
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

      if (tx != null && (tx.isPending || tx.isPendingAdmin)) {
        _startPolling();
      } else {
        _pollingTimer?.cancel();
      }
    } catch (e) {
      String errorMessage;
      if (e is DioException && e.response?.data is Map) {
        final data = e.response!.data as Map;
        errorMessage = (data['message'] ?? 'Erreur inconnue').toString();
      } else {
        errorMessage = 'Erreur de connexion. Verifiez votre reseau.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
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
      _startPolling();
    } catch (e) {
      String errorMessage;
      if (e is DioException && e.response?.data is Map) {
        final data = e.response!.data as Map;
        errorMessage = (data['message'] ?? 'Erreur inconnue').toString();
      } else {
        errorMessage = 'Erreur de connexion. Verifiez votre reseau.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
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
      if (tx.isCompleted) {
        _pollingTimer?.cancel();
      }
    } catch (e) {
      String errorMessage;
      if (e is DioException && e.response?.data is Map) {
        final data = e.response!.data as Map;
        errorMessage = (data['message'] ?? 'Erreur inconnue').toString();
      } else {
        errorMessage = 'Erreur de connexion. Verifiez votre reseau.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
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
                  refundDone: payloadRefundDone,
                  refundRequired: latest.refundRequired,
                )
              : null,
        );
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
      String errorMessage;
      if (e is DioException && e.response?.data is Map) {
        final data = e.response!.data as Map;
        errorMessage = (data['message'] ?? 'Erreur inconnue').toString();
      } else {
        errorMessage = 'Erreur de connexion. Verifiez votre reseau.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
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

  String _statusMessage(
    String status, {
    String? rejectionReason,
    required bool refundDone,
    required bool refundRequired,
  }) {
    if (refundDone) {
      return 'Un remboursement a ete effectue.';
    }

    switch (status) {
      case 'COMPLETED':
        return 'Votre paiement a ete valide. Abonnement actif.';
      case 'REJECTED':
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
