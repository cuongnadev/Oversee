import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/constants/app_constants.dart';

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

/// Service for managing local non-sensitive application preferences and cache
/// backed by SharedPreferences with in-memory fallback for test harnesses.
class PreferencesService {
  SharedPreferences? _prefs;
  final Map<String, dynamic> _memoryCache = {};

  PreferencesService([this._prefs]);

  Future<SharedPreferences> _getInstance() async {
    if (_prefs != null) return _prefs!;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs!;
    } catch (_) {
      // Return null or handle environments without plugins
      rethrow;
    }
  }

  /// Saves the last active workspace ID for quick session restoration.
  Future<void> saveLastWorkspaceId(String workspaceId) async {
    _memoryCache[AppConstants.lastWorkspaceIdKey] = workspaceId;
    try {
      final prefs = await _getInstance();
      await prefs.setString(AppConstants.lastWorkspaceIdKey, workspaceId);
    } catch (_) {}
  }

  /// Retrieves the last active workspace ID, if previously stored.
  Future<String?> getLastWorkspaceId() async {
    try {
      final prefs = await _getInstance();
      return prefs.getString(AppConstants.lastWorkspaceIdKey) ??
          _memoryCache[AppConstants.lastWorkspaceIdKey] as String?;
    } catch (_) {
      return _memoryCache[AppConstants.lastWorkspaceIdKey] as String?;
    }
  }

  /// Clears the stored last workspace ID.
  Future<void> clearLastWorkspaceId() async {
    _memoryCache.remove(AppConstants.lastWorkspaceIdKey);
    try {
      final prefs = await _getInstance();
      await prefs.remove(AppConstants.lastWorkspaceIdKey);
    } catch (_) {}
  }
}
