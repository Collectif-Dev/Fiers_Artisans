import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'config/app_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore initialization races in background isolate.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Future.wait([
    dotenv.load(fileName: '.env'),
    EasyLocalization.ensureInitialized(),
  ]);

  if (kDebugMode) {
    debugPrint('[Config] API Base URL: ${AppConfig.apiBaseUrl}');
    debugPrint('[Config] WS Base URL: ${AppConfig.wsBaseUrl}');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      child: const ProviderScope(child: FiersArtisansApp()),
    ),
  );

  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );
}
