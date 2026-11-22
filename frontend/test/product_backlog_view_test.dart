import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/application/backlog_state.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/backlog_screen.dart';
import 'package:frontend/features/issue/presentation/widgets/backlog_item_card.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/features/issue/presentation/widgets/quick_create_issue_bar.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';

class FakeIssueRepository implements IssueRepository {
  List<IssueModel> mockIssues = [
    const IssueModel(
      id: 'iss-1',
      projectId: 'proj-1',
      issueNumber: 101,
      title: 'Design database schema',
      type: IssueType.task,
      status: IssueStatus.backlog,
      priority: IssuePriority.high,
      estimate: 5.0,
      backlogRank: 100.0,
      reporterId: 'user-1',
      subIssueCount: 3,
      completedSubIssueCount: 2,
    ),
    const IssueModel(
      id: 'iss-2',
      projectId: 'proj-1',
      issueNumber: 102,
      title: 'Setup user authentication',
      type: IssueType.story,
      status: IssueStatus.backlog,
      priority: IssuePriority.urgent,
      estimate: 8.0,
      backlogRank: 200.0,
      reporterId: 'user-1',
      assignee: UserModel(id: 'u-2', email: 'dev@oversee.local', fullName: 'Dan Dev'),
    ),
    const IssueModel(
      id: 'iss-3',
      projectId: 'proj-1',
      issueNumber: 103,
      title: 'Fix token refresh bug',
      type: IssueType.bug,
      status: IssueStatus.backlog,
      priority: IssuePriority.medium,
      estimate: 2.0,
      backlogRank: 300.0,
      reporterId: 'user-1',
    ),
  ];

  bool shouldThrowOnList = false;
  bool shouldThrowOnCreate = false;
  bool shouldThrowOnReorder = false;

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
    if (shouldThrowOnList) {
      throw const AppException(message: 'Failed to fetch backlog issues');
    }
    return IssuePageModel(
      items: List.from(mockIssues),
      total: mockIssues.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<IssueModel> createIssue(
    String projectId, {
    required String title,
    String? description,
    IssueType type = IssueType.task,
    IssueStatus? status,
    IssuePriority priority = IssuePriority.medium,
    double? estimate,
    String? assigneeId,
    String? sprintId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (shouldThrowOnCreate) {
      throw const AppException(message: 'Failed to create issue');
    }
    final newIssue = IssueModel(
      id: 'iss-new-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      issueNumber: 104,
      title: title,
      type: type,
      priority: priority,
      estimate: estimate,
      backlogRank: 400.0,
      reporterId: 'user-1',
    );
    return newIssue;
  }

  @override
  Future<void> addIssueToBacklog(String projectId, {required String issueId}) async {}

  @override
  Future<IssueModel> reorderBacklog(
    String projectId, {
    required String issueId,
    String? previousIssueId,
    String? nextIssueId,
    double? targetRank,
    String? position,
  }) async {
    if (shouldThrowOnReorder) {
      throw const AppException(message: 'Reorder rejected by server');
    }
    final issue = mockIssues.firstWhere((i) => i.id == issueId);
    return issue.copyWith(backlogRank: 150.0);
  }

  @override
  Future<IssueModel> updateIssue(
    String issueId, {
    String? title,
    String? description,
    IssueType? type,
    IssueStatus? status,
    IssuePriority? priority,
    double? estimate,
    String? assigneeId,
    String? sprintId,
    bool clearSprint = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    final index = mockIssues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      mockIssues[index] = mockIssues[index].copyWith(
        title: title ?? mockIssues[index].title,
        description: description ?? mockIssues[index].description,
        type: type ?? mockIssues[index].type,
        status: status ?? mockIssues[index].status,
        priority: priority ?? mockIssues[index].priority,
        estimate: estimate ?? mockIssues[index].estimate,
      );
      return mockIssues[index];
    }
    throw const AppException(message: 'Issue not found');
  }
}

class FakeProjectRepository implements ProjectRepository {
  ProjectModel mockProject = const ProjectModel(
    id: 'proj-1',
    workspaceId: 'ws-1',
    name: 'Oversee Core',
    key: 'OVS',
    description: 'Core project',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async {
    return mockProject;
  }

  @override
  Future<List<ProjectMemberModel>> listProjectMembers(String projectId) async {
    return [];
  }
}

class FakeSecureStorageService implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<String?> getAccessToken() async => 'mock-token';
  @override
  Future<String?> getRefreshToken() async => 'mock-refresh';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IssueModel & IssuePageModel Unit Tests', () {
    test('serializes and deserializes correctly', () {
      final json = {
        'id': 'iss-10',
        'project_id': 'proj-1',
        'issue_number': 42,
        'title': 'Test Story',
        'type': 'story',
        'status': 'backlog',
        'priority': 'high',
        'estimate': 5.5,
        'backlog_rank': 120.0,
        'reporter_id': 'user-1',
        'sub_issues': [
          {'id': 'sub-1', 'status': 'done'},
          {'id': 'sub-2', 'status': 'in_progress'},
        ],
      };

      final issue = IssueModel.fromJson(json);
      expect(issue.id, equals('iss-10'));
      expect(issue.issueNumber, equals(42));
      expect(issue.type, equals(IssueType.story));
      expect(issue.priority, equals(IssuePriority.high));
      expect(issue.estimate, equals(5.5));
      expect(issue.subIssueCount, equals(2));
      expect(issue.completedSubIssueCount, equals(1));
      expect(issue.formattedKey('OVS'), equals('OVS-42'));

      final out = issue.toJson();
      expect(out['type'], equals('story'));
      expect(out['priority'], equals('high'));
      expect(out['estimate'], equals(5.5));
    });

    test('IssuePageModel correctly parses items and total', () {
      final json = {
        'items': [
          {
            'id': 'iss-1',
            'project_id': 'proj-1',
            'issue_number': 1,
            'title': 'Task 1',
            'type': 'task',
            'status': 'backlog',
            'priority': 'low',
            'reporter_id': 'user-1',
          }
        ],
        'total': 1,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      };

      final page = IssuePageModel.fromJson(json);
      expect(page.items.length, equals(1));
      expect(page.total, equals(1));
      expect(page.items.first.title, equals('Task 1'));
    });
  });

