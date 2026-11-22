/// API constants and endpoint definitions for Oversee Backend.
class ApiConstants {
  ApiConstants._();

  /// Base URL configured via compile-time environment variable, defaults to VPS FastAPI server.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://157.230.246.22/route/api/v1',
  );

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Endpoints
  static const String health = '/health';

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String currentUser = '/users/me';

  // Workspace endpoints
  static const String workspaces = '/workspaces';

  // Project endpoints
  static const String projects = '/projects';

  // Issue endpoints
  static const String issues = '/issues';

  // Sprint endpoints
  static const String sprints = '/sprints';

  // Document endpoints
  static const String documents = '/documents';
}
