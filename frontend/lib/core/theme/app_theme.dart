import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';

/// Oversee Material 3 Themes (Light & Dark) aligned with Figma Design System
/// and driven synchronously by the user's selected seed color.
class AppTheme {
  AppTheme._();

  /// Default/current Light Theme getter for backwards compatibility.
  static ThemeData get lightTheme => buildLightTheme(AppColors.currentSeedColor);

  /// Default/current Dark Theme getter for backwards compatibility.
  static ThemeData get darkTheme => buildDarkTheme(AppColors.currentSeedColor);

  /// Builds Light Theme derived from [seedColor].
  static ThemeData buildLightTheme(Color seedColor) {
    final palette = SeedAccentPalette.fromSeed(seedColor);
    final textTheme = AppTypography.createTextTheme(
      primaryColor: AppColors.textPrimaryLight,
      secondaryColor: AppColors.textSecondaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      primaryColor: palette.primarySolidLight,
      focusColor: palette.primaryDark.withValues(alpha: 0.14),
      hoverColor: AppColors.hoverLight,
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: textTheme,
      colorScheme: ColorScheme.light(
        primary: palette.primarySolidLight,
        onPrimary: Colors.white,
        primaryContainer: palette.accentSoftLight,
        onPrimaryContainer: palette.primaryDark,
        secondary: AppColors.secondaryDark,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
        surfaceContainerLowest: AppColors.surfaceLight,
        surfaceContainerLow: AppColors.bgLight,
        surfaceContainer: AppColors.surface2Light,
        surfaceContainerHigh: AppColors.surface3Light,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderSoftLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x2630204A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        clipBehavior: Clip.antiAlias,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimaryLight,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primarySolidLight,
          foregroundColor: Colors.white,
          minimumSize: const Size(84, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          backgroundColor: AppColors.surface2Light,
          minimumSize: const Size(84, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          side: const BorderSide(color: AppColors.borderLight),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: palette.primaryDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(color: AppColors.textMutedLight, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primarySolidLight;
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.borderLight, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5)),
      ),
    );
  }

  /// Builds Dark Theme derived from [seedColor].
  static ThemeData buildDarkTheme(Color seedColor) {
    final palette = SeedAccentPalette.fromSeed(seedColor);
    final textTheme = AppTypography.createTextTheme(
      primaryColor: AppColors.textPrimaryDark,
      secondaryColor: AppColors.textSecondaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      primaryColor: palette.primaryLight,
      focusColor: palette.primaryLight.withValues(alpha: 0.2),
      hoverColor: AppColors.hoverDark,
      scaffoldBackgroundColor: AppColors.bgDark,
      textTheme: textTheme,
      colorScheme: ColorScheme.dark(
        primary: palette.primaryLight,
        onPrimary: Colors.white,
        primaryContainer: palette.accentSoftDark,
        onPrimaryContainer: palette.primaryLight,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        error: AppColors.errorDark,
        onError: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
        surfaceContainerLowest: AppColors.bgDark,
        surfaceContainerLow: AppColors.sidebarDark,
        surfaceContainer: AppColors.surface2Dark,
        surfaceContainerHigh: AppColors.surface3Dark,
        outline: AppColors.borderDark,
        outlineVariant: AppColors.borderSoftDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: const Color(0x88000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        clipBehavior: Clip.antiAlias,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surface3Dark,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderDark),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 11.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(84, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          backgroundColor: AppColors.surface2Dark,
          minimumSize: const Size(84, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          side: const BorderSide(color: AppColors.borderDark),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: palette.primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.errorDark),
        ),
        hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primary;
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.borderDark, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5)),
      ),
    );
  }
}
