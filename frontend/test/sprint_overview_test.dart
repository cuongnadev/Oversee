import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/application/sprint_overview_provider.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_complete_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:frontend/features/sprint/presentation/sprint_overview_screen.dart';
import 'package:frontend/features/sprint/presentation/widgets/complete_sprint_dialog.dart';
import 'package:frontend/features/sprint/presentation/widgets/start_sprint_dialog.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

class FakeSprintOverviewSprintRepository implements SprintRepository {
  List<SprintModel> mockSprints = [];
  Map<String, SprintProgressModel> mockProgress = {};
  int startSprintCallCount = 0;
  int completeSprintCallCount = 0;
  String? lastTargetSprintId;

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
  Future<SprintModel> startSprint(
    String sprintId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    startSprintCallCount++;
    final index = mockSprints.indexWhere((s) => s.id == sprintId);
    final updated = mockSprints[index].copyWith(
      status: SprintStatus.active,
      startDate: startDate,
      endDate: endDate,
    );
    mockSprints[index] = updated;
    return updated;
  }

  @override
  Future<SprintCompleteModel> completeSprint(
    String sprintId, {
    String? targetSprintId,
  }) async {
    completeSprintCallCount++;
    lastTargetSprintId = targetSprintId;
    final index = mockSprints.indexWhere((s) => s.id == sprintId);
    final updated = mockSprints[index].copyWith(status: SprintStatus.completed);
    mockSprints[index] = updated;

    return SprintCompleteModel(
      sprint: updated,
      completedIssuesCount: 3,
      incompleteIssuesCount: 2,
      movedToSprintId: targetSprintId,
      movedToBacklog: targetSprintId == null,
    );
  }
}

class FakeSprintOverviewProjectRepository implements ProjectRepository {
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

class FakeSprintOverviewWorkspaceRepository implements WorkspaceRepository {
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

class FakeSprintOverviewSecureStorageService implements SecureStorageService {
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
    id: 'sp-active',
    projectId: 'proj-1',
    name: 'Sprint 1',
    goal: 'Deliver core authentication flow',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 15),
    status: SprintStatus.active,
  );

  final plannedSprint = SprintModel(
    id: 'sp-planned',
    projectId: 'proj-1',
    name: 'Sprint 2',
    goal: 'Build backlog and kanban',
    startDate: DateTime(2026, 11, 16),
    endDate: DateTime(2026, 11, 30),
    status: SprintStatus.planned,
  );

  final completedSprint = SprintModel(
    id: 'sp-completed',
    projectId: 'proj-1',
    name: 'Sprint 0',
    goal: 'Initial setup',
    startDate: DateTime(2026, 10, 15),
    endDate: DateTime(2026, 10, 31),
    status: SprintStatus.completed,
  );

  const sampleProgress = SprintProgressModel(
    sprintId: 'sp-active',
    sprintName: 'Sprint 1',
    status: SprintStatus.active,
    totalIssues: 8,
    completedIssues: 5,
    remainingIssues: 3,
    issueProgressPercentage: 62.5,
    totalStoryPoints: 16.0,
    completedStoryPoints: 10.0,
    remainingStoryPoints: 6.0,
    storyPointProgressPercentage: 62.5,
    statusBreakdown: {'TODO': 1, 'IN_PROGRESS': 2, 'DONE': 5},
    burndown: [
      BurndownPointModel(date: '2026-11-01', idealRemaining: 16.0, actualRemaining: 16.0),
      BurndownPointModel(date: '2026-11-05', idealRemaining: 12.0, actualRemaining: 10.0),
    ],
  );

