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
  static const String workspaceCreate = '/workspaces/new';
  static const String workspaceDetail = '/workspaces/:workspaceId';
  static const String workspaceProjects = '/workspaces/:workspaceId/projects';
  static const String workspaceProjectCreate = '/workspaces/:workspaceId/projects/new';
  static const String workspaceSettings = '/workspaces/:workspaceId/settings';

  // Project routes under workspace
  static const String projectRoot = '/workspaces/:workspaceId/projects/:projectId';
  static const String projectInbox = '/workspaces/:workspaceId/projects/:projectId/inbox';
  static const String projectMyTasks = '/workspaces/:workspaceId/projects/:projectId/my-tasks';
  static const String projectOverview = '/workspaces/:workspaceId/projects/:projectId/overview';
  static const String projectBacklog = '/workspaces/:workspaceId/projects/:projectId/backlog';
  static const String projectIssues = '/workspaces/:workspaceId/projects/:projectId/issues';
  static const String projectBoard = '/workspaces/:workspaceId/projects/:projectId/board';
  static const String projectSprints = '/workspaces/:workspaceId/projects/:projectId/sprints';
  static const String projectSprintPlanning = '/workspaces/:workspaceId/projects/:projectId/sprints/planning';
  static const String projectRoadmap = '/workspaces/:workspaceId/projects/:projectId/roadmap';
  static const String projectTimeline = '/workspaces/:workspaceId/projects/:projectId/timeline';
  static const String projectCalendar = '/workspaces/:workspaceId/projects/:projectId/calendar';
  static const String projectInitiatives = '/workspaces/:workspaceId/projects/:projectId/initiatives';
  static const String projectDocuments = '/workspaces/:workspaceId/projects/:projectId/documents';
  static const String projectReports = '/workspaces/:workspaceId/projects/:projectId/reports';
  static const String projectAiAssistant = '/workspaces/:workspaceId/projects/:projectId/ai-assistant';
  static const String projectAutoSchedule = '/workspaces/:workspaceId/projects/:projectId/auto-schedule';
  static const String projectMembers = '/workspaces/:workspaceId/projects/:projectId/members';
  static const String projectNotifications = '/workspaces/:workspaceId/projects/:projectId/notifications';
  static const String projectIntegrations = '/workspaces/:workspaceId/projects/:projectId/integrations';
  static const String projectDashboard = '/workspaces/:workspaceId/projects/:projectId/dashboard';
  static const String projectSettings = '/workspaces/:workspaceId/projects/:projectId/settings';
  static const String projectApiDocs = '/workspaces/:workspaceId/projects/:projectId/api-docs';
  static const String projectDeveloper = '/workspaces/:workspaceId/projects/:projectId/developer';

  // Helper methods to build parameterized URLs
  static String workspaceDetailPath(String workspaceId) => '/workspaces/$workspaceId';
  static String workspaceProjectsPath(String workspaceId) => '/workspaces/$workspaceId/projects';
  static String workspaceProjectCreatePath(String workspaceId) => '/workspaces/$workspaceId/projects/new';
  static String workspaceSettingsPath(String workspaceId) => '/workspaces/$workspaceId/settings';
  static String projectInboxPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/inbox';
  static String projectMyTasksPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/my-tasks';
  static String projectOverviewPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/overview';
  static String projectBacklogPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/backlog';
  static String projectIssuesPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/issues';
  static String projectBoardPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/board';
  static String projectSprintsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/sprints';
  static String projectSprintPlanningPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/sprints/planning';
  static String projectRoadmapPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/roadmap';
  static String projectTimelinePath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/timeline';
  static String projectCalendarPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/calendar';
  static String projectInitiativesPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/initiatives';
  static String projectDocumentsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/documents';
  static String projectReportsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/reports';
  static String projectAiAssistantPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/ai-assistant';
  static String projectAutoSchedulePath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/auto-schedule';
  static String projectMembersPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/members';
  static String projectNotificationsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/notifications';
  static String projectIntegrationsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/integrations';
  static String projectDashboardPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/dashboard';
  static String projectSettingsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/settings';
  static String projectApiDocsPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/api-docs';
  static String projectDeveloperPath(String workspaceId, String projectId) =>
      '/workspaces/$workspaceId/projects/$projectId/developer';
}
