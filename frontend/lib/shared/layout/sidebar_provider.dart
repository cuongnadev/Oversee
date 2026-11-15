import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/constants/app_constants.dart';

/// Provider managing sidebar expanded/collapsed state with persistence.
final sidebarExpandedProvider = StateNotifierProvider<SidebarNotifier, bool>((ref) {
  return SidebarNotifier();
});

class SidebarNotifier extends StateNotifier<bool> {
  SidebarNotifier() : super(true) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getBool(AppConstants.sidebarExpandedKey);
      if (savedState != null) {
        state = savedState;
      }
    } catch (_) {
      // SharedPreferences failure fallback to default true
    }
  }

  Future<void> toggleSidebar() async {
    state = !state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.sidebarExpandedKey, state);
    } catch (_) {}
  }

  Future<void> setExpanded(bool isExpanded) async {
    if (state != isExpanded) {
      state = isExpanded;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConstants.sidebarExpandedKey, state);
      } catch (_) {}
    }
  }
}
