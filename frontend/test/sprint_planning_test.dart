import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/application/sprint_planning_provider.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_planning_model.dart';
import 'package:frontend/features/sprint/presentation/sprint_planning_screen.dart';
import 'package:frontend/features/sprint/presentation/widgets/create_sprint_dialog.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

class FakeSprintPlanningSprintRepository implements SprintRepository {
  List<SprintModel> mockSprints = [];
  Map<String, SprintPlanningModel> mockPlanningSummaries = {};
  int addIssueCallCount = 0;
  int removeIssueCallCount = 0;
  int createSprintCallCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<SprintModel>> listProjectSprints(String projectId, {SprintStatus? status}) async {
    return List.from(mockSprints);
  }

  @override
  Future<SprintPlanningModel> getSprintPlanning(String sprintId) async {
    if (mockPlanningSummaries.containsKey(sprintId)) {
      return mockPlanningSummaries[sprintId]!;
    }
    final sprint = mockSprints.firstWhere((s) => s.id == sprintId);
    return SprintPlanningModel(sprint: sprint, capacity: sprint.capacity);
  }

  @override
  Future<void> addIssueToSprint(String sprintId, String issueId) async {
    addIssueCallCount++;
  }

  @override
  Future<void> removeIssueFromSprint(String sprintId, String issueId) async {
    removeIssueCallCount++;
  }

  @override
  Future<SprintModel> createSprint(
    String projectId, {
    required String name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
    double? capacity,
  }) async {
    createSprintCallCount++;
    final created = SprintModel(
      id: 'sp-${mockSprints.length + 1}',
      projectId: projectId,
      name: name,
      goal: goal,
      startDate: startDate,
      endDate: endDate,
      capacity: capacity,
      status: SprintStatus.planned,
    );
    mockSprints.add(created);
    mockPlanningSummaries[created.id] = SprintPlanningModel(sprint: created, capacity: capacity);
    return created;
  }
}

class FakeSprintPlanningIssueRepository implements IssueRepository {
  List<IssueModel> mockBacklogIssues = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<IssuePageModel> listBacklogIssues(
    String projectId, {
    int page = 1,
    int pageSize = 100,
    String? search,
    IssuePriority? priority,
    IssueType? type,
  }) async {
    return IssuePageModel(
      items: List.from(mockBacklogIssues),
      total: mockBacklogIssues.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }
}

class FakeSprintPlanningProjectRepository implements ProjectRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async {
    return const ProjectModel(
      id: 'proj-1',
      workspaceId: 'ws-1',
      name: 'Oversee Core',
      key: 'OVS',
    );
  }

  @override
  Future<ProjectPageModel> listWorkspaceProjects(
    String workspaceId, {
    int page = 1,
    int pageSize = 20,
    bool includeArchived = false,
  }) async {
    return const ProjectPageModel(
      items: [
        ProjectModel(
          id: 'proj-1',
          workspaceId: 'ws-1',
          name: 'Oversee Core',
          key: 'OVS',
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 100,
      totalPages: 1,
    );
  }
}

class FakeSprintPlanningWorkspaceRepository implements WorkspaceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async {
    return [
      const WorkspaceModel(
        id: 'ws-1',
        name: 'Oversee HQ',
        slug: 'oversee-hq',
        ownerId: 'u-1',
        userRole: RoleType.owner,
      ),
    ];
  }
}

class FakeSecureStorageService implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testSprint = SprintModel(
    id: 'sprint-101',
    projectId: 'proj-1',
    name: 'Sprint 1 - Foundations',
    status: SprintStatus.planned,
    capacity: 20.0,
  );

  const testBacklogIssues = [
    IssueModel(
      id: 'iss-1',
      projectId: 'proj-1',
      issueNumber: 1,
      title: 'Setup PostgreSQL Database',
      type: IssueType.task,
      status: IssueStatus.backlog,
      priority: IssuePriority.high,
      estimate: 5.0,
      reporterId: 'u-1',
    ),
    IssueModel(
      id: 'iss-2',
      projectId: 'proj-1',
      issueNumber: 2,
      title: 'Create User Authentication',
      type: IssueType.story,
      status: IssueStatus.backlog,
      priority: IssuePriority.urgent,
      estimate: 8.0,
      reporterId: 'u-1',
    ),
  ];

  const testSprintIssues = [
    IssueModel(
      id: 'iss-3',
      projectId: 'proj-1',
      issueNumber: 3,
      title: 'Design Design System',
      type: IssueType.story,
      status: IssueStatus.todo,
      priority: IssuePriority.medium,
      estimate: 10.0,
      reporterId: 'u-1',
      sprintId: 'sprint-101',
    ),
  ];

