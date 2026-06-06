import 'package:fiers_artisans/data/models/manual_payment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses manual payment payload', () {
    final model = ManualPaymentModel.fromJson({
      'transaction_id': 'TX-ZZZ111',
      'provider': 'MTN_MOMO',
      'amount_fcfa': 5000,
      'status': 'REJECTED',
      'recipient_number': '0700000000',
      'rejection_reason': 'Informations incoherentes',
      'refund_required': true,
      'refund_done_at': '2026-05-21T09:30:00.000Z',
      'validated_at': '2026-05-19T09:30:00.000Z',
      'request_number': 3,
      'replaced_by_transaction_id': 'TX-NEW-222',
      'cooldown_until': '2026-05-21T12:30:00.000Z',
      'cooldown_cycle': 2,
      'proof_count': 4,
      'provider_available': true,
    });

    expect(model.transactionId, 'TX-ZZZ111');
    expect(model.provider, 'MTN_MOMO');
    expect(model.amountFcfa, 5000);
    expect(model.isRejected, true);
    expect(model.rejectionReason, 'Informations incoherentes');
    expect(model.refundRequired, true);
    expect(model.refundDoneAt, isNotNull);
    expect(model.isRefundDone, true);
    expect(model.providerAvailable, true);
    expect(model.requestNumber, 3);
    expect(model.validatedAt, isNotNull);
    expect(model.isRejectedAfterValidation, true);
    expect(model.replacedByTransactionId, 'TX-NEW-222');
    expect(model.hasReplacement, true);
    expect(model.cooldownUntil, isNotNull);
    expect(model.cooldownCycle, 2);
    expect(model.submittedProofCount, 4);
    expect(model.currentAttemptNumber, 1);
    expect(model.isAutoReplaceCandidate, false);
  });
}
