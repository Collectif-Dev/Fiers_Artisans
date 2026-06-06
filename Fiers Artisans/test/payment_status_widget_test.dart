import 'package:fiers_artisans/data/models/manual_payment_model.dart';
import 'package:fiers_artisans/presentation/artisan/payment_status_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _InlineAssetLoader extends AssetLoader {
  const _InlineAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}

void main() {
  testWidgets('renders transaction status and id', (tester) async {
    const tx = ManualPaymentModel(
      transactionId: 'TX-ABCD1234',
      provider: 'ORANGE_MONEY',
      amountFcfa: 5000,
      status: 'PENDING_ADMIN',
      requestNumber: 2,
      submittedProofCount: 1,
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('fr')],
        path: 'unused',
        fallbackLocale: const Locale('fr'),
        startLocale: const Locale('fr'),
        assetLoader: const _InlineAssetLoader({
          'manual_payment': {
            'status_label': 'Statut : {status}',
            'transaction_id': 'Transaction : {id}',
            'request_number': 'Demande n°{number}',
            'attempt_count': 'Tentative : {attempt}/3',
            'status': {'pending_admin': 'En attente admin'},
          },
        }),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const Scaffold(body: PaymentStatusWidget(transaction: tx)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Statut : En attente admin'), findsOneWidget);
    expect(find.text('Transaction : TX-ABCD1234'), findsOneWidget);
    expect(find.text('Demande n°2'), findsOneWidget);
    expect(find.text('Tentative : 1/3'), findsOneWidget);
  });

  testWidgets('renders cooldown countdown for blocked rejected transaction', (
    tester,
  ) async {
    final tx = ManualPaymentModel(
      transactionId: 'TX-COOLDOWN-1',
      provider: 'ORANGE_MONEY',
      amountFcfa: 5000,
      status: 'REJECTED',
      cooldownUntil: DateTime.now().add(
        const Duration(hours: 4, minutes: 23, seconds: 59),
      ),
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('fr')],
        path: 'unused',
        fallbackLocale: const Locale('fr'),
        startLocale: const Locale('fr'),
        assetLoader: const _InlineAssetLoader({
          'manual_payment': {
            'status_label': 'Statut : {status}',
            'transaction_id': 'Transaction : {id}',
            'cooldown_countdown': 'Blocage actif : {remaining}',
            'status': {'rejected': 'Rejete'},
          },
        }),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Scaffold(body: PaymentStatusWidget(transaction: tx)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Blocage actif : 4h 23min'), findsOneWidget);
  });
}
