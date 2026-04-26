import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/app_providers.dart';

class FiersArtisansApp extends ConsumerWidget {
  const FiersArtisansApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
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
