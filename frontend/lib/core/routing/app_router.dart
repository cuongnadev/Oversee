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
import 'package:frontend/features/project/presentation/project_overview_screen.dart';
import 'package:frontend/features/project/presentation/project_settings_screen.dart';
import 'package:frontend/features/sprint/presentation/kanban_board_screen.dart';
import 'package:frontend/features/sprint/presentation/sprint_planning_screen.dart';
import 'package:frontend/features/workspace/presentation/workspace_list_screen.dart';
import 'package:frontend/features/workspace/presentation/workspace_settings_screen.dart';

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
      GoRoute(
        path: AppRoutes.projectOverview,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          final projectId = state.pathParameters['projectId']!;
          return ProjectOverviewScreen(workspaceId: workspaceId, projectId: projectId);
        },
      ),
      GoRoute(
        path: AppRoutes.projectBacklog,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          final projectId = state.pathParameters['projectId']!;
          return BacklogScreen(workspaceId: workspaceId, projectId: projectId);
        },
      ),
      GoRoute(
        path: AppRoutes.projectBoard,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          final projectId = state.pathParameters['projectId']!;
          return KanbanBoardScreen(workspaceId: workspaceId, projectId: projectId);
        },
      ),
      GoRoute(
        path: AppRoutes.projectSprints,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          final projectId = state.pathParameters['projectId']!;
          return SprintPlanningScreen(workspaceId: workspaceId, projectId: projectId);
        },
      ),
      GoRoute(
        path: AppRoutes.projectDashboard,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          final projectId = state.pathParameters['projectId']!;
          return DashboardScreen(workspaceId: workspaceId, projectId: projectId);
        },
      ),
      GoRoute(
        path: AppRoutes.projectSettings,
        builder: (context, state) {
          final workspaceId = state.pathParameters['workspaceId']!;
          final projectId = state.pathParameters['projectId']!;
          return ProjectSettingsScreen(workspaceId: workspaceId, projectId: projectId);
        },
      ),
    ],
  );
});
