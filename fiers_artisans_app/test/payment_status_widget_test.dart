import 'package:fiers_artisans_app/data/models/manual_payment_model.dart';
import 'package:fiers_artisans_app/presentation/artisan/payment_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders transaction status and id', (tester) async {
    const tx = ManualPaymentModel(
      transactionId: 'TX-ABCD1234',
      provider: 'ORANGE_MONEY',
      amountFcfa: 5000,
      status: 'PENDING_ADMIN',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PaymentStatusWidget(transaction: tx),
        ),
      ),
    );

    expect(find.textContaining('PENDING_ADMIN'), findsOneWidget);
    expect(find.textContaining('TX-ABCD1234'), findsOneWidget);
  });
}
