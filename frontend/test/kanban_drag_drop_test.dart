import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/presentation/widgets/kanban_column_widget.dart';

class MockSprintRepository implements SprintRepository {
  SprintModel? mockActiveSprint;
  List<IssueModel> mockIssues = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<SprintModel?> getActiveSprint(String projectId) async => mockActiveSprint;

  @override
  Future<List<IssueModel>> getSprintIssues(String sprintId) async => List.from(mockIssues);
}

class MockIssueRepository implements IssueRepository {
  bool shouldFail = false;
  String failMessage = 'Backend validation error: 400 Bad Request';
  IssueModel? lastUpdated;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<IssueModel> updateIssueStatus(
    String issueId, {
    required IssueStatus status,
    bool? allowOpenSubissues,
  }) async {
    if (shouldFail) {
      throw AppException(message: failMessage);
    }
    lastUpdated = IssueModel(
      id: issueId,
      projectId: 'proj-1',
      issueNumber: 101,
      title: 'Mock Issue',
      status: status,
      reporterId: 'u-1',
    );
    return lastUpdated!;
  }
}

class MockProjectRepository implements ProjectRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ProjectModel> getProject(String projectId) async {
    return const ProjectModel(
      id: 'proj-1',
      workspaceId: 'ws-1',
      name: 'Oversee',
      key: 'OVS',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSprintRepository mockSprintRepo;
  late MockIssueRepository mockIssueRepo;
  late MockProjectRepository mockProjectRepo;
  late SprintModel activeSprint;

  setUp(() {
    activeSprint = SprintModel(
      id: 'sp-1',
      projectId: 'proj-1',
      name: 'Sprint Alpha',
      status: SprintStatus.active,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 15),
    );

    mockSprintRepo = MockSprintRepository();
    mockSprintRepo.mockActiveSprint = activeSprint;

    mockIssueRepo = MockIssueRepository();
    mockProjectRepo = MockProjectRepository();
  });

  group('Drag and Drop Status Updates & Workflow Validation', () {
    test('blocks transition to DONE when sub-issues are incomplete', () async {
      const issueWithOpenSubs = IssueModel(
        id: 'iss-parent',
        projectId: 'proj-1',
        issueNumber: 101,
        title: 'Feature with Sub-tasks',
        status: IssueStatus.inReview,
        reporterId: 'u-1',
        subIssueCount: 4,
        completedSubIssueCount: 2, // 2 open!
      );

      mockSprintRepo.mockIssues = [issueWithOpenSubs];

      final notifier = KanbanBoardNotifier(
        sprintRepository: mockSprintRepo,
        issueRepository: mockIssueRepo,
        projectRepository: mockProjectRepo,
        projectId: 'proj-1',
      );

      // Wait for initial load
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Attempt to move to DONE
      final success = await notifier.updateIssueStatus(
        'iss-parent',
        IssueStatus.done,
      );

      expect(success, isFalse);
      expect(notifier.state.errorMessage, contains('Cannot move to Done'));
      expect(notifier.state.errorMessage, contains('2 open sub-issues'));
      // Issue status remains inReview
      expect(notifier.state.allIssues.first.status, IssueStatus.inReview);
    });

    test('optimistically updates status and commits on backend success', () async {
      const validIssue = IssueModel(
        id: 'iss-valid',
        projectId: 'proj-1',
        issueNumber: 102,
        title: 'Simple Bugfix',
        status: IssueStatus.todo,
        reporterId: 'u-1',
        subIssueCount: 0,
        completedSubIssueCount: 0,
      );

      mockSprintRepo.mockIssues = [validIssue];

      final notifier = KanbanBoardNotifier(
        sprintRepository: mockSprintRepo,
        issueRepository: mockIssueRepo,
        projectRepository: mockProjectRepo,
        projectId: 'proj-1',
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final success = await notifier.updateIssueStatus(
        'iss-valid',
        IssueStatus.inProgress,
      );

      expect(success, isTrue);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.allIssues.first.status, IssueStatus.inProgress);
      expect(mockIssueRepo.lastUpdated?.status, IssueStatus.inProgress);
    });

    test('automatically rolls back card to original status when API rejects', () async {
      const validIssue = IssueModel(
        id: 'iss-rollback',
        projectId: 'proj-1',
        issueNumber: 103,
        title: 'Protected Issue',
        status: IssueStatus.todo,
        reporterId: 'u-1',
      );

      mockSprintRepo.mockIssues = [validIssue];
      mockIssueRepo.shouldFail = true;
      mockIssueRepo.failMessage = '403 Forbidden: You do not have permission to transition this issue';

      final notifier = KanbanBoardNotifier(
        sprintRepository: mockSprintRepo,
        issueRepository: mockIssueRepo,
        projectRepository: mockProjectRepo,
        projectId: 'proj-1',
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final success = await notifier.updateIssueStatus(
        'iss-rollback',
        IssueStatus.inProgress,
      );

      expect(success, isFalse);
      expect(notifier.state.errorMessage, contains('403 Forbidden'));
      // Assert rollback: Card must be back at IssueStatus.todo!
      expect(notifier.state.allIssues.first.status, IssueStatus.todo);
    });
  });

  group('DragTarget and Drop Target Visuals', () {
    testWidgets('KanbanColumnWidget accepts dropped issue and fires onIssueDropped',
        (tester) async {
      IssueModel? droppedIssue;

      const issueToDrop = IssueModel(
        id: 'iss-drop',
        projectId: 'proj-1',
        issueNumber: 105,
        title: 'Draggable Task',
        status: IssueStatus.todo,
        reporterId: 'u-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              child: KanbanColumnWidget(
                status: IssueStatus.inProgress,
                issues: const [],
                totalStoryPoints: 0.0,
                projectKey: 'OVS',
                onIssueDropped: (issue) {
                  droppedIssue = issue;
                },
              ),
            ),
          ),
        ),
      );

      // Verify column header
      expect(find.text('In Progress'), findsOneWidget);

      // Simulate dropping an issue directly into the DragTarget
      final dragTargetFinder = find.byType(DragTarget<IssueModel>);
      expect(dragTargetFinder, findsOneWidget);

      final dragTargetWidget = tester.widget<DragTarget<IssueModel>>(dragTargetFinder);
      dragTargetWidget.onAcceptWithDetails?.call(
        DragTargetDetails<IssueModel>(
          data: issueToDrop,
          offset: const Offset(100, 100),
        ),
      );

      expect(droppedIssue, isNotNull);
      expect(droppedIssue?.id, 'iss-drop');
    });
  });
}