  group('BacklogState Filter & Calculation Tests', () {
    test('filters issues by search query matching title or key', () {
      const state = BacklogState(
        project: ProjectModel(id: 'proj-1', workspaceId: 'ws-1', name: 'Test', key: 'OVS'),
        issues: [
          IssueModel(id: '1', projectId: 'proj-1', issueNumber: 1, title: 'Authentication', reporterId: 'u-1'),
          IssueModel(id: '2', projectId: 'proj-1', issueNumber: 2, title: 'Database Index', reporterId: 'u-1'),
        ],
        searchQuery: 'auth',
      );

      final filtered = state.filteredIssues;
      expect(filtered.length, equals(1));
      expect(filtered.first.title, equals('Authentication'));
    });

    test('filters issues by type and priority', () {
      const state = BacklogState(
        issues: [
          IssueModel(id: '1', projectId: 'p', issueNumber: 1, title: 'T1', type: IssueType.bug, priority: IssuePriority.urgent, reporterId: 'u'),
          IssueModel(id: '2', projectId: 'p', issueNumber: 2, title: 'T2', type: IssueType.task, priority: IssuePriority.low, reporterId: 'u'),
        ],
        selectedType: IssueType.bug,
        selectedPriority: IssuePriority.urgent,
      );

      expect(state.filteredIssues.length, equals(1));
      expect(state.filteredIssues.first.title, equals('T1'));
    });

    test('computes totalStoryPoints correctly', () {
      const state = BacklogState(
        issues: [
          IssueModel(id: '1', projectId: 'p', issueNumber: 1, title: 'T1', estimate: 3.0, reporterId: 'u'),
          IssueModel(id: '2', projectId: 'p', issueNumber: 2, title: 'T2', estimate: 5.5, reporterId: 'u'),
          IssueModel(id: '3', projectId: 'p', issueNumber: 3, title: 'T3', estimate: null, reporterId: 'u'),
        ],
      );

      expect(state.totalStoryPoints, equals(8.5));
    });
  });

