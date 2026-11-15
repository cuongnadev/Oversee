import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/shared/widgets/widgets.dart';

class FakeRespSprintRepo implements SprintRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<SprintModel>> listProjectSprints(String projectId, {SprintStatus? status}) async {
    return [
      SprintModel(
        id: 'sp-1',
        projectId: projectId,
        name: 'Sprint Alpha',
        startDate: DateTime.now().subtract(const Duration(days: 4)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        status: SprintStatus.active,
      ),
    ];
  }

  @override
  Future<SprintProgressModel> getSprintProgress(String sprintId) async {
    return const SprintProgressModel(
      sprintId: 'sp-1',
      sprintName: 'Sprint Alpha',
      status: SprintStatus.active,
      totalIssues: 8,
      completedIssues: 5,
      remainingIssues: 3,
      issueProgressPercentage: 62.5,
      totalStoryPoints: 24.0,
      completedStoryPoints: 15.0,
      remainingStoryPoints: 9.0,
      storyPointProgressPercentage: 62.5,
      statusBreakdown: {'TODO': 2, 'IN_PROGRESS': 1, 'DONE': 5},
      burndown: [
        BurndownPointModel(date: '2026-11-01', idealRemaining: 24.0, actualRemaining: 24.0),
        BurndownPointModel(date: '2026-11-03', idealRemaining: 18.0, actualRemaining: 20.0),
        BurndownPointModel(date: '2026-11-05', idealRemaining: 12.0, actualRemaining: 15.0),
      ],
    );
  }

  @override
  Future<List<IssueModel>> getSprintIssues(String sprintId) async {
    return [
      IssueModel(
        id: 'iss-1',
        projectId: 'proj-1',
        issueNumber: 1,
        title: 'Fix responsive layout crash on mobile devices',
        status: IssueStatus.inProgress,
        priority: IssuePriority.urgent,
        estimate: 5.0,
        reporterId: 'u1',
        assigneeId: 'u1',
        assignee: const UserModel(id: 'u1', email: 'dev@oversee.com', fullName: 'Sarah Connor'),
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        updatedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      const IssueModel(
        id: 'iss-2',
        projectId: 'proj-1',
        issueNumber: 2,
        title: 'Add accessibility semantics to all charts',
        status: IssueStatus.done,
        priority: IssuePriority.medium,
        estimate: 3.0,
        reporterId: 'u1',
        assigneeId: 'u1',
        assignee: UserModel(id: 'u1', email: 'dev@oversee.com', fullName: 'Sarah Connor'),
      ),
    ];
  }
}

class FakeRespProjectRepo implements ProjectRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async {
    return const ProjectModel(id: 'proj-1', workspaceId: 'ws-1', name: 'Oversee Mobile', key: 'OVS');
  }

  @override
  Future<List<ProjectMemberModel>> listProjectMembers(String projectId) async {
    return [
      const ProjectMemberModel(
        id: 'pm-1',
        projectId: 'proj-1',
        userId: 'u1',
        role: RoleType.owner,
        user: UserModel(id: 'u1', email: 'dev@oversee.com', fullName: 'Sarah Connor'),
      ),
    ];
  }
}

class FakeRespWorkspaceRepo implements WorkspaceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async {
    return [const WorkspaceModel(id: 'ws-1', name: 'Alpha Org', slug: 'alpha', ownerId: 'u1')];
  }
}

