import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/issue/application/issue_detail_provider.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_activity_model.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_panel.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';

class FakeDetailIssueRepository implements IssueRepository {
  late IssueModel mockIssue;
  List<IssueModel> mockSubIssues = [];
  List<IssueActivityModel> mockActivities = [];
  bool shouldThrowOnUpdate = false;
  int updateIssueCallCount = 0;
  int updateStatusCallCount = 0;
  int updateAssigneeCallCount = 0;
  int updatePriorityCallCount = 0;
  int createSubIssueCallCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<IssueModel> getIssue(String issueId) async {
    return mockIssue;
  }

  @override
  Future<List<IssueModel>> listSubIssues(String issueId) async {
    return List.from(mockSubIssues);
  }

  @override
  Future<List<IssueActivityModel>> listIssueActivities(String issueId) async {
    return List.from(mockActivities);
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
  }) async {
    updateIssueCallCount++;
    if (shouldThrowOnUpdate) {
      throw const AppException(message: 'Failed to update issue');
    }
    mockIssue = mockIssue.copyWith(
      title: title ?? mockIssue.title,
      description: description ?? mockIssue.description,
      type: type ?? mockIssue.type,
      status: status ?? mockIssue.status,
      priority: priority ?? mockIssue.priority,
      estimate: estimate ?? mockIssue.estimate,
      assigneeId: assigneeId ?? mockIssue.assigneeId,
    );
    return mockIssue;
  }

  @override
  Future<IssueModel> updateIssueStatus(
    String issueId, {
    required IssueStatus status,
    bool? allowOpenSubissues,
  }) async {
    updateStatusCallCount++;
    if (shouldThrowOnUpdate) {
      throw const AppException(message: 'Failed to update status');
    }
    // Check if updating sub-issue
    final subIdx = mockSubIssues.indexWhere((s) => s.id == issueId);
    if (subIdx != -1) {
      mockSubIssues[subIdx] = mockSubIssues[subIdx].copyWith(status: status);
      return mockSubIssues[subIdx];
    }
    mockIssue = mockIssue.copyWith(status: status);
    return mockIssue;
  }

  @override
  Future<IssueModel> updateIssueAssignee(String issueId, String? assigneeId) async {
    updateAssigneeCallCount++;
    mockIssue = mockIssue.copyWith(assigneeId: assigneeId);
    return mockIssue;
  }

  @override
  Future<IssueModel> updateIssuePriority(String issueId, IssuePriority priority) async {
    updatePriorityCallCount++;
    mockIssue = mockIssue.copyWith(priority: priority);
    return mockIssue;
  }

  @override
  Future<IssueModel> createSubIssue(
    String projectId,
    String parentIssueId, {
    required String title,
    IssuePriority priority = IssuePriority.medium,
    double? estimate,
    String? assigneeId,
  }) async {
    createSubIssueCallCount++;
    final sub = IssueModel(
      id: 'sub-${mockSubIssues.length + 1}',
      projectId: projectId,
      issueNumber: 200 + mockSubIssues.length + 1,
      title: title,
      type: IssueType.subtask,
      status: IssueStatus.todo,
      priority: priority,
      estimate: estimate,
      parentId: parentIssueId,
      reporterId: 'u-1',
    );
    mockSubIssues.add(sub);
    return sub;
  }
}

class FakeDetailProjectRepository implements ProjectRepository {
  List<ProjectMemberModel> mockMembers = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async {
    return const ProjectModel(id: 'proj-1', workspaceId: 'ws-1', name: 'Oversee', key: 'OVS');
  }

  @override
  Future<List<ProjectMemberModel>> listProjectMembers(String projectId) async {
    return List.from(mockMembers);
  }
}

