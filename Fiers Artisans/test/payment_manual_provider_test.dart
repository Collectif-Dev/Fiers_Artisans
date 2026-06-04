import 'dart:async';

import 'package:dio/dio.dart';
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
    this.initiateError,
    this.submitProofError,
  });

  final ManualPaymentModel initiateResult;
  ManualPaymentModel statusResult;
  ManualPaymentModel? currentResult;
  Object? initiateError;
  Object? submitProofError;
  int fetchStatusCalls = 0;
  int submitProofCalls = 0;
  int initiateCalls = 0;
  final List<String> initiateProviders = [];

  @override
  Future<ManualPaymentModel?> fetchCurrentTransaction() async {
    return currentResult;
  }

  @override
  Future<ManualPaymentModel> initiatePayment({required String provider}) async {
    initiateCalls += 1;
    initiateProviders.add(provider);
    if (initiateError != null) {
      throw initiateError!;
    }
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
    if (submitProofError != null) {
      throw submitProofError!;
    }
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

  test('maps refund pending error when initiation is blocked', () async {
    final requestOptions = RequestOptions(path: '/payments/manual/initiate');
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
      initiateError: DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 409,
          data: const {
            'code': 'PAYMENT_MANUAL_REFUND_PENDING',
            'message':
                'Un remboursement est en cours. Vous ne pouvez pas creer une nouvelle demande.',
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    final events = StreamController<ChatRealtimeEvent>.broadcast();
    final notifier = PaymentManualNotifier(
      repository: repo,
      domainEvents: events.stream,
    );

    await notifier.initiatePayment(provider: 'ORANGE_MONEY');

    expect(
      notifier.state.error,
      'Un remboursement est en cours. Vous ne pouvez pas creer une nouvelle demande.',
    );

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

  test('auto-replaces a terminal rejected transaction on load using its provider', () async {
    final repo = FakePaymentManualRepository(
      initiateResult: const ManualPaymentModel(
        transactionId: 'TX-NEW-1',
        provider: 'MTN_MOMO',
        amountFcfa: 5000,
        status: 'PENDING',
      ),
      statusResult: const ManualPaymentModel(
        transactionId: 'TX-NEW-1',
        provider: 'MTN_MOMO',
        amountFcfa: 5000,
        status: 'PENDING',
      ),
      currentResult: ManualPaymentModel(
        transactionId: 'TX-OLD-1',
        provider: 'MTN_MOMO',
        amountFcfa: 5000,
        status: 'REJECTED',
        validatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
      ),
    );
    final events = StreamController<ChatRealtimeEvent>.broadcast();
    final notifier = PaymentManualNotifier(
      repository: repo,
      domainEvents: events.stream,
    );

    await notifier.loadCurrentTransaction(refresh: true);

    expect(repo.initiateCalls, 1);
    expect(repo.initiateProviders, ['MTN_MOMO']);
    expect(notifier.state.currentTransaction?.transactionId, 'TX-NEW-1');
    expect(
      notifier.state.transientMessage,
      'Votre transaction TX-OLD-1 a ete remplacee automatiquement par TX-NEW-1.',
    );

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

  test('maps retry-after header for 429 proof submissions', () async {
    final requestOptions = RequestOptions(
      path: '/payments/manual/tx/submit-proof',
    );
    final repo = FakePaymentManualRepository(
      initiateResult: const ManualPaymentModel(
        transactionId: 'TX-RL',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'PENDING',
      ),
      statusResult: const ManualPaymentModel(
        transactionId: 'TX-RL',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'PENDING',
      ),
      currentResult: const ManualPaymentModel(
        transactionId: 'TX-RL',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'PENDING',
      ),
      submitProofError: DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 429,
          headers: Headers.fromMap(<String, List<String>>{
            'retry-after': <String>['120'],
          }),
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    final events = StreamController<ChatRealtimeEvent>.broadcast();
    final notifier = PaymentManualNotifier(
      repository: repo,
      domainEvents: events.stream,
    );

    await notifier.loadCurrentTransaction(refresh: true);
    await notifier.submitProof(
      filePath: '/tmp/proof.png',
      senderNumber: '0700000000',
    );

    expect(
      notifier.state.error,
      'Trop de tentatives. Reessayez dans 2 minute(s).',
    );
    expect(repo.submitProofCalls, 1);

    notifier.dispose();
    await events.close();
  });

  test('keeps backend cooldown message for rejected transaction cooldown', () async {
    final requestOptions = RequestOptions(
      path: '/payments/manual/tx/submit-proof',
    );
    final repo = FakePaymentManualRepository(
      initiateResult: const ManualPaymentModel(
        transactionId: 'TX-CD',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'PENDING',
      ),
      statusResult: const ManualPaymentModel(
        transactionId: 'TX-CD',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'REJECTED',
      ),
      currentResult: const ManualPaymentModel(
        transactionId: 'TX-CD',
        provider: 'ORANGE_MONEY',
        amountFcfa: 5000,
        status: 'REJECTED',
      ),
      submitProofError: DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 429,
          data: const {
            'code': 'PAYMENT_MANUAL_COOLDOWN_ACTIVE',
            'message': 'Nouvelle soumission possible dans 5 h.',
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    final events = StreamController<ChatRealtimeEvent>.broadcast();
    final notifier = PaymentManualNotifier(
      repository: repo,
      domainEvents: events.stream,
    );

    await notifier.loadCurrentTransaction(refresh: true);
    await notifier.submitProof(
      filePath: '/tmp/proof.png',
      senderNumber: '0700000000',
    );

    expect(notifier.state.error, 'Nouvelle soumission possible dans 5 h.');

    notifier.dispose();
    await events.close();
  });
}
