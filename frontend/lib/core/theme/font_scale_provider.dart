import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/constants/app_constants.dart';

/// Immutable dual font scale state stored as exact integer percentages.
///
/// Stepping is strictly additive in 10 percentage-point increments so that
/// decreasing from 100% -> 90% and then increasing by +10% yields 100%
/// (never 99% from multiplicative rounding).
class FontScaleState extends Equatable {
  static const int minPercent = 70;
  static const int maxPercent = 130;
  static const int stepPercent = 10;
  static const int defaultAppPercent = 100;
  static const int defaultContentPercent = 90;

  final int appPercent;
  final int contentPercent;

  const FontScaleState({
    this.appPercent = defaultAppPercent,
    this.contentPercent = defaultContentPercent,
  });

  double get appScale => appPercent / 100.0;
  double get contentScale => contentPercent / 100.0;

  /// Effective text scale factor applied inside the layout content pane.
  double get effectiveContentScale => (appPercent * contentPercent) / 10000.0;

  static int clampPercent(int value) {
    final snapped = ((value / stepPercent).round() * stepPercent);
    return snapped.clamp(minPercent, maxPercent);
  }

  static int stepDown(int current) => clampPercent(current - stepPercent);
  static int stepUp(int current) => clampPercent(current + stepPercent);

  FontScaleState copyWith({
    int? appPercent,
    int? contentPercent,
  }) {
    return FontScaleState(
      appPercent: appPercent != null ? clampPercent(appPercent) : this.appPercent,
      contentPercent: contentPercent != null ? clampPercent(contentPercent) : this.contentPercent,
    );
  }

  @override
  List<Object?> get props => [appPercent, contentPercent];
}

/// Provider managing both whole-app and content-pane font scale percentages.
final fontScaleProvider = StateNotifierProvider<FontScaleNotifier, FontScaleState>((ref) {
  return FontScaleNotifier();
});

class FontScaleNotifier extends StateNotifier<FontScaleState> {
  FontScaleNotifier({
    FontScaleState initialState = const FontScaleState(),
  }) : super(initialState) {
    _loadFontScales();
  }

  Future<void> _loadFontScales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedApp = prefs.getInt(AppConstants.appFontScalePercentKey);
      final savedContent = prefs.getInt(AppConstants.contentFontScalePercentKey);
      if ((savedApp != null || savedContent != null) && mounted) {
        state = state.copyWith(
          appPercent: savedApp,
          contentPercent: savedContent,
        );
      }
    } catch (_) {
      // Fallback to defaults on storage error.
    }
  }

  /// Commits both font scale values (used when the user confirms changes).
  Future<void> applyFontScales({
    required int appPercent,
    required int contentPercent,
  }) async {
    final next = FontScaleState(
      appPercent: FontScaleState.clampPercent(appPercent),
      contentPercent: FontScaleState.clampPercent(contentPercent),
    );
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.appFontScalePercentKey, next.appPercent);
      await prefs.setInt(AppConstants.contentFontScalePercentKey, next.contentPercent);
    } catch (_) {}
  }

  Future<void> decreaseAppFontSize() => applyFontScales(
        appPercent: FontScaleState.stepDown(state.appPercent),
        contentPercent: state.contentPercent,
      );

  Future<void> increaseAppFontSize() => applyFontScales(
        appPercent: FontScaleState.stepUp(state.appPercent),
        contentPercent: state.contentPercent,
      );

  Future<void> decreaseContentFontSize() => applyFontScales(
        appPercent: state.appPercent,
        contentPercent: FontScaleState.stepDown(state.contentPercent),
      );

  Future<void> increaseContentFontSize() => applyFontScales(
        appPercent: state.appPercent,
        contentPercent: FontScaleState.stepUp(state.contentPercent),
      );

  Future<void> resetToDefaults() => applyFontScales(
        appPercent: FontScaleState.defaultAppPercent,
        contentPercent: FontScaleState.defaultContentPercent,
      );
}
