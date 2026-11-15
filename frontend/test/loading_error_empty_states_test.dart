import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/shared/widgets/widgets.dart';

class FakeTestSprintRepo implements SprintRepository {
  bool shouldThrow = false;
  String? throwMessage;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<SprintModel>> listProjectSprints(String projectId, {SprintStatus? status}) async {
    if (shouldThrow) {
      throw NetworkException(message: throwMessage ?? 'Failed to connect to backend server');
    }
    return [];
  }
}

class FakeTestProjectRepo implements ProjectRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async {
    return const ProjectModel(id: 'proj-1', workspaceId: 'ws-1', name: 'Oversee', key: 'OVS');
  }

  @override
  Future<List<ProjectMemberModel>> listProjectMembers(String projectId) async => [];
}

class FakeTestWorkspaceRepo implements WorkspaceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async {
    return [const WorkspaceModel(id: 'ws-1', name: 'WS', slug: 'ws', ownerId: 'u1')];
  }
}

class FakeTestStorageService implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<String?> getAccessToken() async => 'fake-token';
  @override
  Future<String?> getRefreshToken() async => 'fake-refresh';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child, {bool isDark = false}) {
    return MaterialApp(
      theme: ThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
      home: Scaffold(body: child),
    );
  }

  group('AppSkeleton & Shimmer Presets Tests', () {
    testWidgets('AppSkeleton renders rectangular and circular shimmer blocks', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            children: [
              AppSkeleton(width: 150, height: 20),
              AppSkeleton.circle(size: 40),
              AppSkeleton.card(height: 80),
            ],
          ),
        ),
      );

      expect(find.byType(AppSkeleton), findsNWidgets(3));
    });

    testWidgets('DashboardSkeleton renders all placeholder components', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapWithTheme(const DashboardSkeleton()));

      expect(find.byType(DashboardSkeleton), findsOneWidget);
      expect(find.byType(AppSkeleton), findsWidgets);
    });

    testWidgets('KanbanBoardSkeleton renders columns and cards shimmer', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapWithTheme(const KanbanBoardSkeleton()));

      expect(find.byType(KanbanBoardSkeleton), findsOneWidget);
      expect(find.byType(AppSkeleton), findsWidgets);
    });

    testWidgets('BacklogSkeleton renders header, quick create, and rows', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const BacklogSkeleton(rowCount: 4)));

      expect(find.byType(BacklogSkeleton), findsOneWidget);
      expect(find.byType(AppSkeleton), findsWidgets);
    });

    testWidgets('ProjectGridSkeleton renders grid cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapWithTheme(const ProjectGridSkeleton(count: 4)));

      expect(find.byType(ProjectGridSkeleton), findsOneWidget);
      expect(find.byType(AppSkeleton), findsWidgets);
    });

    testWidgets('MemberListSkeleton renders member row placeholders', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const MemberListSkeleton(count: 3)));

      expect(find.byType(MemberListSkeleton), findsOneWidget);
      expect(find.byType(AppSkeleton), findsWidgets);
    });
  });

  group('AppErrorView & Error Classification Tests', () {
    testWidgets('classifies NetworkException with wifi_off icon and retry button', (tester) async {
      bool retried = false;
      const netError = NetworkException(message: 'Connection timed out');

      await tester.pumpWidget(
        wrapWithTheme(
          AppErrorView(
            error: netError,
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Network Connection Lost'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('classifies ServerException (500) with dns icon', (tester) async {
      const serverErr = ServerException(message: 'Internal Database Failure');

      await tester.pumpWidget(
        wrapWithTheme(
          const AppErrorView(error: serverErr),
        ),
      );

      expect(find.text('Server Error (500)'), findsOneWidget);
      expect(find.text('Internal Database Failure'), findsOneWidget);
      expect(find.byIcon(Icons.dns_rounded), findsOneWidget);
    });

    testWidgets('classifies ForbiddenException (403) with lock icon', (tester) async {
      const forbiddenErr = ForbiddenException(message: 'Only admins can view project dashboard');

      await tester.pumpWidget(
        wrapWithTheme(
          const AppErrorView(error: forbiddenErr),
        ),
      );

      expect(find.text('Access Restricted (403)'), findsOneWidget);
      expect(find.text('Only admins can view project dashboard'), findsOneWidget);
      expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);
    });

    testWidgets('classifies NotFoundException (404) with search_off icon', (tester) async {
      const notFoundErr = NotFoundException(message: 'Sprint not found');

      await tester.pumpWidget(
        wrapWithTheme(
          const AppErrorView(error: notFoundErr),
        ),
      );

      expect(find.text('Not Found (404)'), findsOneWidget);
      expect(find.text('Sprint not found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('AppErrorBanner displays compact banner with retry', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        wrapWithTheme(
          AppErrorBanner(
            message: 'Failed to sync with remote server',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Failed to sync with remote server'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('AppEmptyState Factory Presets Tests', () {
    testWidgets('AppEmptyState.noProjects displays proper icon, copy, and action', (tester) async {
      bool created = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppEmptyState.noProjects(
            onCreateProject: () => created = true,
          ),
        ),
      );

      expect(find.text('No Projects Found'), findsOneWidget);
      expect(find.textContaining('This workspace doesn\'t have any projects yet'), findsOneWidget);
      expect(find.text('Create First Project'), findsOneWidget);

      await tester.tap(find.text('Create First Project'));
      expect(created, isTrue);
    });

    testWidgets('AppEmptyState.noBacklog displays proper icon and action', (tester) async {
      bool created = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppEmptyState.noBacklog(
            onCreateIssue: () => created = true,
          ),
        ),
      );

      expect(find.text('Your Product Backlog is Empty'), findsOneWidget);
      expect(find.text('Create First Issue'), findsOneWidget);

      await tester.tap(find.text('Create First Issue'));
      expect(created, isTrue);
    });

    testWidgets('AppEmptyState.noSprints displays proper icon and action', (tester) async {
      bool planning = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppEmptyState.noSprints(
            onGoToPlanning: () => planning = true,
          ),
        ),
      );

      expect(find.text('No Sprints Available'), findsOneWidget);
      expect(find.text('Go to Sprint Planning'), findsOneWidget);

      await tester.tap(find.text('Go to Sprint Planning'));
      expect(planning, isTrue);
    });

    testWidgets('AppEmptyState.noActiveSprint displays proper icon and action', (tester) async {
      bool planning = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppEmptyState.noActiveSprint(
            onGoToPlanning: () => planning = true,
          ),
        ),
      );

      expect(find.text('No Active Sprint'), findsOneWidget);
      expect(find.text('Go to Sprint Planning'), findsOneWidget);

      await tester.tap(find.text('Go to Sprint Planning'));
      expect(planning, isTrue);
    });

    testWidgets('AppEmptyState.noSearchResults displays query and clear action', (tester) async {
      bool cleared = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppEmptyState.noSearchResults(
            query: 'authentication bug',
            onClearFilters: () => cleared = true,
          ),
        ),
      );

      expect(find.text('No Matching Results'), findsOneWidget);
      expect(find.textContaining('authentication bug'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);

      await tester.tap(find.text('Clear Filters'));
      expect(cleared, isTrue);
    });

    testWidgets('AppEmptyState.noMembers displays proper icon and action', (tester) async {
      bool invited = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppEmptyState.noMembers(
            onInviteMember: () => invited = true,
          ),
        ),
      );

      expect(find.text('No Team Members'), findsOneWidget);
      expect(find.text('Invite Member'), findsOneWidget);

      await tester.tap(find.text('Invite Member'));
      expect(invited, isTrue);
    });
  });

  group('DashboardScreen Skeleton & Error State Integration', () {
    testWidgets('DashboardScreen displays AppErrorView with retry on fetch failure', (tester) async {
      final fakeSprint = FakeTestSprintRepo()
        ..shouldThrow = true
        ..throwMessage = 'Network connection failed while fetching sprints';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sprintRepositoryProvider.overrideWithValue(fakeSprint),
            projectRepositoryProvider.overrideWithValue(FakeTestProjectRepo()),
            workspaceRepositoryProvider.overrideWithValue(FakeTestWorkspaceRepo()),
            secureStorageServiceProvider.overrideWithValue(FakeTestStorageService()),
            authNotifierProvider.overrideWith(
              (ref) => AuthNotifier(
                FakeTestStorageService(),
                initialState: const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(id: 'u1', email: 'u1@oversee.com', fullName: 'Tester'),
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: DashboardScreen(workspaceId: 'ws-1', projectId: 'proj-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Network Connection Lost'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
