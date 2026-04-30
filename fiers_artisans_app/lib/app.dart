import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/app_providers.dart';
import 'providers/payment_manual_provider.dart';

class FiersArtisansApp extends ConsumerStatefulWidget {
  const FiersArtisansApp({super.key});

  @override
  ConsumerState<FiersArtisansApp> createState() => _FiersArtisansAppState();
}

class _FiersArtisansAppState extends ConsumerState<FiersArtisansApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    ref.listenManual<PaymentManualState>(paymentManualProvider, (previous, next) {
      final message = next.transientMessage;
      if (message == null || message.trim().isEmpty) {
        return;
      }
      final messenger = _scaffoldMessengerKey.currentState;
      messenger?.showSnackBar(SnackBar(content: Text(message)));
      ref.read(paymentManualProvider.notifier).clearTransientMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Fiers Artisans',
      debugShowCheckedModeBanner: false,
      // Theme
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // i18n
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // Routing
      routerConfig: appRouter,
    );
  }
}
