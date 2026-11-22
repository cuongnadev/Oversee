import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/not_found_screen.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/presentation/login_screen.dart';
import 'package:frontend/features/auth/presentation/register_screen.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:frontend/features/issue/presentation/backlog_screen.dart';
import 'package:frontend/features/issue/presentation/calendar_screen.dart';
import 'package:frontend/features/issue/presentation/issues_list_screen.dart';
import 'package:frontend/features/issue/presentation/timeline_screen.dart';
import 'package:frontend/features/project/presentation/create_project_screen.dart';
import 'package:frontend/features/project/presentation/project_feature_empty_screen.dart';
import 'package:frontend/features/project/presentation/project_list_screen.dart';
import 'package:frontend/features/project/presentation/project_overview_screen.dart';
import 'package:frontend/features/project/presentation/project_settings_screen.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/features/sprint/presentation/kanban_board_screen.dart';
import 'package:frontend/features/sprint/presentation/sprint_overview_screen.dart';
import 'package:frontend/features/sprint/presentation/sprint_planning_screen.dart';
import 'package:frontend/features/workspace/presentation/create_workspace_screen.dart';
import 'package:frontend/features/workspace/presentation/workspace_list_screen.dart';
import 'package:frontend/features/workspace/presentation/workspace_settings_screen.dart';
import 'package:frontend/shared/layout/responsive_app_shell.dart';

class _ProjectShellMeta {
  final String routeKey;
  final String title;
  const _ProjectShellMeta(this.routeKey, this.title);
}

_ProjectShellMeta _resolveProjectShellMeta(String location) {
  if (location.endsWith('/sprints/planning')) {
    return const _ProjectShellMeta('planning', 'Sprint Planning');
  }
  final segment = location.split('/').where((s) => s.isNotEmpty).lastOrNull ?? 'overview';
  switch (segment) {
    case 'inbox':
      return const _ProjectShellMeta('inbox', 'Inbox');
    case 'my-tasks':
      return const _ProjectShellMeta('my_tasks', 'My Tasks');
    case 'overview':
      return const _ProjectShellMeta('overview', 'Overview');
    case 'board':
      return const _ProjectShellMeta('board', 'Board');
    case 'backlog':
      return const _ProjectShellMeta('backlog', 'Product Backlog');
    case 'issues':
      return const _ProjectShellMeta('issues', 'Issues');
    case 'sprints':
      return const _ProjectShellMeta('sprints', 'Sprints');
    case 'roadmap':
      return const _ProjectShellMeta('roadmap', 'Roadmap');
    case 'timeline':
      return const _ProjectShellMeta('timeline', 'Timeline');
    case 'calendar':
      return const _ProjectShellMeta('calendar', 'Calendar');
    case 'initiatives':
      return const _ProjectShellMeta('initiatives', 'Initiatives & Epics');
    case 'documents':
      return const _ProjectShellMeta('documents', 'Documents');
    case 'reports':
      return const _ProjectShellMeta('reports', 'Reports');
    case 'ai-assistant':
      return const _ProjectShellMeta('ai_assistant', 'AI Assistant');
    case 'auto-schedule':
      return const _ProjectShellMeta('auto_schedule', 'Auto Schedule');
    case 'members':
      return const _ProjectShellMeta('members', 'Members');
    case 'notifications':
      return const _ProjectShellMeta('notifications', 'Notifications');
    case 'integrations':
      return const _ProjectShellMeta('integrations', 'Integrations');
    case 'dashboard':
      return const _ProjectShellMeta('dashboard', 'Dashboard');
    case 'settings':
      return const _ProjectShellMeta('settings', 'Project Settings');
    case 'api-docs':
      return const _ProjectShellMeta('api_docs', 'API Docs');
    case 'developer':
      return const _ProjectShellMeta('developer', 'Developer / MCP');
    default:
      return const _ProjectShellMeta('overview', 'Overview');
  }
}

