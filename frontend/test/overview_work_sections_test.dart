import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/auth/domain/user_model.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/widgets/overview_work_sections_row.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';

void main() {
  group('Overview 3-column horizontal work sections', () {
    testWidgets('renders My Ongoing Jobs, Upcoming Jobs, and Participant Workloads with equal span',
        (tester) async {
      final now = DateTime.now();
      const vincent = UserModel(id: 'u-vincent', email: 'vincentt@mail.com', fullName: 'Vincent');
      const alice = UserModel(id: 'u-alice', email: 'alice@oversee.dev', fullName: 'Alice Nguyen');

      const activeSprint = SprintModel(
        id: 'sp-1',
        projectId: 'p-1',
        name: 'Sprint 1',
        status: SprintStatus.active,
      );
      const plannedSprint = SprintModel(
        id: 'sp-2',
        projectId: 'p-1',
        name: 'Sprint 2',
        status: SprintStatus.planned,
      );

      final issues = [
        IssueModel(
          id: 'i-1',
          projectId: 'p-1',
          issueNumber: 1,
          title: 'Build EN/VI switcher',
          status: IssueStatus.inProgress,
          priority: IssuePriority.high,
          estimate: 5,
          reporterId: vincent.id,
          assigneeId: vincent.id,
          assignee: vincent,
          sprintId: activeSprint.id,
        ),
        IssueModel(
          id: 'i-2',
          projectId: 'p-1',
          issueNumber: 2,
          title: 'Schedule Sprint 2 analytics',
          status: IssueStatus.todo,
          priority: IssuePriority.medium,
          estimate: 3,
          reporterId: vincent.id,
          assigneeId: alice.id,
          assignee: alice,
          sprintId: plannedSprint.id,
          startDate: now.add(const Duration(days: 5)),
        ),
        IssueModel(
          id: 'i-3',
          projectId: 'p-1',
          issueNumber: 3,
          title: 'Finish JWT rotation',
          status: IssueStatus.done,
          priority: IssuePriority.high,
          estimate: 5,
          reporterId: vincent.id,
          assigneeId: vincent.id,
          assignee: vincent,
          sprintId: activeSprint.id,
        ),
      ];

      final state = ProjectOverviewState(
        project: const ProjectModel(
          id: 'p-1',
          workspaceId: 'ws-1',
          name: 'Oversee Platform',
          key: 'OVS',
        ),
        members: [
          ProjectMemberModel(
            id: 'pm-1',
            projectId: 'p-1',
            userId: vincent.id,
            role: RoleType.owner,
            user: vincent,
          ),
          ProjectMemberModel(
            id: 'pm-2',
            projectId: 'p-1',
            userId: alice.id,
            role: RoleType.admin,
            user: alice,
          ),
        ],
        sprints: const [activeSprint, plannedSprint],
        activeSprint: activeSprint,
        sprintIssues: [issues[0], issues[2]],
        projectIssues: issues,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OverviewWorkSectionsRow(
                state: state,
                workspaceId: 'ws-1',
                projectId: 'p-1',
                currentUserId: vincent.id,
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('overview_section_ongoing_jobs')), findsOneWidget);
      expect(find.byKey(const Key('overview_section_upcoming_jobs')), findsOneWidget);
      expect(find.byKey(const Key('overview_section_participant_workloads')), findsOneWidget);

      expect(find.text('My Ongoing Jobs'), findsOneWidget);
      expect(find.text('Upcoming Jobs'), findsOneWidget);
      expect(find.text('Project Participant Workloads'), findsOneWidget);

      expect(find.text('Build EN/VI switcher'), findsOneWidget);
      expect(find.text('Schedule Sprint 2 analytics'), findsOneWidget);
      expect(find.text('Vincent'), findsOneWidget);
      expect(find.text('Alice Nguyen'), findsOneWidget);

      final ongoingBox = tester.getRect(find.byKey(const Key('overview_section_ongoing_jobs')));
      final upcomingBox = tester.getRect(find.byKey(const Key('overview_section_upcoming_jobs')));
      final workloadsBox =
          tester.getRect(find.byKey(const Key('overview_section_participant_workloads')));

      expect(ongoingBox.top, closeTo(upcomingBox.top, 1.0));
      expect(upcomingBox.top, closeTo(workloadsBox.top, 1.0));
      expect(ongoingBox.width, closeTo(upcomingBox.width, 1.0));
      expect(upcomingBox.width, closeTo(workloadsBox.width, 1.0));
      expect(ongoingBox.height, closeTo(upcomingBox.height, 1.0));
      expect(upcomingBox.height, closeTo(workloadsBox.height, 1.0));
    });
  });
}
