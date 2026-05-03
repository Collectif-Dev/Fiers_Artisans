import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppIconService {
  static const MethodChannel _channel = MethodChannel(
    'fiers_artisans/app_icon',
  );

  static Future<void> syncForTheme({required bool isDark}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      await _channel.invokeMethod('setThemeIcon', {'isDark': isDark});
    } catch (_) {
      // Ignore platform errors to avoid blocking app startup.
    }
  }
}