  group('Sprint Models Serialization & Deserialization', () {
    test('SprintCompleteModel serializes and deserializes correctly', () {
      final model = SprintCompleteModel(
        sprint: activeSprint,
        completedIssuesCount: 5,
        incompleteIssuesCount: 2,
        movedToSprintId: 'sp-planned',
        movedToBacklog: false,
      );

      final json = model.toJson();
      expect(json['completed_issues_count'], 5);
      expect(json['incomplete_issues_count'], 2);
      expect(json['moved_to_sprint_id'], 'sp-planned');
      expect(json['moved_to_backlog'], isFalse);

      final fromJson = SprintCompleteModel.fromJson(json);
      expect(fromJson.sprint.id, activeSprint.id);
      expect(fromJson.completedIssuesCount, 5);
      expect(fromJson.incompleteIssuesCount, 2);
      expect(fromJson.movedToSprintId, 'sp-planned');
      expect(fromJson.movedToBacklog, isFalse);
    });

    test('SprintProgressModel serializes and deserializes correctly with helper getters', () {
      final json = sampleProgress.toJson();
      expect(json['total_issues'], 8);
      expect(json['completed_issues'], 5);
      expect(json['issue_progress_percentage'], 62.5);
      expect(json['total_story_points'], 16.0);
      expect(json['burndown'], hasLength(2));

      final fromJson = SprintProgressModel.fromJson(json);
      expect(fromJson.sprintId, 'sp-active');
      expect(fromJson.hasIssues, isTrue);
      expect(fromJson.hasStoryPoints, isTrue);
      expect(fromJson.issueProgressRatio, closeTo(0.625, 0.001));
      expect(fromJson.storyPointProgressRatio, closeTo(0.625, 0.001));
      expect(fromJson.burndown.first.idealRemaining, 16.0);
    });
  });