  group('SprintPlanningModel Unit Tests', () {
    test('serializes and deserializes accurately from JSON', () {
      const summary = SprintPlanningModel(
        sprint: testSprint,
        issues: testSprintIssues,
        totalIssues: 1,
        totalEstimate: 10.0,
        capacity: 20.0,
        isOverCapacity: false,
      );

      final json = summary.toJson();
      expect(json['total_issues'], 1);
      expect(json['total_estimate'], 10.0);
      expect(json['capacity'], 20.0);
      expect(json['is_over_capacity'], isFalse);

      final reconstructed = SprintPlanningModel.fromJson(json);
      expect(reconstructed.totalIssues, 1);
      expect(reconstructed.totalEstimate, 10.0);
      expect(reconstructed.capacityPercentageText, '50%');
      expect(reconstructed.capacityUsageRatio, 0.5);
    });

    test('calculates capacity percentage and over-capacity correctly', () {
      const summaryOver = SprintPlanningModel(
        sprint: testSprint,
        issues: testSprintIssues,
        totalIssues: 2,
        totalEstimate: 25.0,
        capacity: 20.0,
        isOverCapacity: true,
        warning: 'Sprint estimate (25.0) exceeds planned capacity (20.0).',
      );

      expect(summaryOver.capacityUsageRatio, 1.25);
      expect(summaryOver.capacityPercentageText, '125%');
      expect(summaryOver.isOverCapacity, isTrue);
      expect(summaryOver.warning, contains('exceeds planned capacity'));
    });
  });

