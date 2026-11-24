/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Oversee';
  static const String appVersion = '1.0.0';

  // Storage keys
  static const String accessTokenKey = 'oversee_access_token';
  static const String refreshTokenKey = 'oversee_refresh_token';
  static const String userProfileKey = 'oversee_user_profile';
  static const String lastWorkspaceIdKey = 'oversee_last_workspace_id';
  static const String themeModeKey = 'oversee_theme_mode';
  static const String seedColorKey = 'oversee_seed_color';
  static const String sidebarExpandedKey = 'oversee_sidebar_expanded';
  static const String localeKey = 'oversee_locale';
  static const String appFontScalePercentKey = 'oversee_app_font_scale_percent';
  static const String contentFontScalePercentKey = 'oversee_content_font_scale_percent';

  // Pagination defaults
  static const int defaultPage = 1;
  static const int defaultPageSize = 20;

  // Responsive Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1440.0;
}
