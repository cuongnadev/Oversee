/// Route path and name definitions for Oversee application.
class AppRoutes {
  AppRoutes._();

  // Root
  static const String root = '/';

  // Auth routes
  static const String login = '/login';
  static const String register = '/register';

  // Workspace routes
  static const String workspaces = '/workspaces';
  static const String workspaceDetail = '/workspaces/:workspaceId';
  static const String workspaceSettings = '/workspaces/:workspaceId/settings';

  // Project routes under workspace
  static const String projectRoot = '/workspaces/:workspaceId/projects/:projectId';
  static const String projectOverview = '/workspaces/:workspaceId/projects/:projectId/overview';
  static const String projectBacklog = '/workspaces/:workspaceId/projects/:projectId/backlog';
  static const String projectBoard = '/workspaces/:workspaceId/projects/:projectId/board';
  static const String projectSprints = '/workspaces/:workspaceId/projects/:projectId/sprints';
  static const String projectDashboard = '/workspaces/:workspaceId/projects/:projectId/dashboard';
  static const String projectSettings = '/workspaces/:workspaceId/projects/:projectId/settings';

  // Helper methods to build parameterized URLs
  static String workspaceDetailPath(String workspaceId) => '/workspaces/$workspaceId';
  static String workspaceSettingsPath(String workspaceId) => '/workspaces/$workspaceId/settings';
  static String projectOverviewPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/overview';
  static String projectBacklogPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/backlog';
  static String projectBoardPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/board';
  static String projectSprintsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/sprints';
  static String projectDashboardPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/dashboard';
  static String projectSettingsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/settings';
}