  group('SprintPlanningNotifier Unit Tests', () {
    late FakeSprintPlanningSprintRepository sprintRepo;
    late FakeSprintPlanningIssueRepository issueRepo;
    late FakeSprintPlanningProjectRepository projectRepo;

    setUp(() {
      sprintRepo = FakeSprintPlanningSprintRepository()
        ..mockSprints = [testSprint]
        ..mockPlanningSummaries = {
          'sprint-101': SprintPlanningModel(
            sprint: testSprint,
            issues: List.from(testSprintIssues),
            totalIssues: 1,
            totalEstimate: 10.0,
            capacity: 20.0,
          ),
        };

      issueRepo = FakeSprintPlanningIssueRepository()
        ..mockBacklogIssues = List.from(testBacklogIssues);

      projectRepo = FakeSprintPlanningProjectRepository();
    });

    test('loadPlanningData loads project, backlog, and sprint summaries', () async {
      final notifier = SprintPlanningNotifier(
        projectId: 'proj-1',
        sprintRepository: sprintRepo,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );

      await notifier.loadPlanningData();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.backlogIssues.length, 2);
      expect(notifier.state.totalBacklogStoryPoints, 13.0);
      expect(notifier.state.sprints.length, 1);
      expect(notifier.state.planningSummaries.containsKey('sprint-101'), isTrue);
      expect(notifier.state.planningSummaries['sprint-101']!.totalEstimate, 10.0);
    });

    test('assignIssueToSprint moves issue from backlog into sprint and triggers warning if over capacity',
        () async {
      final notifier = SprintPlanningNotifier(
        projectId: 'proj-1',
        sprintRepository: sprintRepo,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadPlanningData();

      // Issue 2 is 8 pts. 10 + 8 = 18 pts (capacity is 20, within limit)
      final success1 = await notifier.assignIssueToSprint('sprint-101', testBacklogIssues[1]);
      expect(success1, isTrue);
      expect(notifier.state.backlogIssues.length, 1);
      expect(notifier.state.planningSummaries['sprint-101']!.totalEstimate, 18.0);
      expect(notifier.state.planningSummaries['sprint-101']!.isOverCapacity, isFalse);

      // Issue 1 is 5 pts. 18 + 5 = 23 pts (exceeds capacity 20!)
      final success2 = await notifier.assignIssueToSprint('sprint-101', testBacklogIssues[0]);
      expect(success2, isTrue);
      expect(notifier.state.backlogIssues.isEmpty, isTrue);
      expect(notifier.state.planningSummaries['sprint-101']!.totalEstimate, 23.0);
      expect(notifier.state.planningSummaries['sprint-101']!.isOverCapacity, isTrue);
      expect(notifier.state.planningSummaries['sprint-101']!.warning, contains('exceeds planned capacity'));
      expect(sprintRepo.addIssueCallCount, 2);
    });

    test('removeIssueFromSprint returns issue to backlog and recalculates estimate', () async {
      final notifier = SprintPlanningNotifier(
        projectId: 'proj-1',
        sprintRepository: sprintRepo,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadPlanningData();

      // Remove iss-3 (10 pts) from sprint-101
      final success = await notifier.removeIssueFromSprint('sprint-101', testSprintIssues[0]);
      expect(success, isTrue);
      expect(notifier.state.backlogIssues.length, 3);
      expect(notifier.state.planningSummaries['sprint-101']!.totalEstimate, 0.0);
      expect(sprintRepo.removeIssueCallCount, 1);
    });

    test('createSprint calls repo and adds new planned sprint to state', () async {
      final notifier = SprintPlanningNotifier(
        projectId: 'proj-1',
        sprintRepository: sprintRepo,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadPlanningData();

      final created = await notifier.createSprint(
        name: 'Sprint 2 - User Onboarding',
        goal: 'Complete registration',
        capacity: 35.0,
      );

      expect(created, isNotNull);
      expect(created!.name, 'Sprint 2 - User Onboarding');
      expect(notifier.state.sprints.length, 2);
      expect(notifier.state.planningSummaries.containsKey(created.id), isTrue);
      expect(sprintRepo.createSprintCallCount, 1);
    });

    test('setSearchQuery filters backlog issues', () async {
      final notifier = SprintPlanningNotifier(
        projectId: 'proj-1',
        sprintRepository: sprintRepo,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadPlanningData();

      notifier.setSearchQuery('PostgreSQL');
      expect(notifier.state.filteredBacklogIssues.length, 1);
      expect(notifier.state.filteredBacklogIssues.first.title, contains('PostgreSQL'));
    });
  });

  group('SprintPlanningScreen & CreateSprintDialog Widget Tests', () {
    late FakeSprintPlanningSprintRepository fakeSprintRepo;
    late FakeSprintPlanningIssueRepository fakeIssueRepo;
    late FakeSprintPlanningProjectRepository fakeProjectRepo;
    late FakeSprintPlanningWorkspaceRepository fakeWorkspaceRepo;

    setUp(() {
      fakeSprintRepo = FakeSprintPlanningSprintRepository()
        ..mockSprints = [testSprint]
        ..mockPlanningSummaries = {
          'sprint-101': SprintPlanningModel(
            sprint: testSprint,
            issues: List.from(testSprintIssues),
            totalIssues: 1,
            totalEstimate: 10.0,
            capacity: 20.0,
          ),
        };

      fakeIssueRepo = FakeSprintPlanningIssueRepository()
        ..mockBacklogIssues = List.from(testBacklogIssues);

      fakeProjectRepo = FakeSprintPlanningProjectRepository();
      fakeWorkspaceRepo = FakeSprintPlanningWorkspaceRepository();
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          sprintRepositoryProvider.overrideWithValue(fakeSprintRepo),
          issueRepositoryProvider.overrideWithValue(fakeIssueRepo),
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspaceRepo),
          authNotifierProvider.overrideWith(
            (ref) => AuthNotifier(
              FakeSecureStorageService(),
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: UserModel(id: 'u-1', email: 'cuong@oversee.local', fullName: 'Cuong'),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SprintPlanningScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
        ),
      );
    }

    testWidgets('renders Product Backlog column and Sprints column', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Product Backlog'), findsOneWidget);
      expect(find.text('Setup PostgreSQL Database'), findsOneWidget);
      expect(find.text('Create User Authentication'), findsOneWidget);

      expect(find.text('Sprint 1 - Foundations'), findsOneWidget);
      expect(find.text('Design Design System'), findsOneWidget);
      expect(find.text('10 / 20 pts'), findsOneWidget);
      expect(find.text('Create Sprint'), findsOneWidget);
    });

    testWidgets('displays prominent capacity warning banner when sprint estimate exceeds capacity',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Set sprint to be over capacity
      fakeSprintRepo.mockPlanningSummaries['sprint-101'] = SprintPlanningModel(
        sprint: testSprint,
        issues: [
          testSprintIssues[0],
          testBacklogIssues[0].copyWith(estimate: 15.0),
        ],
        totalIssues: 2,
        totalEstimate: 25.0,
        capacity: 20.0,
        isOverCapacity: true,
        warning: 'Sprint estimate (25 pts) exceeds capacity (20 pts).',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('25 / 20 pts'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Sprint estimate (25 pts) exceeds capacity (20 pts).'), findsOneWidget);
    });

    testWidgets('CreateSprintDialog opens and submits form correctly', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Sprint'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Sprint'), findsOneWidget);
      expect(find.text('Sprint Name *'), findsOneWidget);

      // Enter name
      final nameField = find.widgetWithText(TextFormField, 'e.g. Sprint 2 - Core Workflows');
      await tester.enterText(nameField, 'Sprint 2 - API Enhancements');

      // Tap Create Sprint button inside dialog
      final createButton = find.descendant(
        of: find.byType(CreateSprintDialog),
        matching: find.widgetWithText(ElevatedButton, 'Create Sprint'),
      );
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(fakeSprintRepo.createSprintCallCount, 1);
    });

    testWidgets('Drag and drop backlog issue to sprint bucket assigns issue to sprint', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final draggable = find.text('Setup PostgreSQL Database');
      final target = find.text('Sprint 1 - Foundations');

      final gesture = await tester.startGesture(tester.getCenter(draggable));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(fakeSprintRepo.addIssueCallCount, 1);
    });
  });
}