  group('BacklogNotifier Unit Tests', () {
    late FakeIssueRepository issueRepo;
    late FakeProjectRepository projectRepo;

    setUp(() {
      issueRepo = FakeIssueRepository();
      projectRepo = FakeProjectRepository();
    });

    test('loadBacklog loads and sorts issues by rank', () async {
      final notifier = BacklogNotifier(
        projectId: 'proj-1',
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );

      await notifier.loadBacklog();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.issues.length, equals(3));
      expect(notifier.state.issues[0].backlogRank, equals(100.0));
      expect(notifier.state.issues[1].backlogRank, equals(200.0));
      expect(notifier.state.issues[2].backlogRank, equals(300.0));
    });

    test('quickCreateIssue adds newly created issue to state immediately', () async {
      final notifier = BacklogNotifier(
        projectId: 'proj-1',
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadBacklog();

      final success = await notifier.quickCreateIssue(
        'Implement OAuth2',
        type: IssueType.story,
        priority: IssuePriority.high,
      );

      expect(success, isTrue);
      expect(notifier.state.issues.length, equals(4));
      expect(notifier.state.issues.last.title, equals('Implement OAuth2'));
    });

    test('reorderBacklog optimistically moves item and updates rank', () async {
      final notifier = BacklogNotifier(
        projectId: 'proj-1',
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadBacklog();

      // Move item at index 2 (iss-3) to index 0
      final success = await notifier.reorderBacklog(2, 0);
      expect(success, isTrue);
      expect(notifier.state.issues.first.id, equals('iss-3'));
    });

    test('reorderBacklog rolls back list order on server failure', () async {
      issueRepo.shouldThrowOnReorder = true;
      final notifier = BacklogNotifier(
        projectId: 'proj-1',
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadBacklog();

      final originalFirst = notifier.state.issues.first.id;
      final success = await notifier.reorderBacklog(2, 0);

      expect(success, isFalse);
      // Rolled back to original first item
      expect(notifier.state.issues.first.id, equals(originalFirst));
      expect(notifier.state.errorMessage, contains('Reorder rejected by server'));
    });
  });

  group('Backlog Screen & Widgets Tests', () {
    late FakeIssueRepository issueRepo;
    late FakeProjectRepository projectRepo;

    setUp(() {
      issueRepo = FakeIssueRepository();
      projectRepo = FakeProjectRepository();
    });

    Widget createTestApp({required Widget child}) {
      return ProviderScope(
        overrides: [
          issueRepositoryProvider.overrideWithValue(issueRepo),
          projectRepositoryProvider.overrideWithValue(projectRepo),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
          authNotifierProvider.overrideWith((ref) => AuthNotifier(
                FakeSecureStorageService(),
                initialState: const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(id: 'u-1', email: 'user@oversee.local', fullName: 'Tester'),
                ),
              )),
          backlogNotifierProvider('proj-1').overrideWith((ref) => BacklogNotifier(
                projectId: 'proj-1',
                issueRepository: issueRepo,
                projectRepository: projectRepo,
                initialState: BacklogState(
                  isLoading: false,
                  project: projectRepo.mockProject,
                  issues: List.from(issueRepo.mockIssues),
                ),
              )),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('BacklogScreen renders toolbar, quick create bar, and backlog items', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        createTestApp(
          child: const BacklogScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Product Backlog'), findsWidgets);
      expect(find.text('3 issues'), findsOneWidget);
      expect(find.text('15 SP'), findsOneWidget);
      expect(find.byType(QuickCreateIssueBar), findsOneWidget);
      expect(find.byType(BacklogItemCard), findsNWidgets(3));

      expect(find.text('Design database schema'), findsOneWidget);
      expect(find.text('Setup user authentication'), findsOneWidget);
      expect(find.text('Fix token refresh bug'), findsOneWidget);
      expect(find.text('OVS-101'), findsOneWidget);
    });

    testWidgets('QuickCreateIssueBar submittal creates new issue and inserts into list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        createTestApp(
          child: const BacklogScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(TextField).first;
      await tester.enterText(input, 'New Quick Issue');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('New Quick Issue'), findsOneWidget);
    });

    testWidgets('Tapping BacklogItemCard opens IssueDetailDialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        createTestApp(
          child: const BacklogScreen(
            workspaceId: 'ws-1',
            projectId: 'proj-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstCard = find.text('Design database schema');
      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      expect(find.byType(IssueDetailDialog), findsOneWidget);
      expect(find.text('OVS-101 - Issue Details'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });
}
