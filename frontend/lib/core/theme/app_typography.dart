import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Oversee Typography standards aligned with Figma Inter type scale.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';
  static const List<String> fontFallback = ['Inter', 'Segoe UI', 'Roboto', 'sans-serif'];
  static const List<String> monoFallback = ['SFMono-Regular', 'Consolas', 'monospace'];

  static TextStyle eyebrow(bool isDark) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.3,
        color: AppColors.textMutedFor(isDark),
      );

  static TextStyle mono(bool isDark, {double fontSize = 11, Color? color, FontWeight? fontWeight}) => TextStyle(
        fontFamily: 'Consolas',
        fontFamilyFallback: monoFallback,
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color ?? AppColors.textMutedFor(isDark),
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextTheme createTextTheme({required Color primaryColor, required Color secondaryColor}) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.9,
        height: 1.2,
        color: primaryColor,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 27,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        height: 1.25,
        color: primaryColor,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.7,
        height: 1.25,
        color: primaryColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.3,
        color: primaryColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.35,
        color: primaryColor,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.35,
        color: primaryColor,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.4,
        color: primaryColor,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
        color: secondaryColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
        color: primaryColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
        color: primaryColor,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.45,
        color: secondaryColor,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: primaryColor,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: secondaryColor,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: secondaryColor,
      ),
    );
  }
}
