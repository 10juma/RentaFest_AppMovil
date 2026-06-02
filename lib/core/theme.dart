import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color accent = Color(0xFF6C63FF);
  static const Color coral = Color(0xFFFF6584);
  static const Color mint = Color(0xFF43C6AC);
  static const Color darkBg = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color lightBg = Color(0xFFF5F6FA);
  static const Color red = Color(0xFFFF0000);
  static const Color green = Color(0xFF00FF00);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        secondary: AppColors.coral,
        tertiary: AppColors.mint,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.coral,
        tertiary: AppColors.mint,
        surface: AppColors.darkSurface,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
    );
  }
}
