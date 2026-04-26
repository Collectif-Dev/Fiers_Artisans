import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../config/constants.dart';
import '../config/theme.dart';

// ──────────── Theme Provider ────────────
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(AppConstants.keyThemeMode) ?? 'dark';
    state = mode == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setDark() async {
    state = ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyThemeMode, 'dark');
  }

  Future<void> setLight() async {
    state = ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyThemeMode, 'light');
  }

  Future<void> toggle() async {
    if (state == ThemeMode.dark) {
      await setLight();
    } else {
      await setDark();
    }
  }

  bool get isDark => state == ThemeMode.dark;
}

// ──────────── Locale Provider ────────────
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('fr')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(AppConstants.keyLocale) ?? 'fr';
    state = Locale(lang);
  }

  Future<void> setLocale(Locale locale, BuildContext context) async {
    state = locale;
    await context.setLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLocale, locale.languageCode);
  }

  Future<void> setFrench(BuildContext context) =>
      setLocale(const Locale('fr'), context);

  Future<void> setEnglish(BuildContext context) =>
      setLocale(const Locale('en'), context);

  Future<void> toggleLocale(BuildContext context) async {
    if (state.languageCode == 'fr') {
      await setEnglish(context);
    } else {
      await setFrench(context);
    }
  }
}

// ──────────── Onboarding Provider ────────────
final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(AppConstants.keyOnboardingCompleted) ?? false;
  }

  Future<void> complete() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingCompleted, true);
  }
}

// ──────────── Theme Helper Extension ────────────
extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get goldColor =>
      isDark ? AppTheme.gold : AppTheme.goldDark;
}