Page<void> _innerPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerListenable = ref.watch(routerListenableProvider);

  return GoRouter(
    initialLocation: AppRoutes.workspaces,
    refreshListenable: routerListenable,
    debugLogDiagnostics: false,
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri.toString()),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;
      final isAuthRoute = location == AppRoutes.login || location == AppRoutes.register;

      // Allow initial session restoration to resolve without premature redirection
      if (authState.status == AuthStatus.initial) {
        return null;
      }

      final isAuthenticated = authState.isAuthenticated;

      // If user is not authenticated and trying to access protected route
      if (!isAuthenticated) {
        if (isAuthRoute) return null;
        return AppRoutes.login;
      }

      // If user is authenticated and trying to access login/register or root
      if (isAuthRoute || location == AppRoutes.root) {
        return AppRoutes.workspaces;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (context, state) => AppRoutes.workspaces,
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.workspaces,
        builder: (context, state) => const WorkspaceListScreen(),
      ),
      // Declared before `/workspaces/:workspaceId` so `new` is not captured as a workspaceId.
      GoRoute(
        path: AppRoutes.workspaceCreate,
        builder: (context, state) => const CreateWorkspaceScreen(),
      ),
      GoRoute(
        path: AppRoutes.workspaceDetail,
        redirect: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          return AppRoutes.workspaceProjectsPath(workspaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.workspaceProjects,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          return ProjectListScreen(workspaceId: workspaceId);
        },
      ),
      // Declared before `/workspaces/:workspaceId/projects/:projectId` so `new` is not captured.
      GoRoute(
        path: AppRoutes.workspaceProjectCreate,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          return CreateProjectScreen(workspaceId: workspaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.workspaceSettings,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId'] ?? 'default';
          return WorkspaceSettingsScreen(workspaceId: workspaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.projectRoot,
        redirect: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          final projectId = state.pathParameters['projectId']!;
          return AppRoutes.projectOverviewPath(workspaceId, projectId);
        },
      ),

      // Persistent Project Shell: keeps outer sidebar & top AppBar stationary and only swaps inner content.
      ShellRoute(
        builder: (context, state, child) {
          final workspaceId = state.pathParameters['workspaceId'] ?? '';
          final projectId = state.pathParameters['projectId'] ?? '';
          final meta = _resolveProjectShellMeta(state.matchedLocation);
          return ProjectShellScope(
            child: ResponsiveAppShell(
              workspaceId: workspaceId,
              projectId: projectId,
              currentRoute: meta.routeKey,
              title: meta.title,
              body: child,
            ),
          );
        },
        routes: [
          // WORKSPACE group routes
          GoRoute(
            path: AppRoutes.projectInbox,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'inbox',
                  sectionEyebrow: 'Workspace',
                  title: 'Inbox',
                  subtitle: 'Mentions, review requests, and issue updates directed to you.',
                  icon: Icons.inbox_outlined,
                  emptyTitle: 'Your Inbox is Clear',
                  emptyDescription:
                      'You have no unread mentions, assignments, or status updates in this project yet.',
                  primaryActionLabel: 'Open Kanban Board',
                  primaryActionIcon: Icons.view_kanban_outlined,
                  primaryActionPath: AppRoutes.projectBoardPath(workspaceId, projectId),
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectMyTasks,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'my_tasks',
                  sectionEyebrow: 'Workspace',
                  title: 'My Tasks',
                  subtitle: 'Personal queue of issues assigned to you across sprints and backlog.',
                  icon: Icons.checklist_rounded,
                  emptyTitle: 'No Tasks Assigned Yet',
                  emptyDescription:
                      'Issues assigned to you will appear here with due dates, priorities, and sprint context.',
                  primaryActionLabel: 'Browse Backlog',
                  primaryActionIcon: Icons.layers_outlined,
                  primaryActionPath: AppRoutes.projectBacklogPath(workspaceId, projectId),
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectOverview,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectOverviewScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),

          // PLANNING group routes
          GoRoute(
            path: AppRoutes.projectBoard,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                KanbanBoardScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectBacklog,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                BacklogScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectIssues,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                IssuesListScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectSprints,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                SprintOverviewScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectSprintPlanning,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                SprintPlanningScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectRoadmap,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'roadmap',
                  sectionEyebrow: 'Planning',
                  title: 'Roadmap',
                  subtitle: 'High-level milestones, release quarters, and strategic delivery targets.',
                  icon: Icons.flag_outlined,
                  emptyTitle: 'No Roadmap Milestones Yet',
                  emptyDescription:
                      'Plan upcoming releases and quarterly goals once roadmap milestones are configured.',
                  primaryActionLabel: 'Go to Sprints',
                  primaryActionIcon: Icons.timer_outlined,
                  primaryActionPath: AppRoutes.projectSprintsPath(workspaceId, projectId),
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectTimeline,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                TimelineScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectCalendar,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                CalendarScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectInitiatives,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'initiatives',
                  sectionEyebrow: 'Planning',
                  title: 'Initiatives & Epics',
                  subtitle: 'Group cross-sprint work streams and track parent epic completion.',
                  icon: Icons.account_tree_outlined,
                  emptyTitle: 'No Initiatives or Epics',
                  emptyDescription:
                      'Create initiatives and epics to connect strategic objectives with backlog issues.',
                  primaryActionLabel: 'View Backlog',
                  primaryActionIcon: Icons.layers_outlined,
                  primaryActionPath: AppRoutes.projectBacklogPath(workspaceId, projectId),
                ),
              );
            },
          ),

          // KNOWLEDGE group routes
          GoRoute(
            path: AppRoutes.projectDocuments,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'documents',
                  sectionEyebrow: 'Knowledge',
                  title: 'Documents',
                  subtitle: 'Technical specs, RFCs, meeting notes, and architecture decisions.',
                  icon: Icons.description_outlined,
                  emptyTitle: 'No Documents Yet',
                  emptyDescription:
                      'Project specs, runbooks, and design documentation will live in this knowledge hub.',
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectReports,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'reports',
                  sectionEyebrow: 'Knowledge',
                  title: 'Reports',
                  subtitle: 'Velocity trends, cycle time breakdowns, and exportable sprint summaries.',
                  icon: Icons.bar_chart_outlined,
                  emptyTitle: 'No Saved Reports Yet',
                  emptyDescription:
                      'Generate custom delivery reports or inspect live burndown metrics in the Sprint Dashboard.',
                  primaryActionLabel: 'Open Sprint Dashboard',
                  primaryActionIcon: Icons.space_dashboard_outlined,
                  primaryActionPath: AppRoutes.projectDashboardPath(workspaceId, projectId),
                ),
              );
            },
          ),

          // AI TEAM group routes
          GoRoute(
            path: AppRoutes.projectAiAssistant,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'ai_assistant',
                  sectionEyebrow: 'AI Team',
                  title: 'AI Assistant',
                  subtitle: 'Ask questions about sprint risk, summarize specs, and triage backlog items.',
                  badgeLabel: 'BETA',
                  icon: Icons.auto_awesome_outlined,
                  emptyTitle: 'AI Assistant Ready Soon',
                  emptyDescription:
                      'Start a conversation to summarize sprint blockers, draft acceptance criteria, and estimate scope.',
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectAutoSchedule,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'auto_schedule',
                  sectionEyebrow: 'AI Team',
                  title: 'Auto Schedule',
                  subtitle: 'Automated capacity balancing and sprint allocation recommendations.',
                  icon: Icons.schedule_outlined,
                  emptyTitle: 'No Auto-Schedule Rules Configured',
                  emptyDescription:
                      'Configure team capacity and priority rules to automatically propose balanced sprint plans.',
                ),
              );
            },
          ),

          // CONFIGURATION group routes
          GoRoute(
            path: AppRoutes.projectMembers,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'members',
                  sectionEyebrow: 'Configuration',
                  title: 'Members',
                  subtitle: 'Project collaborators, team roles, and workspace membership permissions.',
                  icon: Icons.people_outline_rounded,
                  emptyTitle: 'Dedicated Members Directory',
                  emptyDescription:
                      'Manage project-level collaborators in Project Settings or organization roles in Workspace Settings.',
                  primaryActionLabel: 'Open Project Settings',
                  primaryActionIcon: Icons.tune_rounded,
                  primaryActionPath: AppRoutes.projectSettingsPath(workspaceId, projectId),
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectNotifications,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'notifications',
                  sectionEyebrow: 'Configuration',
                  title: 'Notifications',
                  subtitle: 'Configure alert channels, digest cadence, and issue event triggers.',
                  icon: Icons.notifications_none_rounded,
                  emptyTitle: 'No Notification Rules Yet',
                  emptyDescription:
                      'Customize in-app, email, and webhook alerts for sprint transitions and mentions.',
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectIntegrations,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'integrations',
                  sectionEyebrow: 'Configuration',
                  title: 'Integrations',
                  subtitle: 'Connect GitHub, Slack, CI pipelines, and external issue trackers.',
                  icon: Icons.hub_outlined,
                  emptyTitle: 'No Integrations Connected',
                  emptyDescription:
                      'Link repositories, pull requests, and chat notifications to automate project updates.',
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectDashboard,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                DashboardScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectSettings,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectSettingsScreen(workspaceId: workspaceId, projectId: projectId),
              );
            },
          ),

          // Bottom utility routes (Figma 1:273)
          GoRoute(
            path: AppRoutes.projectApiDocs,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'api_docs',
                  sectionEyebrow: 'Resources',
                  title: 'API Docs',
                  subtitle: 'REST endpoints, authentication tokens, and interactive API reference.',
                  icon: Icons.menu_book_outlined,
                  emptyTitle: 'API Reference Portal',
                  emptyDescription:
                      'Endpoint schemas, webhook payloads, and SDK examples for automating Oversee will appear here.',
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.projectDeveloper,
            pageBuilder: (context, state) {
              final workspaceId = state.pathParameters['workspaceId']!;
              final projectId = state.pathParameters['projectId']!;
              return _innerPage(
                state,
                ProjectFeatureEmptyScreen(
                  workspaceId: workspaceId,
                  projectId: projectId,
                  routeKey: 'developer',
                  sectionEyebrow: 'Resources',
                  title: 'Developer / MCP',
                  subtitle: 'API keys, Model Context Protocol endpoints, and developer tooling.',
                  badgeLabel: 'DEV',
                  icon: Icons.terminal_outlined,
                  emptyTitle: 'No Developer Tokens Yet',
                  emptyDescription:
                      'Create personal access tokens and configure MCP servers for AI-assisted project workflows.',
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
});
