import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Provider for managing the active application Locale (English / Vietnamese).
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier({Locale initialLocale = AppLocalizations.en}) : super(initialLocale) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(AppConstants.localeKey);
      if (saved == 'vi' && mounted) {
        state = AppLocalizations.vi;
      } else if (saved == 'en' && mounted) {
        state = AppLocalizations.en;
      }
    } catch (_) {
      // Fallback to English when storage is unavailable (e.g. unit tests).
    }
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = locale.languageCode == 'vi' ? AppLocalizations.vi : AppLocalizations.en;
    state = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.localeKey, normalized.languageCode);
    } catch (_) {}
  }

  Future<void> toggleLocale() async {
    await setLocale(state.languageCode == 'vi' ? AppLocalizations.en : AppLocalizations.vi);
  }
}
