import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Named curated seed color preset for Oversee theme customization.
class SeedColorPreset {
  final String name;
  final Color color;

  const SeedColorPreset({required this.name, required this.color});
}

/// Curated list of accessible brand seed colors (Figma Violet is default).
const List<SeedColorPreset> appSeedColorPresets = [
  SeedColorPreset(name: 'Violet', color: AppColors.defaultSeedColor),
  SeedColorPreset(name: 'Indigo', color: Color(0xFF4F46E5)),
  SeedColorPreset(name: 'Ocean', color: Color(0xFF2563EB)),
  SeedColorPreset(name: 'Teal', color: Color(0xFF0D9488)),
  SeedColorPreset(name: 'Emerald', color: Color(0xFF059669)),
  SeedColorPreset(name: 'Amber', color: Color(0xFFD97706)),
  SeedColorPreset(name: 'Rose', color: Color(0xFFE11D48)),
  SeedColorPreset(name: 'Slate', color: Color(0xFF475569)),
];

/// Provider for managing ThemeMode across the application.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(AppConstants.themeModeKey);
      if (savedMode != null) {
        if (savedMode == 'dark') {
          state = ThemeMode.dark;
        } else if (savedMode == 'light') {
          state = ThemeMode.light;
        } else {
          state = ThemeMode.system;
        }
      }
    } catch (_) {
      // Default to system on storage failure
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String value = 'system';
      if (mode == ThemeMode.dark) value = 'dark';
      if (mode == ThemeMode.light) value = 'light';
      await prefs.setString(AppConstants.themeModeKey, value);
    } catch (_) {}
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}

/// Provider for managing the application-wide primary seed color.
final seedColorProvider = StateNotifierProvider<SeedColorNotifier, Color>((ref) {
  return SeedColorNotifier();
});

class SeedColorNotifier extends StateNotifier<Color> {
  SeedColorNotifier({Color initialColor = AppColors.defaultSeedColor}) : super(initialColor) {
    AppColors.applySeedColor(initialColor);
    _loadSeedColor();
  }

  Future<void> _loadSeedColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedArgb = prefs.getInt(AppConstants.seedColorKey);
      if (savedArgb != null) {
        final color = Color(savedArgb);
        AppColors.applySeedColor(color);
        if (mounted) {
          state = color;
        }
      }
    } catch (_) {
      // Fallback to default seed color
    }
  }

  Future<void> setSeedColor(Color color) async {
    final opaqueColor = color.withValues(alpha: 1.0);
    AppColors.applySeedColor(opaqueColor);
    state = opaqueColor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.seedColorKey, opaqueColor.toARGB32());
    } catch (_) {}
  }

  Future<void> resetToDefault() async {
    await setSeedColor(AppColors.defaultSeedColor);
  }
}
