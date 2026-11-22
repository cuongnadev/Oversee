import 'package:flutter/material.dart';

/// Oversee Design System Color Palette aligned with Figma tokens.css.
class AppColors {
  AppColors._();

  // Primary Brand Colors (Figma Violet Accent)
  static const Color primary = Color(0xFF7860E8); // --accent-solid (dark)
  static const Color primaryLight = Color(0xFFA292FF); // --accent (dark)
  static const Color primaryDark = Color(0xFF7054CF); // --accent (light)
  static const Color primarySolidLight = Color(0xFF7253D5); // --accent-solid (light)
  static const Color primaryHoverDark = Color(0xFF8B73F0); // --accent-hover (dark)
  static const Color primaryHoverLight = Color(0xFF6443C7); // --accent-hover (light)
  static const Color accentSoftDark = Color(0xFF29243E); // --accent-soft (dark)
  static const Color accentSoftLight = Color(0xFFEEE8FB); // --accent-soft (light)

  // Secondary Accent Colors
  static const Color secondary = Color(0xFF81A9F9); // --status-review (dark)
  static const Color secondaryLight = Color(0xFF6DBDC0); // --team-cyan (dark)
  static const Color secondaryDark = Color(0xFF2F5DB4); // --status-review (light)

  // Semantic Status Colors
  static const Color success = Color(0xFF187249); // --status-done (light)
  static const Color successDark = Color(0xFF66CDA1); // --status-done (dark)
  static const Color successLight = Color(0xFFE2F4EB); // --green-soft (light)
  static const Color greenSoftDark = Color(0xFF1A2D28); // --green-soft (dark)

  static const Color warning = Color(0xFFB75D1D); // --priority-high (light)
  static const Color warningDark = Color(0xFFEAC46C); // --status-progress (dark)
  static const Color warningLight = Color(0xFFF8EFDB); // --warning-soft (light)
  static const Color warningSoftDark = Color(0xFF352D20); // --warning-soft (dark)

  static const Color error = Color(0xFFC53E55); // --priority-critical (light)
  static const Color errorDark = Color(0xFFED818D); // --priority-critical (dark)
  static const Color errorLight = Color(0xFFFBE8EC); // --danger-soft (light)
  static const Color dangerSoftDark = Color(0xFF372127); // --danger-soft (dark)

  static const Color info = Color(0xFF2F5DB4); // --status-review (light)
  static const Color infoDark = Color(0xFF81A9F9); // --status-review (dark)
  static const Color infoLight = Color(0xFFDBEAFE);

  // Issue Status Colors (default/light-safe base; prefer *For(isDark) helpers)
  static const Color statusBacklog = Color(0xFF777184);
  static const Color statusTodo = Color(0xFF777184); // --status-todo (light)
  static const Color statusTodoDark = Color(0xFFA2A1AF); // --status-todo (dark)
  static const Color statusInProgress = Color(0xFF92701C); // --status-progress (light)
  static const Color statusInProgressDark = Color(0xFFEAC46C); // --status-progress (dark)
  static const Color statusInReview = Color(0xFF2F5DB4); // --status-review (light)
  static const Color statusInReviewDark = Color(0xFF81A9F9); // --status-review (dark)
  static const Color statusDone = Color(0xFF187249); // --status-done (light)
  static const Color statusDoneDark = Color(0xFF66CDA1); // --status-done (dark)
  static const Color statusCanceled = Color(0xFF93909F);

  // Issue Priority Colors (default/light-safe base; prefer *For(isDark) helpers)
  static const Color priorityLowest = Color(0xFF777184);
  static const Color priorityLow = Color(0xFF777184); // --priority-low (light)
  static const Color priorityLowDark = Color(0xFF9998A6); // --priority-low (dark)
  static const Color priorityMedium = Color(0xFF92701C); // --priority-medium (light)
  static const Color priorityMediumDark = Color(0xFFDFCB8C); // --priority-medium (dark)
  static const Color priorityHigh = Color(0xFFB75D1D); // --priority-high (light)
  static const Color priorityHighDark = Color(0xFFEEA26E); // --priority-high (dark)
  static const Color priorityUrgent = Color(0xFFC53E55); // --priority-critical (light)
  static const Color priorityUrgentDark = Color(0xFFED818D); // --priority-critical (dark)

