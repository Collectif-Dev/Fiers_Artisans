import 'dart:async';

import 'package:fiers_artisans_app/data/models/manual_payment_model.dart';
import 'package:fiers_artisans_app/data/repositories/payment_manual_repository.dart';
import 'package:fiers_artisans_app/providers/payment_manual_provider.dart';
import 'package:fiers_artisans_app/services/chat_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePaymentManualRepository implements PaymentManualRepositoryContract {
  FakePaymentManualRepository({
    required this.initiateResult,
    required this.statusResult,
    this.currentResult,
  });

  final ManualPaymentModel initiateResult;
  ManualPaymentModel statusResult;
  ManualPaymentModel? currentResult;
  int fetchStatusCalls = 0;
  int submitProofCalls = 0;

  @override
  Future<ManualPaymentModel?> fetchCurrentTransaction() async {
    return currentResult;
  }

  @override
  Future<ManualPaymentModel> initiatePayment({required String provider}) async {
    return initiateResult;
  }

  @override
  Future<ManualPaymentModel> fetchStatus({
    required String transactionId,
  }) async {
    fetchStatusCalls += 1;
    return statusResult;
  }

  @override
  Future<void> submitProof({
    required String transactionId,
    required String filePath,
    required String senderNumber,
    DateTime? declaredPaymentTime,
  }) async {
    submitProofCalls += 1;
  }
}

void main() {
  test('initiates payment and stores current transaction', () async {
    final repo = FakePaymentManualRepository(
      initiateResult: const ManualPaymentModel(
        transactionId: 'TX-INIT-1',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'PENDING',
      ),
      statusResult: const ManualPaymentModel(
        transactionId: 'TX-INIT-1',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'PENDING',
      ),
    );
    final events = StreamController<ChatRealtimeEvent>.broadcast();
    final notifier = PaymentManualNotifier(
      repository: repo,
      domainEvents: events.stream,
    );

    await notifier.initiatePayment(provider: 'ORANGE_MONEY');

    expect(notifier.state.currentTransaction?.transactionId, 'TX-INIT-1');
    expect(notifier.state.error, isNull);
    expect(notifier.state.isLoading, isFalse);

    notifier.dispose();
    await events.close();
  });

  test(
    'updates status when receiving manualPaymentUpdated realtime event',
    () async {
      final repo = FakePaymentManualRepository(
        initiateResult: const ManualPaymentModel(
          transactionId: 'TX-REAL-1',
          provider: 'MTN_MOMO',
          amountFcfa: 5000,
          status: 'PENDING',
        ),
        statusResult: const ManualPaymentModel(
          transactionId: 'TX-REAL-1',
          provider: 'MTN_MOMO',
          amountFcfa: 5000,
          status: 'COMPLETED',
        ),
      );
      final events = StreamController<ChatRealtimeEvent>.broadcast();
      final notifier = PaymentManualNotifier(
        repository: repo,
        domainEvents: events.stream,
      );

      await notifier.initiatePayment(provider: 'MTN_MOMO');
      events.add(
        const ChatRealtimeEvent(
          event: 'manualPaymentUpdated',
          payload: {'transactionId': 'TX-REAL-1'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.fetchStatusCalls, greaterThanOrEqualTo(1));
      expect(notifier.state.currentTransaction?.status, 'COMPLETED');
      expect(
        notifier.state.transientMessage,
        'Votre paiement a ete valide. Abonnement actif.',
      );

      notifier.clearTransientMessage();
      expect(notifier.state.transientMessage, isNull);

      notifier.dispose();
      await events.close();
    },
  );

  test('includes rejection reason in realtime transient message', () async {
    final repo = FakePaymentManualRepository(
      initiateResult: const ManualPaymentModel(
        transactionId: 'TX-REAL-2',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'PENDING_ADMIN',
      ),
      statusResult: const ManualPaymentModel(
        transactionId: 'TX-REAL-2',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'REJECTED',
        rejectionReason: 'Capture floue',
      ),
    );
    final events = StreamController<ChatRealtimeEvent>.broadcast();
    final notifier = PaymentManualNotifier(
      repository: repo,
      domainEvents: events.stream,
    );

    await notifier.initiatePayment(provider: 'ORANGE_MONEY');
    events.add(
      const ChatRealtimeEvent(
        event: 'manualPaymentUpdated',
        payload: {
          'transactionId': 'TX-REAL-2',
          'status': 'REJECTED',
          'rejectionReason': 'Capture floue',
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(notifier.state.currentTransaction?.status, 'REJECTED');
    expect(notifier.state.transientMessage, 'Preuve rejetee : Capture floue');

    notifier.dispose();
    await events.close();
  });

  test(
    'sets an explicit error when submitting proof without transaction',
    () async {
      final repo = FakePaymentManualRepository(
        initiateResult: const ManualPaymentModel(
          transactionId: 'TX-X',
          provider: 'WAVE',
          amountFcfa: 5000,
          status: 'PENDING',
        ),
        statusResult: const ManualPaymentModel(
          transactionId: 'TX-X',
          provider: 'WAVE',
          amountFcfa: 5000,
          status: 'PENDING',
        ),
      );
      final events = StreamController<ChatRealtimeEvent>.broadcast();
      final notifier = PaymentManualNotifier(
        repository: repo,
        domainEvents: events.stream,
      );

      await notifier.submitProof(
        filePath: '/tmp/proof.png',
        senderNumber: '0700000000',
      );

      expect(notifier.state.error, 'Transaction introuvable.');
      expect(repo.submitProofCalls, 0);

      notifier.dispose();
      await events.close();
    },
  );
}
