import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/manual_payment_model.dart';
import '../data/repositories/payment_manual_repository.dart';
import '../services/chat_realtime_service.dart';

class PaymentManualState {
  final ManualPaymentModel? currentTransaction;
  final bool isLoading;
  final String? error;
  final bool hasSubmittedProof;

  const PaymentManualState({
    this.currentTransaction,
    this.isLoading = false,
    this.error,
    this.hasSubmittedProof = false,
  });

  PaymentManualState copyWith({
    ManualPaymentModel? currentTransaction,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? hasSubmittedProof,
  }) {
    return PaymentManualState(
      currentTransaction: currentTransaction ?? this.currentTransaction,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasSubmittedProof: hasSubmittedProof ?? this.hasSubmittedProof,
    );
  }
}

final paymentManualProvider =
    StateNotifierProvider<PaymentManualNotifier, PaymentManualState>((ref) {
  return PaymentManualNotifier();
});

class PaymentManualNotifier extends StateNotifier<PaymentManualState> {
  final PaymentManualRepository _repository = PaymentManualRepository();
  final ChatRealtimeService _realtime = ChatRealtimeService();

  Timer? _pollingTimer;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  PaymentManualNotifier() : super(const PaymentManualState()) {
    _realtimeSub = _realtime.domainEvents.listen((event) {
      if (event.event == 'manualPaymentUpdated') {
        final txId = event.payload['transactionId']?.toString();
        if (txId != null && txId == state.currentTransaction?.transactionId) {
          fetchStatus();
        }
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchStatus() async {
    final txId = state.currentTransaction?.transactionId;
    if (txId == null || txId.isEmpty) return;

    try {
      final tx = await _repository.fetchStatus(transactionId: txId);
      state = state.copyWith(currentTransaction: tx);
      if (tx.isCompleted) {
        _pollingTimer?.cancel();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> submitProof({
    required String filePath,
    required String senderNumber,
    DateTime? declaredPaymentTime,
  }) async {
    final txId = state.currentTransaction?.transactionId;
    if (txId == null || txId.isEmpty) {
      state = state.copyWith(error: 'Transaction introuvable.');
      return;
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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    _pollingTimer?.cancel();
    state = const PaymentManualState();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchStatus();
    });
  }
}
