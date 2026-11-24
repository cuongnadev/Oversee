import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';

/// Aggregated workload summary for a project participant on the Overview screen.
class ParticipantWorkloadItem extends Equatable {
  final String? userId;
  final String name;
  final String? avatarUrl;
  final RoleType? role;
  final int totalIssues;
  final int completedIssues;
  final int inProgressIssues;
  final double totalStoryPoints;

  const ParticipantWorkloadItem({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.role,
    required this.totalIssues,
    required this.completedIssues,
    required this.inProgressIssues,
    required this.totalStoryPoints,
  });

  int get openIssues => (totalIssues - completedIssues).clamp(0, totalIssues);

  double get completionRatio =>
      totalIssues > 0 ? (completedIssues / totalIssues).clamp(0.0, 1.0) : 0.0;

  int get completionPercentage => (completionRatio * 100).round();

  @override
  List<Object?> get props => [
        userId,
        name,
        avatarUrl,
        role,
        totalIssues,
        completedIssues,
        inProgressIssues,
        totalStoryPoints,
      ];
}

class ProjectOverviewState extends Equatable {
  final ProjectModel? project;
  final List<ProjectMemberModel> members;
  final RoleType currentUserRole;
  final bool isLoading;
  final String? errorMessage;
  final List<SprintModel> sprints;
  final SprintModel? activeSprint;
  final SprintProgressModel? sprintProgress;
  final List<IssueModel> sprintIssues;
  final List<IssueModel> projectIssues;

  const ProjectOverviewState({
    this.project,
    this.members = const [],
    this.currentUserRole = RoleType.viewer,
    this.isLoading = false,
    this.errorMessage,
    this.sprints = const [],
    this.activeSprint,
    this.sprintProgress,
    this.sprintIssues = const [],
    this.projectIssues = const [],
  });

  bool get isOwner => currentUserRole == RoleType.owner;
  bool get isAdmin => currentUserRole == RoleType.admin || isOwner;
  bool get canEdit => isAdmin;

  /// Full project issue list when available, falling back to active sprint issues.
  List<IssueModel> get effectiveProjectIssues =>
      projectIssues.isNotEmpty ? projectIssues : sprintIssues;

  int get totalIssues => sprintProgress?.totalIssues ?? sprintIssues.length;

  int get completedIssues =>
      sprintProgress?.completedIssues ??
      sprintIssues.where((i) => i.status == IssueStatus.done).length;

  int get inProgressIssues =>
      sprintIssues.where((i) => i.status == IssueStatus.inProgress).length;

  int get inReviewIssues =>
      sprintIssues.where((i) => i.status == IssueStatus.inReview).length;

  int get todoIssues =>
      sprintIssues.where((i) => i.status == IssueStatus.todo).length;

  int get blockerIssuesCount => sprintIssues
      .where(
        (i) =>
            (i.priority == IssuePriority.urgent || i.priority == IssuePriority.high) &&
            i.status != IssueStatus.done &&
            i.status != IssueStatus.canceled,
      )
      .length;

  double get completedStoryPoints =>
      sprintProgress?.completedStoryPoints ??
      sprintIssues
          .where((i) => i.status == IssueStatus.done)
          .fold<double>(0.0, (sum, i) => sum + (i.estimate ?? 0.0));

  double get totalStoryPoints =>
      sprintProgress?.totalStoryPoints ??
      sprintIssues.fold<double>(0.0, (sum, i) => sum + (i.estimate ?? 0.0));

  int get completionPercentage =>
      totalIssues > 0 ? (completedIssues / totalIssues * 100).round() : 0;

  /// Ongoing issues assigned to [userId] (In Progress, In Review, To Do).
  List<IssueModel> myOngoingJobsFor(String? userId) {
    if (userId == null || userId.isEmpty) return const [];
    int statusOrder(IssueStatus s) {
      switch (s) {
        case IssueStatus.inProgress:
          return 0;
        case IssueStatus.inReview:
          return 1;
        case IssueStatus.todo:
          return 2;
        default:
          return 9;
      }
    }

    final list = effectiveProjectIssues
        .where(
          (i) =>
              i.assigneeId == userId &&
              (i.status == IssueStatus.inProgress ||
                  i.status == IssueStatus.inReview ||
                  i.status == IssueStatus.todo),
        )
        .toList()
      ..sort((a, b) {
        final sCmp = statusOrder(a.status).compareTo(statusOrder(b.status));
        if (sCmp != 0) return sCmp;
        final pCmp = b.priority.index.compareTo(a.priority.index);
        if (pCmp != 0) return pCmp;
        final aDue = a.endDate;
        final bDue = b.endDate;
        if (aDue != null && bDue != null) return aDue.compareTo(bDue);
        if (aDue != null) return -1;
        if (bDue != null) return 1;
        return a.issueNumber.compareTo(b.issueNumber);
      });
    return list;
  }

