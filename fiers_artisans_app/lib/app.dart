import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/app_providers.dart';
import 'providers/payment_manual_provider.dart';
import 'services/app_icon_service.dart';
import 'presentation/common/app_snackbar.dart';

class FiersArtisansApp extends ConsumerStatefulWidget {
  const FiersArtisansApp({super.key});

  @override
  ConsumerState<FiersArtisansApp> createState() => _FiersArtisansAppState();
}

class _FiersArtisansAppState extends ConsumerState<FiersArtisansApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool? _lastDarkIconValue;

  void _syncHomeIconWithTheme(ThemeMode themeMode, BuildContext context) {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && systemBrightness == Brightness.dark);

    if (_lastDarkIconValue == isDark) {
      return;
    }
    _lastDarkIconValue = isDark;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppIconService.syncForTheme(isDark: isDark);
    });
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual<PaymentManualState>(paymentManualProvider, (
      previous,
      next,
    ) {
      final message = next.transientMessage;
      if (message == null || message.trim().isEmpty) {
        return;
      }
      AppSnackBar.show(context, message: message);
      ref.read(paymentManualProvider.notifier).clearTransientMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    _syncHomeIconWithTheme(themeMode, context);

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
