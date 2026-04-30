import 'package:fiers_artisans_app/data/models/manual_payment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses manual payment payload', () {
    final model = ManualPaymentModel.fromJson({
      'transaction_id': 'TX-ZZZ111',
      'provider': 'MTN_MOMO',
      'amount_fcfa': 5000,
      'status': 'REJECTED',
      'recipient_number': '0700000000',
    });

    expect(model.transactionId, 'TX-ZZZ111');
    expect(model.provider, 'MTN_MOMO');
    expect(model.amountFcfa, 5000);
    expect(model.isRejected, true);
  });
}