  // Neutral Colors - Light Mode (Figma [data-theme='light'])
  static const Color bgLight = Color(0xFFF7F7FA); // --bg
  static const Color sidebarLight = Color(0xFFFFFFFF); // --sidebar
  static const Color surfaceLight = Color(0xFFFFFFFF); // --surface
  static const Color surface2Light = Color(0xFFF4F3F8); // --surface-2
  static const Color surface3Light = Color(0xFFEDEBF4); // --surface-3
  static const Color hoverLight = Color(0xFFF0EDF8); // --hover
  static const Color cardLight = Color(0xFFFFFFFF); // --surface
  static const Color borderLight = Color(0xFFE1DFE9); // --border
  static const Color borderSoftLight = Color(0xFFEEECF3); // --border-soft
  static const Color textPrimaryLight = Color(0xFF262333); // --text
  static const Color textSecondaryLight = Color(0xFF6D677D); // --muted
  static const Color textMutedLight = Color(0xFF655D73); // --subtle
  static const Color chartGridLight = Color(0xFFECE9F2); // --chart-grid

  // Neutral Colors - Dark Mode (Figma :root)
  static const Color bgDark = Color(0xFF101014); // --bg
  static const Color sidebarDark = Color(0xFF141418); // --sidebar
  static const Color surfaceDark = Color(0xFF19191F); // --surface
  static const Color surface2Dark = Color(0xFF1E1E25); // --surface-2
  static const Color surface3Dark = Color(0xFF26262F); // --surface-3
  static const Color hoverDark = Color(0xFF25242E); // --hover
  static const Color cardDark = Color(0xFF19191F); // --surface
  static const Color borderDark = Color(0xFF2C2C35); // --border
  static const Color borderSoftDark = Color(0xFF22222B); // --border-soft
  static const Color textPrimaryDark = Color(0xFFEEEEF3); // --text
  static const Color textSecondaryDark = Color(0xFFA2A1AF); // --muted
  static const Color textMutedDark = Color(0xFF93909F); // --subtle
  static const Color chartGridDark = Color(0xFF282832); // --chart-grid

  // Curated Figma Avatar Palette
  static const List<Color> avatarPalette = [
    Color(0xFF6D548F), // --avatar-violet
    Color(0xFF376F5A), // --avatar-green
    Color(0xFF906138), // --avatar-amber
    Color(0xFF8F4D75), // --avatar-pink
    Color(0xFF326B78), // --avatar-cyan
    Color(0xFF4E6297), // --avatar-blue
  ];

  // Design Radii Tokens (Figma --radius-*)
  static const double radiusSm = 4.0;
  static const double radiusMd = 7.0;
  static const double radiusLg = 10.0;
  static const double radiusXl = 14.0;

  // Brightness-aware token resolvers
  static Color bgFor(bool isDark) => isDark ? bgDark : bgLight;
  static Color sidebarFor(bool isDark) => isDark ? sidebarDark : sidebarLight;
  static Color surfaceFor(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color surface2For(bool isDark) => isDark ? surface2Dark : surface2Light;
  static Color surface3For(bool isDark) => isDark ? surface3Dark : surface3Light;
  static Color hoverFor(bool isDark) => isDark ? hoverDark : hoverLight;
  static Color borderFor(bool isDark) => isDark ? borderDark : borderLight;
  static Color borderSoftFor(bool isDark) => isDark ? borderSoftDark : borderSoftLight;
  static Color textPrimaryFor(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondaryFor(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textMutedFor(bool isDark) => isDark ? textMutedDark : textMutedLight;

  static Color accentFor(bool isDark) => isDark ? primaryLight : primaryDark;
  static Color accentSolidFor(bool isDark) => isDark ? primary : primarySolidLight;
  static Color accentSoftFor(bool isDark) => isDark ? accentSoftDark : accentSoftLight;

  static Color successFor(bool isDark) => isDark ? successDark : success;
  static Color greenSoftFor(bool isDark) => isDark ? greenSoftDark : successLight;
  static Color warningFor(bool isDark) => isDark ? warningDark : warning;
  static Color warningSoftFor(bool isDark) => isDark ? warningSoftDark : warningLight;
  static Color errorFor(bool isDark) => isDark ? errorDark : error;
  static Color dangerSoftFor(bool isDark) => isDark ? dangerSoftDark : errorLight;
  static Color infoFor(bool isDark) => isDark ? infoDark : info;
  static Color chartGridFor(bool isDark) => isDark ? chartGridDark : chartGridLight;
}