class FakeRespStorageService implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<String?> getAccessToken() async => 'fake-token';
  @override
  Future<String?> getRefreshToken() async => 'fake-refresh';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestDashboard({required Size size}) {
    return ProviderScope(
      overrides: [
        sprintRepositoryProvider.overrideWithValue(FakeRespSprintRepo()),
        projectRepositoryProvider.overrideWithValue(FakeRespProjectRepo()),
        workspaceRepositoryProvider.overrideWithValue(FakeRespWorkspaceRepo()),
        secureStorageServiceProvider.overrideWithValue(FakeRespStorageService()),
        authNotifierProvider.overrideWith(
          (ref) => AuthNotifier(
            FakeRespStorageService(),
            initialState: const AuthState(
              status: AuthStatus.authenticated,
              user: UserModel(id: 'u1', email: 'dev@oversee.com', fullName: 'Sarah Connor'),
            ),
          ),
        ),
      ],
      child: const MaterialApp(
        home: DashboardScreen(
          workspaceId: 'ws-1',
          projectId: 'proj-1',
        ),
      ),
    );
  }

  group('Multi-Platform Responsive Breakpoints Tests', () {
    testWidgets('Dashboard renders on compact mobile (360x740) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestDashboard(size: const Size(360, 740)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sprint Alpha'), findsWidgets);
      expect(find.text('Story Points Progress'), findsOneWidget);
    });

    testWidgets('Dashboard renders on standard mobile (412x915) cleanly', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestDashboard(size: const Size(412, 915)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sprint Burndown Chart'), findsOneWidget);
      expect(find.text('Status Distribution'), findsOneWidget);
      expect(find.text('Priority Breakdown'), findsOneWidget);
    });

    testWidgets('Dashboard renders on tablet (768x1024) in responsive 2x2 grid without overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestDashboard(size: const Size(768, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sprint Timeline'), findsOneWidget);
      expect(find.text('Burn Velocity & Forecast'), findsOneWidget);
      expect(find.textContaining('Workload by Assignee'), findsOneWidget);
    });

    testWidgets('Dashboard renders on desktop (1440x900) in full 2-column layout', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestDashboard(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sprint Burndown Chart'), findsOneWidget);
      expect(find.text('Status Distribution'), findsOneWidget);
      expect(find.text('Priority Breakdown'), findsOneWidget);
      expect(find.textContaining('Workload by Assignee'), findsOneWidget);
      expect(find.text('Attention Required (1)'), findsOneWidget);
    });
  });

  group('Keyboard Navigation & Cheatsheet Tests', () {
    testWidgets('AppKeyboardShortcuts invokes onRefresh on R key press', (tester) async {
      bool refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppKeyboardShortcuts(
              onRefresh: () => refreshed = true,
              child: const Center(child: Text('Dashboard Content')),
            ),
          ),
        ),
      );

      // Simulate 'R' key
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      expect(refreshed, isTrue);
    });

    testWidgets('AppKeyboardShortcuts opens KeyboardShortcutsDialog on ? (Shift + /)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppKeyboardShortcuts(
              child: Center(child: Text('Dashboard Content')),
            ),
          ),
        ),
      );

      // Press Shift + Slash ('?')
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('R / Ctrl+R'), findsOneWidget);
      expect(find.text('C / Ctrl+N'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardShortcutsDialog), findsNothing);
    });

    testWidgets('Keyboard shortcuts dialog can be opened via toolbar button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestDashboard(size: const Size(1280, 800)));
      await tester.pumpAndSettle();

      final helpBtn = find.byTooltip('Keyboard shortcuts (?)');
      expect(helpBtn, findsOneWidget);

      await tester.tap(helpBtn);
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    });
  });

  group('Accessibility & Semantics (a11y) Verification', () {
    testWidgets('Charts and cards expose clear Semantics for screen readers', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestDashboard(size: const Size(1280, 1000)));
      await tester.pumpAndSettle();

      // Check Semantics nodes exist
      final semanticsFinder = find.byType(Semantics);
      expect(semanticsFinder, findsWidgets);

      // Burndown chart semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains('burndown chart') ?? false),
        ),
        findsOneWidget,
      );

      // Status distribution donut semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains('Status Distribution donut chart') ?? false),
        ),
        findsOneWidget,
      );

      // Priority breakdown bar chart semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains('Priority breakdown bar chart') ?? false),
        ),
        findsOneWidget,
      );

      // Workload semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains('Workload for Sarah Connor') ?? false),
        ),
        findsOneWidget,
      );
    });
  });
}
