import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:frontend/features/dashboard/presentation/widgets/burndown_chart_widget.dart';
import 'package:frontend/features/dashboard/presentation/widgets/progress_summary_cards.dart';
import 'package:frontend/features/dashboard/presentation/widgets/risk_issues_widget.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

class FakeDashboardSprintRepository implements SprintRepository {
  List<SprintModel> mockSprints = [];
  Map<String, SprintProgressModel> mockProgress = {};
  Map<String, List<IssueModel>> mockSprintIssues = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<SprintModel>> listProjectSprints(String projectId, {SprintStatus? status}) async {
    if (status != null) {
      return mockSprints.where((s) => s.status == status).toList();
    }
    return List.from(mockSprints);
  }

  @override
  Future<SprintProgressModel> getSprintProgress(String sprintId) async {
    if (mockProgress.containsKey(sprintId)) {
      return mockProgress[sprintId]!;
    }
    final sprint = mockSprints.firstWhere((s) => s.id == sprintId);
    return SprintProgressModel(
      sprintId: sprint.id,
      sprintName: sprint.name,
      status: sprint.status,
      totalIssues: 5,
      completedIssues: 3,
      remainingIssues: 2,
      issueProgressPercentage: 60.0,
      totalStoryPoints: 10.0,
      completedStoryPoints: 6.0,
      remainingStoryPoints: 4.0,
      storyPointProgressPercentage: 60.0,
      statusBreakdown: const {'TODO': 1, 'IN_PROGRESS': 1, 'DONE': 3},
    );
  }

  @override
  Future<List<IssueModel>> getSprintIssues(String sprintId) async {
    if (mockSprintIssues.containsKey(sprintId)) {
      return List.from(mockSprintIssues[sprintId]!);
    }
    return [];
  }
}

class FakeDashboardProjectRepository implements ProjectRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async {
    return const ProjectModel(
      id: 'proj-1',
      workspaceId: 'ws-1',
      name: 'Oversee Mobile App',
      key: 'OVS',
    );
  }
}

class FakeDashboardWorkspaceRepository implements WorkspaceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async {
    return [
      const WorkspaceModel(
        id: 'ws-1',
        name: 'Workspace Alpha',
        slug: 'workspace-alpha',
        ownerId: 'user-1',
      ),
    ];
  }
}

