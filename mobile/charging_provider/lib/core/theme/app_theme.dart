
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Typography
  static const String headlineFont = 'Comfortaa';
  static const String bodyFont = 'Questrial';
  static const String labelFont = 'Outfit';

  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.black,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.neutral900,
      error: AppColors.error,
      onError: AppColors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      isDark: false,
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.black,
      secondary: Color(0xFF91BB80),
      onSecondary: AppColors.black,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.neutral900,
      error: Color(0xFFFF8A80),
      onError: AppColors.black,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      isDark: true,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    final border = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    final secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final baseTextTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    ).textTheme;

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontFamily: headlineFont,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontFamily: headlineFont,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: headlineFont,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: headlineFont,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontFamily: bodyFont,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontFamily: bodyFont,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontFamily: bodyFont,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontFamily: labelFont,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontFamily: labelFont,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontFamily: labelFont,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: bodyFont,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: labelFont,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: labelFont,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        hintStyle: TextStyle(color: secondaryText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: labelFont,
            fontSize: 12,
            color: colorScheme.onSurface,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
