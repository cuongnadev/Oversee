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
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';
import 'package:frontend/features/sprint/application/kanban_board_state.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/presentation/kanban_board_screen.dart';
import 'package:frontend/features/sprint/presentation/widgets/kanban_column_widget.dart';
import 'package:frontend/features/sprint/presentation/widgets/kanban_issue_card.dart';

class FakeSprintRepository implements SprintRepository {
  SprintModel? mockActiveSprint;
  List<IssueModel> mockIssues = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<SprintModel?> getActiveSprint(String projectId) async {
    return mockActiveSprint;
  }

  @override
  Future<List<IssueModel>> getSprintIssues(String sprintId) async {
    return List.from(mockIssues);
  }
}

class FakeIssueRepository implements IssueRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<IssueModel> updateIssueStatus(
    String issueId, {
    required IssueStatus status,
    bool? allowOpenSubissues,
  }) async {
    return IssueModel(
      id: issueId,
      projectId: 'proj-1',
      issueNumber: 101,
      title: 'Updated title',
      status: status,
      reporterId: 'user-1',
    );
  }
}

class FakeProjectRepository implements ProjectRepository {
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
}

class FakeSecureStorageService implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String?> getAccessToken() async => 'fake-token';

  @override
  Future<String?> getRefreshToken() async => 'fake-refresh';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSprint = SprintModel(
    id: 'sprint-1',
    projectId: 'proj-1',
    name: 'Sprint 1',
    goal: 'Build foundation & Kanban',
    startDate: DateTime(2026, 10, 12),
    endDate: DateTime(2026, 10, 26),
    status: SprintStatus.active,
  );

  final testIssues = [
    const IssueModel(
      id: 'iss-1',
      projectId: 'proj-1',
      issueNumber: 101,
      title: 'Build backend API',
      type: IssueType.task,
      status: IssueStatus.todo,
      priority: IssuePriority.high,
      estimate: 5.0,
      reporterId: 'u-1',
      subIssueCount: 4,
      completedSubIssueCount: 2,
    ),
    const IssueModel(
      id: 'iss-2',
      projectId: 'proj-1',
      issueNumber: 102,
      title: 'Create Kanban UI',
      type: IssueType.story,
      status: IssueStatus.inProgress,
      priority: IssuePriority.urgent,
      estimate: 8.0,
      reporterId: 'u-1',
      assignee: UserModel(id: 'u-2', email: 'alice@oversee.io', fullName: 'Alice Smith'),
    ),
    const IssueModel(
      id: 'iss-3',
      projectId: 'proj-1',
      issueNumber: 103,
      title: 'Review auth workflow',
      type: IssueType.task,
      status: IssueStatus.inReview,
      priority: IssuePriority.medium,
      estimate: 3.0,
      reporterId: 'u-1',
    ),
    const IssueModel(
      id: 'iss-4',
      projectId: 'proj-1',
      issueNumber: 104,
      title: 'Fix typo in README',
      type: IssueType.bug,
      status: IssueStatus.done,
      priority: IssuePriority.low,
      estimate: 1.0,
      reporterId: 'u-1',
    ),
  ];

  group('SprintModel Unit Tests', () {
    test('serializes and deserializes correctly from JSON', () {
      final json = testSprint.toJson();
      expect(json['name'], 'Sprint 1');
      expect(json['status'], 'active');

      final reconstructed = SprintModel.fromJson(json);
      expect(reconstructed.id, testSprint.id);
      expect(reconstructed.name, testSprint.name);
      expect(reconstructed.isActive, isTrue);
      expect(reconstructed.isCompleted, isFalse);
    });

    test('calculates date range text and days remaining', () {
      expect(testSprint.dateRangeText, contains('Oct 12'));
      expect(testSprint.dateRangeText, contains('Oct 26, 2026'));
      expect(testSprint.daysRemaining, isNotNull);
    });
  });

  group('KanbanBoardState Tests', () {
    test('computes issues and story points for each status column correctly', () {
      final state = KanbanBoardState(
        allIssues: testIssues,
        activeSprint: testSprint,
        projectKey: 'OVS',
      );

      expect(state.issuesForStatus(IssueStatus.todo).length, 1);
      expect(state.issuesForStatus(IssueStatus.inProgress).length, 1);
      expect(state.issuesForStatus(IssueStatus.inReview).length, 1);
      expect(state.issuesForStatus(IssueStatus.done).length, 1);

      expect(state.storyPointsForStatus(IssueStatus.todo), 5.0);
      expect(state.storyPointsForStatus(IssueStatus.inProgress), 8.0);
      expect(state.storyPointsForStatus(IssueStatus.inReview), 3.0);
      expect(state.storyPointsForStatus(IssueStatus.done), 1.0);

      expect(state.totalIssues, 4);
      expect(state.totalStoryPoints, 17.0);
    });

    test('filters issues by search query matching key or title', () {
      final state = KanbanBoardState(
        allIssues: testIssues,
        activeSprint: testSprint,
        projectKey: 'OVS',
        searchQuery: 'backend',
      );

      expect(state.filteredIssues.length, 1);
      expect(state.filteredIssues.first.issueNumber, 101);

      final stateByKey = state.copyWith(searchQuery: 'OVS-104');
      expect(stateByKey.filteredIssues.length, 1);
      expect(stateByKey.filteredIssues.first.issueNumber, 104);
    });

    test('filters issues by type and priority', () {
      final state = KanbanBoardState(
        allIssues: testIssues,
        activeSprint: testSprint,
        projectKey: 'OVS',
        selectedTypes: {IssueType.bug},
      );

      expect(state.filteredIssues.length, 1);
      expect(state.filteredIssues.first.type, IssueType.bug);

      final statePriority = state.copyWith(
        selectedTypes: {},
        selectedPriorities: {IssuePriority.urgent},
      );
      expect(statePriority.filteredIssues.length, 1);
      expect(statePriority.filteredIssues.first.priority, IssuePriority.urgent);
    });
  });

  group('Kanban Widgets Tests', () {
    testWidgets('KanbanIssueCard renders key, title, priority, SP, sub-issues and assignee',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KanbanIssueCard(
              issue: testIssues[0], // subIssueCount: 4, completed: 2, estimate: 5.0
              projectKey: 'OVS',
            ),
          ),
        ),
      );

      expect(find.text('OVS-101'), findsOneWidget);
      expect(find.text('Build backend API'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('5 pts'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
    });

    testWidgets('KanbanColumnWidget renders header with status, card count, and issues',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: KanbanColumnWidget(
                status: IssueStatus.todo,
                issues: [testIssues[0]],
                totalStoryPoints: 5.0,
                projectKey: 'OVS',
              ),
            ),
          ),
        ),
      );

      expect(find.text('To Do'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // card count badge
      expect(find.text('5 pts'), findsOneWidget); // story points badge
      expect(find.text('Build backend API'), findsOneWidget);
    });

    testWidgets('KanbanBoardScreen renders No Active Sprint empty state when sprint is null',
        (tester) async {
      final fakeSprintRepo = FakeSprintRepository();
      fakeSprintRepo.mockActiveSprint = null;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sprintRepositoryProvider.overrideWithValue(fakeSprintRepo),
            issueRepositoryProvider.overrideWithValue(FakeIssueRepository()),
            projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
            secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
            authNotifierProvider.overrideWith(
              (ref) => AuthNotifier(
                authRepository: null as dynamic,
                storage: FakeSecureStorageService(),
              )..state = const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(id: 'u-1', email: 'test@oversee.local', fullName: 'Tester'),
                ),
            ),
          ],
          child: const MaterialApp(
            home: KanbanBoardScreen(
              workspaceId: 'ws-1',
              projectId: 'proj-1',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('No Active Sprint'), findsOneWidget);
      expect(find.text('Go to Sprint Planning'), findsOneWidget);
    });

    testWidgets('KanbanBoardScreen renders active sprint toolbar and 4 Kanban columns',
        (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1400, 900);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() => tester.binding.window.clearPhysicalSizeTestValue());

      final fakeSprintRepo = FakeSprintRepository();
      fakeSprintRepo.mockActiveSprint = testSprint;
      fakeSprintRepo.mockIssues = testIssues;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sprintRepositoryProvider.overrideWithValue(fakeSprintRepo),
            issueRepositoryProvider.overrideWithValue(FakeIssueRepository()),
            projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
            secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
            authNotifierProvider.overrideWith(
              (ref) => AuthNotifier(
                authRepository: null as dynamic,
                storage: FakeSecureStorageService(),
              )..state = const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(id: 'u-1', email: 'test@oversee.local', fullName: 'Tester'),
                ),
            ),
          ],
          child: const MaterialApp(
            home: KanbanBoardScreen(
              workspaceId: 'ws-1',
              projectId: 'proj-1',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Sprint 1'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('To Do'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('In Review'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      expect(find.text('Build backend API'), findsOneWidget);
      expect(find.text('Create Kanban UI'), findsOneWidget);
    });
  });
}