  group('StartSprintDialog', () {
    testWidgets('renders sprint information and calls onStart on submit', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool onStartCalled = false;
      DateTime? passedStart;
      DateTime? passedEnd;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartSprintDialog(
              sprint: plannedSprint,
              hasOtherActiveSprint: false,
              onStart: ({startDate, endDate}) async {
                onStartCalled = true;
                passedStart = startDate;
                passedEnd = endDate;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Start Sprint'), findsWidgets);
      expect(find.text('Sprint 2'), findsOneWidget);
      expect(find.text('Goal: Build backlog and kanban'), findsOneWidget);

      final startButton = find.widgetWithText(ElevatedButton, 'Start Sprint');
      expect(startButton, findsOneWidget);

      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(onStartCalled, isTrue);
      expect(passedStart, isNotNull);
      expect(passedEnd, isNotNull);
    });

    testWidgets('shows warning and disables start button when another sprint is active', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartSprintDialog(
              sprint: plannedSprint,
              hasOtherActiveSprint: true,
              onStart: ({startDate, endDate}) async => true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Another sprint is currently active'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Start Sprint'));
      expect(button.onPressed, isNull);
    });
  });

  group('CompleteSprintDialog', () {
    testWidgets('shows summary and supports rollover to backlog or planned sprint', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? completedTargetSprintId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompleteSprintDialog(
              sprint: activeSprint,
              progress: sampleProgress,
              plannedSprints: [plannedSprint],
              onComplete: ({targetSprintId}) async {
                completedTargetSprintId = targetSprintId;
                return SprintCompleteModel(
                  sprint: activeSprint,
                  completedIssuesCount: sampleProgress.completedIssues,
                  incompleteIssuesCount: sampleProgress.remainingIssues,
                  movedToSprintId: targetSprintId,
                  movedToBacklog: targetSprintId == null,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Complete Sprint'), findsWidgets);
      expect(find.text('5'), findsOneWidget); // 5 completed
      expect(find.text('3'), findsOneWidget); // 3 incomplete
      expect(find.text('Move to Product Backlog'), findsOneWidget);
      expect(find.text('Move to Next Sprint'), findsOneWidget);

      // Select Move to Next Sprint
      await tester.tap(find.text('Move to Next Sprint'));
      await tester.pumpAndSettle();

      // Submit
      final completeButton = find.widgetWithText(ElevatedButton, 'Complete Sprint');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(completedTargetSprintId, 'sp-planned');
    });

    testWidgets('supports moving to backlog with null target sprint id', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? completedTargetSprintId = 'not-null-sentinel';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompleteSprintDialog(
              sprint: activeSprint,
              progress: sampleProgress,
              plannedSprints: [plannedSprint],
              onComplete: ({targetSprintId}) async {
                completedTargetSprintId = targetSprintId;
                return SprintCompleteModel(
                  sprint: activeSprint,
                  completedIssuesCount: sampleProgress.completedIssues,
                  incompleteIssuesCount: sampleProgress.remainingIssues,
                  movedToSprintId: null,
                  movedToBacklog: true,
                );
              },
            ),
          ),
        ),
      );

      // Default is Move to Product Backlog
      final completeButton = find.widgetWithText(ElevatedButton, 'Complete Sprint');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(completedTargetSprintId, isNull);
    });
  });

  group('SprintOverviewScreen Widget Tests', () {
    late FakeSprintOverviewSprintRepository fakeSprintRepo;
    late FakeSprintOverviewProjectRepository fakeProjectRepo;
    late FakeSprintOverviewWorkspaceRepository fakeWorkspaceRepo;

    setUp(() {
      fakeSprintRepo = FakeSprintOverviewSprintRepository();
      fakeSprintRepo.mockSprints = [activeSprint, plannedSprint, completedSprint];
      fakeSprintRepo.mockProgress[activeSprint.id] = sampleProgress;
      fakeProjectRepo = FakeSprintOverviewProjectRepository();
      fakeWorkspaceRepo = FakeSprintOverviewWorkspaceRepository();
    });

    test('SprintOverviewNotifier loads overview data and manages state correctly', () async {
      final container = ProviderContainer(
        overrides: [
          sprintRepositoryProvider.overrideWithValue(fakeSprintRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(sprintOverviewProvider('proj-1').notifier);
      await notifier.loadOverview();

      final state = container.read(sprintOverviewProvider('proj-1'));
      expect(state.sprints, hasLength(3));
      expect(state.hasActiveSprint, isTrue);
      expect(state.activeSprint?.id, 'sp-active');
      expect(state.activeSprintProgress?.completedIssues, 5);
      expect(state.plannedSprints, hasLength(1));
      expect(state.completedSprints, hasLength(1));

      // Test filter
      notifier.setStatusFilter(SprintStatus.planned);
      final filteredState = container.read(sprintOverviewProvider('proj-1'));
      expect(filteredState.filteredSprints, hasLength(1));
      expect(filteredState.filteredSprints.first.id, 'sp-planned');
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          sprintRepositoryProvider.overrideWithValue(fakeSprintRepo),
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspaceRepo),
          secureStorageServiceProvider.overrideWithValue(FakeSprintOverviewSecureStorageService()),
          authNotifierProvider.overrideWith(
            (ref) => AuthNotifier(
              FakeSprintOverviewSecureStorageService(),
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: UserModel(id: 'user-1', email: 'test@oversee.com', fullName: 'Tester'),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SprintOverviewScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
        ),
      );
    }

    testWidgets('renders active sprint hero card, planned sprints, and completed sprints', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify Active Sprint Section
      expect(find.text('ACTIVE SPRINT'), findsOneWidget);
      expect(find.text('Sprint 1'), findsOneWidget);
      expect(find.text('Goal: Deliver core authentication flow'), findsOneWidget);
      expect(find.text('Issue Progress'), findsOneWidget);
      expect(find.text('Points Progress'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Complete Sprint'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'View Board'), findsOneWidget);

      // Verify Planned Sprints Section
      expect(find.text('Planned Sprints (1)'), findsOneWidget);
      expect(find.text('Sprint 2'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Start Sprint'), findsOneWidget);

      // Verify Completed Sprints Section
      expect(find.text('Completed Sprints (1)'), findsOneWidget);
      expect(find.text('Sprint 0'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets('filters sprints when status filter chips are clicked', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Click 'Planned' chip
      await tester.tap(find.text('Planned'));
      await tester.pumpAndSettle();

      // Active and completed sections should be hidden
      expect(find.text('ACTIVE SPRINT'), findsNothing);
      expect(find.text('Completed Sprints (1)'), findsNothing);
      expect(find.text('Planned Sprints (1)'), findsOneWidget);
      expect(find.text('Sprint 2'), findsOneWidget);

      // Click 'Completed' chip
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE SPRINT'), findsNothing);
      expect(find.text('Planned Sprints (1)'), findsNothing);
      expect(find.text('Completed Sprints (1)'), findsOneWidget);
      expect(find.text('Sprint 0'), findsOneWidget);
    });
  });
}