void main() {
  final testDate = DateTime(2026, 11, 16, 1, 0, 0);

  const testParentIssue = IssueModel(
    id: 'iss-parent-1',
    projectId: 'proj-1',
    issueNumber: 101,
    title: 'Implement Authentication Architecture',
    description: '### Context\nNeed to support JWT token refresh.',
    type: IssueType.story,
    status: IssueStatus.inProgress,
    priority: IssuePriority.high,
    estimate: 8.0,
    reporterId: 'u-1',
    assignee: UserModel(id: 'u-alice', email: 'alice@oversee.local', fullName: 'Alice Dev'),
    subIssueCount: 2,
    completedSubIssueCount: 1,
  );

  final testSubIssues = [
    const IssueModel(
      id: 'sub-1',
      projectId: 'proj-1',
      issueNumber: 102,
      title: 'Build token storage',
      type: IssueType.subtask,
      status: IssueStatus.done,
      priority: IssuePriority.medium,
      estimate: 3.0,
      reporterId: 'u-1',
      parentId: 'iss-parent-1',
    ),
    const IssueModel(
      id: 'sub-2',
      projectId: 'proj-1',
      issueNumber: 103,
      title: 'Write token rotation unit tests',
      type: IssueType.subtask,
      status: IssueStatus.todo,
      priority: IssuePriority.low,
      estimate: 2.0,
      reporterId: 'u-1',
      parentId: 'iss-parent-1',
    ),
  ];

  final testActivities = [
    IssueActivityModel(
      id: 'act-1',
      issueId: 'iss-parent-1',
      actorId: 'u-1',
      action: 'created',
      createdAt: testDate.subtract(const Duration(hours: 3)),
      actorName: 'Cuong Nguyen',
    ),
    IssueActivityModel(
      id: 'act-2',
      issueId: 'iss-parent-1',
      actorId: 'u-1',
      action: 'status_changed',
      oldValue: 'To Do',
      newValue: 'In Progress',
      createdAt: testDate.subtract(const Duration(minutes: 45)),
      actorName: 'Cuong Nguyen',
    ),
  ];

  final testMembers = [
    const ProjectMemberModel(
      id: 'pm-1',
      projectId: 'proj-1',
      userId: 'u-alice',
      role: RoleType.member,
      user: UserModel(id: 'u-alice', email: 'alice@oversee.local', fullName: 'Alice Dev'),
    ),
    const ProjectMemberModel(
      id: 'pm-2',
      projectId: 'proj-1',
      userId: 'u-bob',
      role: RoleType.member,
      user: UserModel(id: 'u-bob', email: 'bob@oversee.local', fullName: 'Bob Dev'),
    ),
  ];

  group('IssueActivityModel Unit Tests', () {
    test('serializes and deserializes accurately from JSON', () {
      final act = testActivities[1];
      final json = act.toJson();
      expect(json['action'], 'status_changed');
      expect(json['old_value'], 'To Do');
      expect(json['new_value'], 'In Progress');

      final reconstructed = IssueActivityModel.fromJson(json);
      expect(reconstructed.id, act.id);
      expect(reconstructed.actionLabel, 'changed status');
      expect(reconstructed.transitionText, 'To Do  →  In Progress');
      expect(reconstructed.actorName, 'Cuong Nguyen');
    });

    test('generates correct actionLabel for various action types', () {
      expect(
        IssueActivityModel(id: '1', issueId: 'i', actorId: 'a', action: 'priority_changed', createdAt: testDate).actionLabel,
        'changed priority',
      );
      expect(
        IssueActivityModel(id: '2', issueId: 'i', actorId: 'a', action: 'assignee_changed', createdAt: testDate).actionLabel,
        'changed assignee',
      );
      expect(
        IssueActivityModel(id: '3', issueId: 'i', actorId: 'a', action: 'description_changed', createdAt: testDate).actionLabel,
        'updated description',
      );
    });
  });

  group('IssueDetailNotifier Unit Tests', () {
    late FakeDetailIssueRepository issueRepo;
    late FakeDetailProjectRepository projectRepo;

    setUp(() {
      issueRepo = FakeDetailIssueRepository()
        ..mockIssue = testParentIssue
        ..mockSubIssues = List.from(testSubIssues)
        ..mockActivities = List.from(testActivities);
      projectRepo = FakeDetailProjectRepository()..mockMembers = List.from(testMembers);
    });

    test('loadDetails loads issue, sub-issues, activities, and project members', () async {
      final notifier = IssueDetailNotifier(
        projectId: 'proj-1',
        initialIssue: testParentIssue,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );

      await notifier.loadDetails();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.subIssues.length, 2);
      expect(notifier.state.activities.length, 2);
      expect(notifier.state.members.length, 2);
      expect(notifier.state.totalSubIssues, 2);
      expect(notifier.state.completedSubIssues, 1);
      expect(notifier.state.subIssuesProgress, 0.5);
    });

    test('updateTitle updates state and calls repository', () async {
      final notifier = IssueDetailNotifier(
        projectId: 'proj-1',
        initialIssue: testParentIssue,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );

      final success = await notifier.updateTitle('Brand New Title');
      expect(success, isTrue);
      expect(notifier.state.issue.title, 'Brand New Title');
      expect(issueRepo.updateIssueCallCount, 1);
    });

    test('updateStatus blocks Done transition when open sub-issues exist', () async {
      final notifier = IssueDetailNotifier(
        projectId: 'proj-1',
        initialIssue: testParentIssue,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadDetails();

      // sub-2 is still in To Do status
      final success = await notifier.updateStatus(IssueStatus.done);
      expect(success, isFalse);
      expect(notifier.state.errorMessage, contains('Cannot move to Done'));
      expect(notifier.state.issue.status, IssueStatus.inProgress);
    });

    test('updateStatus allows transition when allowed or sub-issues resolved', () async {
      final notifier = IssueDetailNotifier(
        projectId: 'proj-1',
        initialIssue: testParentIssue,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadDetails();

      final success = await notifier.updateStatus(IssueStatus.done, allowOpenSubissues: true);
      expect(success, isTrue);
      expect(notifier.state.issue.status, IssueStatus.done);
    });

    test('updatePriority and updateAssignee update state', () async {
      final notifier = IssueDetailNotifier(
        projectId: 'proj-1',
        initialIssue: testParentIssue,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );

      await notifier.updatePriority(IssuePriority.urgent);
      expect(notifier.state.issue.priority, IssuePriority.urgent);
      expect(issueRepo.updatePriorityCallCount, 1);

      await notifier.updateAssignee('u-bob');
      expect(notifier.state.issue.assigneeId, 'u-bob');
      expect(issueRepo.updateAssigneeCallCount, 1);
    });

    test('createSubTask adds subtask and increments subIssueCount', () async {
      final notifier = IssueDetailNotifier(
        projectId: 'proj-1',
        initialIssue: testParentIssue,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadDetails();

      final success = await notifier.createSubTask('New third subtask', estimate: 1.0);
      expect(success, isTrue);
      expect(notifier.state.subIssues.length, 3);
      expect(notifier.state.issue.subIssueCount, 3);
      expect(issueRepo.createSubIssueCallCount, 1);
    });

    test('toggleSubTaskStatus toggles status and recalculates progress', () async {
      final notifier = IssueDetailNotifier(
        projectId: 'proj-1',
        initialIssue: testParentIssue,
        issueRepository: issueRepo,
        projectRepository: projectRepo,
      );
      await notifier.loadDetails();

      // sub-2 was To Do -> toggle to done
      final success = await notifier.toggleSubTaskStatus('sub-2', true);
      expect(success, isTrue);
      expect(notifier.state.completedSubIssues, 2);
      expect(notifier.state.subIssuesProgress, 1.0);
    });
  });

  group('IssueDetailPanel Widget Tests', () {
    late FakeDetailIssueRepository fakeIssueRepo;
    late FakeDetailProjectRepository fakeProjectRepo;

    setUp(() {
      fakeIssueRepo = FakeDetailIssueRepository()
        ..mockIssue = testParentIssue
        ..mockSubIssues = List.from(testSubIssues)
        ..mockActivities = List.from(testActivities);
      fakeProjectRepo = FakeDetailProjectRepository()..mockMembers = List.from(testMembers);
    });

    Widget createTestWidget({Size size = const Size(1200, 800)}) {
      return ProviderScope(
        overrides: [
          issueRepositoryProvider.overrideWithValue(fakeIssueRepo),
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: const Scaffold(
              body: IssueDetailPanel(
                projectId: 'proj-1',
                projectKey: 'OVS',
                issue: testParentIssue,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders issue key, title, status, priority, and story points', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('OVS-101'), findsOneWidget);
      expect(find.text('Story'), findsOneWidget);
      expect(find.text('Implement Authentication Architecture'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('8'), findsOneWidget); // estimate field
    });

    testWidgets('toggles between Description Write mode and Preview mode', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Write'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);

      // Tap Preview button
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      // MarkdownBody is rendered
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining('Context'), findsOneWidget);

      // Tap Write button to switch back
      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownBody), findsNothing);
    });

    testWidgets('renders sub-tasks checklist, progress indicator, and quick add subtask',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sub-tasks'), findsOneWidget);
      expect(find.text('1 of 2 completed'), findsOneWidget);
      expect(find.text('Build token storage'), findsOneWidget);
      expect(find.text('Write token rotation unit tests'), findsOneWidget);

      // Type into "Add a subtask..." field and tap Add
      final addField = find.widgetWithText(TextField, 'Add a subtask...');
      expect(addField, findsOneWidget);
      await tester.enterText(addField, 'Check refreshToken expiration');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(fakeIssueRepo.createSubIssueCallCount, 1);
      expect(find.text('Check refreshToken expiration'), findsOneWidget);
    });

    testWidgets('renders activity history audit log with transition text', (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Activity History'), findsOneWidget);
      expect(find.text('Cuong Nguyen'), findsNWidgets(2));
      expect(find.text('changed status'), findsOneWidget);
      expect(find.text('To Do  →  In Progress'), findsOneWidget);
    });

    testWidgets('IssueDetailPanel.show opens bottom sheet on mobile screens (< 768px)', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            issueRepositoryProvider.overrideWithValue(fakeIssueRepo),
            projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: Text('Home'));
              },
            ),
          ),
        ),
      );

      unawaited(
        IssueDetailPanel.show(
          capturedContext,
          projectId: 'proj-1',
          projectKey: 'OVS',
          issue: testParentIssue,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(IssueDetailPanel), findsOneWidget);
    });

    testWidgets('IssueDetailPanel.show opens slide-in drawer dialog on desktop screens (>= 768px)', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            issueRepositoryProvider.overrideWithValue(fakeIssueRepo),
            projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: Text('Home'));
              },
            ),
          ),
        ),
      );

      unawaited(
        IssueDetailPanel.show(
          capturedContext,
          projectId: 'proj-1',
          projectKey: 'OVS',
          issue: testParentIssue,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(IssueDetailPanel), findsOneWidget);
    });
  });
}
