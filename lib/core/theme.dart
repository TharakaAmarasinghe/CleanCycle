import 'package:flutter/material.dart';

/// Central design tokens. Never hard-code a color or spacing value in a
/// screen — reference these instead, so the whole app stays consistent
/// and a palette change is a one-file edit.
class AppColors {
  static const primaryGreen = Color(0xFF2F6B45);
  static const darkGreen = Color(0xFF1E4A30);
  static const lightGreen = Color(0xFFE5EFE3);
  static const accentAmber = Color(0xFFB9822C); // offline/pending states ONLY
  static const background = Color(0xFFFAF8F2);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF20241F);
  static const textSecondary = Color(0xFF565A4F);
  static const success = Color(0xFF2F6B45);
  static const warning = Color(0xFFB9822C);
  static const error = Color(0xFFA63D3D);
  static const border = Color(0xFFE1DDD0);
  // Category colours for charts. Amber is deliberately not used here.
  static const categoryPlastic = Color(0xFF2F6B45);
  static const categoryGlass = Color(0xFF2B6CA3);
  static const categoryPaper = Color(0xFF7A8F3A);
  static const categoryMetal = Color(0xFF6B7280);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const full = 999.0;
}

/// Minimum touch target size — every interactive control should be at
/// least this tall/wide, per the constrained-design requirement.
const double kMinTouchTarget = 48.0;

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      primary: AppColors.primaryGreen,
      secondary: AppColors.accentAmber,
      error: AppColors.error,
      surface: AppColors.surface,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      headlineSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 15, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(kMinTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
        minimumSize: const Size.fromHeight(kMinTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    ),
  );
}