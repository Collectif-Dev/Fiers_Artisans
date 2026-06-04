import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color gold = Color(0xFFE8A020);
  static const Color goldDark = Color(0xFFC87D2A);

  // Gradient
  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ──────────── DARK THEME ────────────
  static const Color _darkBackground = Color(0xFF0D0D0F);
  static const Color _darkSurface = Color(0xFF1A1A1E);
  static const Color _darkSurfaceElevated = Color(0xFF242428);
  static const Color _darkOnBackground = Color(0xFFF5F5F5);
  static const Color _darkOnSurfaceMuted = Color(0xFF9E9EA8);
  static const Color _darkDivider = Color(0xFF2A2A2E);

  // ──────────── LIGHT THEME ────────────
  static const Color _lightBackground = Color(0xFFF7F7F9);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceElevated = Color(0xFFEFEFEF);
  static const Color _lightOnBackground = Color(0xFF1A1A1E);
  static const Color _lightOnSurfaceMuted = Color(0xFF6B6B75);
  static const Color _lightDivider = Color(0xFFE0E0E6);

  // Semantic colors (shared)
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  static TextTheme _buildTextTheme(Color textColor, Color mutedColor) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: mutedColor,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: mutedColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: mutedColor,
      ),
    );
  }

  // ──────────── DARK ThemeData ────────────
  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: gold,
      secondary: goldDark,
      surface: _darkSurface,
      onSurface: _darkOnBackground,
      error: error,
      onError: Colors.white,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBackground,
      textTheme: _buildTextTheme(_darkOnBackground, _darkOnSurfaceMuted),
      fontFamily: GoogleFonts.inter().fontFamily,
      dividerColor: _darkDivider,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkSurfaceElevated,
        foregroundColor: _darkOnBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _darkOnBackground,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurfaceElevated,
        selectedItemColor: gold,
        unselectedItemColor: _darkOnSurfaceMuted,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        hintStyle: GoogleFonts.inter(color: _darkOnSurfaceMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: gold,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurface,
        selectedColor: gold.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(fontSize: 13),
        side: BorderSide(color: _darkDivider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurfaceElevated,
        contentTextStyle: GoogleFonts.inter(color: _darkOnBackground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  // ──────────── LIGHT ThemeData ────────────
  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: goldDark,
      secondary: gold,
      surface: _lightSurface,
      onSurface: _lightOnBackground,
      error: error,
      onError: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lightBackground,
      textTheme: _buildTextTheme(_lightOnBackground, _lightOnSurfaceMuted),
      fontFamily: GoogleFonts.inter().fontFamily,
      dividerColor: _lightDivider,
      appBarTheme: AppBarTheme(
        backgroundColor: _lightSurfaceElevated,
        foregroundColor: _lightOnBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lightOnBackground,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightSurfaceElevated,
        selectedItemColor: goldDark,
        unselectedItemColor: _lightOnSurfaceMuted,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        hintStyle: GoogleFonts.inter(color: _lightOnSurfaceMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: goldDark,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldDark,
          side: const BorderSide(color: goldDark),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurface,
        selectedColor: goldDark.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.inter(fontSize: 13),
        side: BorderSide(color: _lightDivider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightOnBackground,
        contentTextStyle: GoogleFonts.inter(color: _lightSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
