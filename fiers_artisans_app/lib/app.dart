import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/app_providers.dart';
import 'providers/payment_manual_provider.dart';
import 'services/app_icon_service.dart';
import 'services/chat_realtime_service.dart';
import 'presentation/common/app_snackbar.dart';

class FiersArtisansApp extends ConsumerStatefulWidget {
  const FiersArtisansApp({super.key});

  @override
  ConsumerState<FiersArtisansApp> createState() => _FiersArtisansAppState();
}

class _FiersArtisansAppState extends ConsumerState<FiersArtisansApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final ChatRealtimeService _realtime = ChatRealtimeService();
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;
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

    _realtimeSub = _realtime.domainEvents.listen(_handleRealtimeEvent);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _handleRealtimeEvent(ChatRealtimeEvent event) {
    if (!mounted || event.event != 'notificationCreated') {
      return;
    }

    final notif = event.payload['notification'];
    if (notif is! Map<String, dynamic>) {
      return;
    }

    final type = (notif['type'] ?? '').toString().toUpperCase();
    const paymentSnackTypes = {
      'PAYMENT_MANUAL_VALIDATED',
      'PAYMENT_MANUAL_REJECTED',
      'PAYMENT_MANUAL_REOPENED',
      'PAYMENT_MANUAL_EXPIRED',
      'REFUND_PROCESSED',
    };
    if (!paymentSnackTypes.contains(type)) {
      return;
    }

    final title = (notif['title'] ?? '').toString().trim();
    final body = (notif['body'] ?? '').toString().trim();
    final message = body.isNotEmpty ? body : title;

    if (message.isEmpty) {
      return;
    }

    AppSnackBar.show(
      context,
      message: message,
      actionLabel: 'notifications.open'.tr(),
      onAction: () {
        appRouter.push('/notifications');
      },
    );
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