class FakeDashboardSecureStorageService implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String?> getAccessToken() async => 'fake-token';

  @override
  Future<String?> getRefreshToken() async => 'fake-refresh';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final activeSprint = SprintModel(
    id: 'sp-1',
    projectId: 'proj-1',
    name: 'Sprint 1 - Core',
    startDate: DateTime.now().subtract(const Duration(days: 5)),
    endDate: DateTime.now().add(const Duration(days: 9)),
    status: SprintStatus.active,
  );

  final completedSprint = SprintModel(
    id: 'sp-0',
    projectId: 'proj-1',
    name: 'Sprint 0 - Inception',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 14),
    status: SprintStatus.completed,
  );

  const sampleProgress = SprintProgressModel(
    sprintId: 'sp-1',
    sprintName: 'Sprint 1 - Core',
    status: SprintStatus.active,
    totalIssues: 10,
    completedIssues: 6,
    remainingIssues: 4,
    issueProgressPercentage: 60.0,
    totalStoryPoints: 20.0,
    completedStoryPoints: 12.0,
    remainingStoryPoints: 8.0,
    storyPointProgressPercentage: 60.0,
    statusBreakdown: {'TODO': 2, 'IN_PROGRESS': 2, 'DONE': 6},
    burndown: [
      BurndownPointModel(date: '2026-11-01', idealRemaining: 20.0, actualRemaining: 20.0),
      BurndownPointModel(date: '2026-11-03', idealRemaining: 16.0, actualRemaining: 18.0),
      BurndownPointModel(date: '2026-11-05', idealRemaining: 12.0, actualRemaining: 12.0),
      BurndownPointModel(date: '2026-11-07', idealRemaining: 8.0, actualRemaining: 8.0),
    ],
  );

  final urgentIssue = IssueModel(
    id: 'iss-1',
    projectId: 'proj-1',
    issueNumber: 101,
    title: 'Database connection leak',
    status: IssueStatus.inProgress,
    priority: IssuePriority.urgent,
    reporterId: 'user-1',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    updatedAt: DateTime.now().subtract(const Duration(days: 4)),
  );

  const normalIssue = IssueModel(
    id: 'iss-2',
    projectId: 'proj-1',
    issueNumber: 102,
    title: 'Update readme badges',
    status: IssueStatus.done,
    priority: IssuePriority.low,
    reporterId: 'user-1',
  );

  group('DashboardNotifier & State Logic', () {
    late FakeDashboardSprintRepository sprintRepo;
    late FakeDashboardProjectRepository projectRepo;

    setUp(() {
      sprintRepo = FakeDashboardSprintRepository();
      sprintRepo.mockSprints = [activeSprint, completedSprint];
      sprintRepo.mockProgress[activeSprint.id] = sampleProgress;
      sprintRepo.mockSprintIssues[activeSprint.id] = [urgentIssue, normalIssue];
      projectRepo = FakeDashboardProjectRepository();
    });

    test('loads project, selects active sprint, and calculates velocity & risks', () async {
      final container = ProviderContainer(
        overrides: [
          sprintRepositoryProvider.overrideWithValue(sprintRepo),
          projectRepositoryProvider.overrideWithValue(projectRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dashboardProvider('proj-1').notifier);
      await notifier.loadDashboard();

      final state = container.read(dashboardProvider('proj-1'));
      expect(state.isLoading, isFalse);
      expect(state.project?.key, 'OVS');
      expect(state.sprints, hasLength(2));
      expect(state.selectedSprint?.id, 'sp-1');
      expect(state.hasActiveSprint, isTrue);

      // Verify KPI metrics
      expect(state.progress?.totalStoryPoints, 20.0);
      expect(state.progress?.completedStoryPoints, 12.0);
      expect(state.burnVelocityPerDay, greaterThan(0));
      expect(state.isOnTrack, isTrue);

      // Verify Risk issues detection
      expect(state.riskIssues, hasLength(1));
      expect(state.riskIssues.first.id, 'iss-1');
      expect(state.blockerIssues, hasLength(1));
    });

    test('selectSprint switches sprint and reloads burndown progress', () async {
      final container = ProviderContainer(
        overrides: [
          sprintRepositoryProvider.overrideWithValue(sprintRepo),
          projectRepositoryProvider.overrideWithValue(projectRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dashboardProvider('proj-1').notifier);
      await notifier.loadDashboard();

      await notifier.selectSprint('sp-0');
      final state = container.read(dashboardProvider('proj-1'));
      expect(state.selectedSprint?.id, 'sp-0');
      expect(state.hasActiveSprint, isFalse);
    });
  });

  group('BurndownChartWidget', () {
    testWidgets('renders title, legend, and line chart', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BurndownChartWidget(
              progress: sampleProgress,
              isDark: true,
            ),
          ),
        ),
      );

      expect(find.text('Sprint Burndown Chart'), findsOneWidget);
      expect(find.text('Ideal Burndown'), findsOneWidget);
      expect(find.text('Actual Remaining'), findsOneWidget);
    });

    testWidgets('renders empty placeholder when burndown list is empty', (tester) async {
      const emptyProgress = SprintProgressModel(
        sprintId: 'sp-1',
        sprintName: 'Sprint 1',
        status: SprintStatus.planned,
        totalIssues: 0,
        completedIssues: 0,
        remainingIssues: 0,
        issueProgressPercentage: 0,
        totalStoryPoints: 0,
        completedStoryPoints: 0,
        remainingStoryPoints: 0,
        storyPointProgressPercentage: 0,
        burndown: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BurndownChartWidget(
              progress: emptyProgress,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('No Burndown Data Available'), findsOneWidget);
    });
  });

  group('ProgressSummaryCards & RiskIssuesWidget', () {
    testWidgets('ProgressSummaryCards renders 4 metric cards accurately', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = DashboardState(
        selectedSprint: activeSprint,
        progress: sampleProgress,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressSummaryCards(state: state, isDark: true),
          ),
        ),
      );

      expect(find.text('Story Points Progress'), findsOneWidget);
      expect(find.text('Issues Completed'), findsOneWidget);
      expect(find.text('Sprint Timeline'), findsOneWidget);
      expect(find.text('Burn Velocity & Forecast'), findsOneWidget);
      expect(find.text('12 / 20 pts'), findsOneWidget);
      expect(find.text('6 of 10'), findsOneWidget);
    });

    testWidgets('RiskIssuesWidget surfaces blocker and lingering tasks', (tester) async {
      final state = DashboardState(
        project: const ProjectModel(id: 'proj-1', workspaceId: 'ws-1', name: 'Oversee', key: 'OVS'),
        issues: [urgentIssue, normalIssue],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskIssuesWidget(
              state: state,
              workspaceId: 'ws-1',
              projectId: 'proj-1',
              isDark: true,
            ),
          ),
        ),
      );

      expect(find.text('Attention Required (1)'), findsOneWidget);
      expect(find.text('Database connection leak'), findsOneWidget);
      expect(find.text('URGENT BLOCKER'), findsOneWidget);
    });
  });

  group('DashboardScreen Full Widget Test', () {
    late FakeDashboardSprintRepository fakeSprintRepo;
    late FakeDashboardProjectRepository fakeProjectRepo;
    late FakeDashboardWorkspaceRepository fakeWorkspaceRepo;

    setUp(() {
      fakeSprintRepo = FakeDashboardSprintRepository();
      fakeSprintRepo.mockSprints = [activeSprint, completedSprint];
      fakeSprintRepo.mockProgress[activeSprint.id] = sampleProgress;
      fakeSprintRepo.mockSprintIssues[activeSprint.id] = [urgentIssue, normalIssue];
      fakeProjectRepo = FakeDashboardProjectRepository();
      fakeWorkspaceRepo = FakeDashboardWorkspaceRepository();
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          sprintRepositoryProvider.overrideWithValue(fakeSprintRepo),
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspaceRepo),
          secureStorageServiceProvider.overrideWithValue(FakeDashboardSecureStorageService()),
          authNotifierProvider.overrideWith(
            (ref) => AuthNotifier(
              FakeDashboardSecureStorageService(),
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: UserModel(id: 'user-1', email: 'test@oversee.com', fullName: 'Tester'),
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

    testWidgets('renders toolbar with sprint selector, KPI cards, burndown chart and risks', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Top Toolbar & Sprint Selector
      expect(find.text('Sprint Progress:'), findsOneWidget);
      expect(find.text('Sprint 1 - Core'), findsWidgets);

      // KPI Metrics Cards
      expect(find.text('Story Points Progress'), findsOneWidget);
      expect(find.text('Issues Completed'), findsOneWidget);

      // Burndown Chart
      expect(find.text('Sprint Burndown Chart'), findsOneWidget);

      // Risk Issues
      expect(find.text('Attention Required (1)'), findsOneWidget);
      expect(find.text('Database connection leak'), findsOneWidget);
    });

    testWidgets('renders empty view when project has no sprints', (tester) async {
      fakeSprintRepo.mockSprints = [];

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('No Sprints Available'), findsOneWidget);
      expect(find.text('Go to Sprint Planning'), findsOneWidget);
    });
  });
}