  /// Upcoming open issues in planned sprints or with future start/due dates.
  List<IssueModel> upcomingJobs({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final todayStart = DateTime(reference.year, reference.month, reference.day);
    final plannedSprintIds = sprints
        .where((s) => s.status == SprintStatus.planned)
        .map((s) => s.id)
        .toSet();

    final list = effectiveProjectIssues.where((i) {
      if (i.status == IssueStatus.done || i.status == IssueStatus.canceled) {
        return false;
      }
      final inPlannedSprint = i.sprintId != null && plannedSprintIds.contains(i.sprintId);
      final hasFutureStart = i.startDate != null && !i.startDate!.isBefore(todayStart);
      final hasFutureEnd = i.endDate != null && !i.endDate!.isBefore(todayStart);
      return inPlannedSprint || hasFutureStart || hasFutureEnd;
    }).toList()
      ..sort((a, b) {
        final aDate = a.startDate ?? a.endDate;
        final bDate = b.startDate ?? b.endDate;
        if (aDate != null && bDate != null) {
          final cmp = aDate.compareTo(bDate);
          if (cmp != 0) return cmp;
        } else if (aDate != null) {
          return -1;
        } else if (bDate != null) {
          return 1;
        }
        return a.issueNumber.compareTo(b.issueNumber);
      });

    return list;
  }

  /// Per-participant workload breakdown across all project members and issues.
  List<ParticipantWorkloadItem> get participantWorkloads {
    final issues = effectiveProjectIssues;
    final Map<String?, List<IssueModel>> byAssignee = {};
    for (final issue in issues) {
      byAssignee.putIfAbsent(issue.assigneeId, () => []).add(issue);
    }

    final Map<String, ProjectMemberModel> memberByUserId = {
      for (final m in members) m.userId: m,
    };

    final Set<String> allUserIds = {
      ...memberByUserId.keys,
      ...byAssignee.keys.whereType<String>(),
    };

    final items = <ParticipantWorkloadItem>[];
    for (final userId in allUserIds) {
      final assigned = byAssignee[userId] ?? const <IssueModel>[];
      final member = memberByUserId[userId];
      final issueAssignee = assigned.firstWhere(
        (i) => i.assignee != null,
        orElse: () => const IssueModel(id: '', projectId: '', issueNumber: 0, title: '', reporterId: ''),
      ).assignee;

      final fullName = member?.user?.fullName.trim().isNotEmpty == true
          ? member!.user!.fullName.trim()
          : (issueAssignee?.fullName.trim().isNotEmpty == true
              ? issueAssignee!.fullName.trim()
              : (member?.user?.email ?? issueAssignee?.email ?? 'Member'));

      final avatarUrl = member?.user?.avatarUrl ?? issueAssignee?.avatarUrl;
      final completed = assigned.where((i) => i.status == IssueStatus.done).length;
      final inProgress = assigned
          .where((i) => i.status == IssueStatus.inProgress || i.status == IssueStatus.inReview)
          .length;
      final points = assigned.fold<double>(0.0, (sum, i) => sum + (i.estimate ?? 0.0));

      items.add(
        ParticipantWorkloadItem(
          userId: userId,
          name: fullName,
          avatarUrl: avatarUrl,
          role: member?.role,
          totalIssues: assigned.length,
          completedIssues: completed,
          inProgressIssues: inProgress,
          totalStoryPoints: points,
        ),
      );
    }

    final unassigned = byAssignee[null];
    if (unassigned != null && unassigned.isNotEmpty) {
      items.add(
        ParticipantWorkloadItem(
          userId: null,
          name: 'Unassigned',
          totalIssues: unassigned.length,
          completedIssues: unassigned.where((i) => i.status == IssueStatus.done).length,
          inProgressIssues: unassigned
              .where((i) => i.status == IssueStatus.inProgress || i.status == IssueStatus.inReview)
              .length,
          totalStoryPoints: unassigned.fold<double>(0.0, (sum, i) => sum + (i.estimate ?? 0.0)),
        ),
      );
    }

    items.sort((a, b) {
      if (a.userId == null && b.userId != null) return 1;
      if (b.userId == null && a.userId != null) return -1;
      final totalCmp = b.totalIssues.compareTo(a.totalIssues);
      if (totalCmp != 0) return totalCmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  ProjectOverviewState copyWith({
    ProjectModel? project,
    List<ProjectMemberModel>? members,
    RoleType? currentUserRole,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<SprintModel>? sprints,
    SprintModel? activeSprint,
    bool clearActiveSprint = false,
    SprintProgressModel? sprintProgress,
    bool clearSprintProgress = false,
    List<IssueModel>? sprintIssues,
    List<IssueModel>? projectIssues,
  }) {
    return ProjectOverviewState(
      project: project ?? this.project,
      members: members ?? this.members,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sprints: sprints ?? this.sprints,
      activeSprint: clearActiveSprint ? null : (activeSprint ?? this.activeSprint),
      sprintProgress: clearSprintProgress ? null : (sprintProgress ?? this.sprintProgress),
      sprintIssues: sprintIssues ?? this.sprintIssues,
      projectIssues: projectIssues ?? this.projectIssues,
    );
  }

  @override
  List<Object?> get props => [
        project,
        members,
        currentUserRole,
        isLoading,
        errorMessage,
        sprints,
        activeSprint,
        sprintProgress,
        sprintIssues,
        projectIssues,
      ];
}
