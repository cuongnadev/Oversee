import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';

/// Represents workload allocation and completion progress for a project member or unassigned bucket.
class AssigneeWorkloadModel extends Equatable {
  final String? userId;
  final String name;
  final String? email;
  final String? avatarUrl;
  final RoleType? role;
  final int totalIssues;
  final int completedIssues;
  final double totalStoryPoints;
  final double completedStoryPoints;

  const AssigneeWorkloadModel({
    this.userId,
    required this.name,
    this.email,
    this.avatarUrl,
    this.role,
    this.totalIssues = 0,
    this.completedIssues = 0,
    this.totalStoryPoints = 0.0,
    this.completedStoryPoints = 0.0,
  });

  double get completionRatio =>
      totalIssues > 0 ? (completedIssues / totalIssues).clamp(0.0, 1.0) : 0.0;

  double get completionPercentage => completionRatio * 100;

  @override
  List<Object?> get props => [
        userId,
        name,
        email,
        avatarUrl,
        role,
        totalIssues,
        completedIssues,
        totalStoryPoints,
        completedStoryPoints,
      ];
}

/// State of the Project Progress Dashboard.
class DashboardState extends Equatable {
  final bool isLoading;
  final String? errorMessage;
  final ProjectModel? project;
  final List<SprintModel> sprints;
  final SprintModel? selectedSprint;
  final SprintProgressModel? progress;
  final List<IssueModel> issues;
  final List<ProjectMemberModel> members;

  const DashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.project,
    this.sprints = const [],
    this.selectedSprint,
    this.progress,
    this.issues = const [],
    this.members = const [],
  });

  bool get hasActiveSprint =>
      selectedSprint != null && selectedSprint!.status == SprintStatus.active;

  /// Issues that are Urgent/High priority and not yet Done.
  List<IssueModel> get blockerIssues {
    return issues.where((issue) {
      final isHighPriority =
          issue.priority == IssuePriority.urgent || issue.priority == IssuePriority.high;
      return isHighPriority && issue.status != IssueStatus.done;
    }).toList();
  }

  /// Issues currently In Progress that haven't moved in 3+ days.
  List<IssueModel> get lingeringIssues {
    final now = DateTime.now();
    return issues.where((issue) {
      if (issue.status != IssueStatus.inProgress) return false;
      final refDate = issue.updatedAt ?? issue.createdAt;
      if (refDate == null) return false;
      return now.difference(refDate).inDays >= 3;
    }).toList();
  }

  /// Combined risk issues list (blockers + lingering issues, deduplicated).
  List<IssueModel> get riskIssues {
    final Map<String, IssueModel> map = {};
    for (final issue in blockerIssues) {
      map[issue.id] = issue;
    }
    for (final issue in lingeringIssues) {
      map[issue.id] = issue;
    }
    return map.values.toList();
  }

  /// Daily velocity in Story Points burned per elapsed day.
  double get burnVelocityPerDay {
    if (selectedSprint == null || selectedSprint!.startDate == null || progress == null) {
      return 0.0;
    }
    final now = DateTime.now();
    final start = selectedSprint!.startDate!;
    final elapsedDays = max(1, now.difference(start).inDays);
    final completedPoints = progress!.completedStoryPoints;
    if (completedPoints <= 0) return 0.0;
    return completedPoints / elapsedDays;
  }

  /// Estimated days remaining to complete remaining points based on velocity.
  int? get projectedDaysToCompletion {
    final velocity = burnVelocityPerDay;
    if (velocity <= 0 || progress == null) return null;
    final remainingPoints = progress!.remainingStoryPoints;
    if (remainingPoints <= 0) return 0;
    return (remainingPoints / velocity).ceil();
  }

  /// Whether the sprint is currently on schedule.
  bool get isOnTrack {
    if (selectedSprint == null || selectedSprint!.daysRemaining == null || progress == null) {
      return true;
    }
    final daysRemaining = selectedSprint!.daysRemaining!;
    final projected = projectedDaysToCompletion;
    if (projected == null) {
      // If no points completed yet but sprint has elapsed > 50%, at risk
      return daysRemaining > 3;
    }
    return projected <= daysRemaining;
  }

  /// Total number of tasks in the selected sprint.
  int get totalTasks => issues.length;

  /// Number of completed tasks in the selected sprint.
  int get completedTasks => issues.where((i) => i.status == IssueStatus.done).length;

  /// High priority blockers (Urgent / High priority and not Done).
  int get blockerTasks => blockerIssues.length;

  /// Average story points per estimated task.
  double get averageStoryPoints {
    final estimatedIssues = issues.where((i) => i.estimate != null && i.estimate! > 0);
    if (estimatedIssues.isEmpty) return 0.0;
    final sum = estimatedIssues.fold(0.0, (acc, i) => acc + i.estimate!);
    return sum / estimatedIssues.length;
  }

  /// Breakdown of issues by status.
  Map<IssueStatus, int> get statusCounts {
    final Map<IssueStatus, int> map = {
      IssueStatus.todo: 0,
      IssueStatus.inProgress: 0,
      IssueStatus.inReview: 0,
      IssueStatus.done: 0,
    };
    for (final issue in issues) {
      map[issue.status] = (map[issue.status] ?? 0) + 1;
    }
    return map;
  }

  /// Breakdown of issues by priority.
  Map<IssuePriority, int> get priorityCounts {
    final Map<IssuePriority, int> map = {
      IssuePriority.urgent: 0,
      IssuePriority.high: 0,
      IssuePriority.medium: 0,
      IssuePriority.low: 0,
      IssuePriority.lowest: 0,
    };
    for (final issue in issues) {
      map[issue.priority] = (map[issue.priority] ?? 0) + 1;
    }
    return map;
  }

  /// Workload grouped by assignee.
  List<AssigneeWorkloadModel> get assigneeWorkloads {
    final Map<String?, List<IssueModel>> grouped = {};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.assigneeId, () => []).add(issue);
    }

    final List<AssigneeWorkloadModel> list = [];

    for (final entry in grouped.entries) {
      final userId = entry.key;
      final memberIssues = entry.value;

      String name = 'Unassigned';
      String? email;
      String? avatar;
      RoleType? role;

      if (userId != null) {
        ProjectMemberModel? member;
        try {
          member = members.firstWhere((m) => m.userId == userId);
        } catch (_) {
          member = null;
        }

        if (member != null) {
          name = member.user?.fullName ?? member.user?.email ?? 'Member';
          email = member.user?.email;
          avatar = member.user?.avatarUrl;
          role = member.role;
        } else if (memberIssues.isNotEmpty && memberIssues.first.assignee != null) {
          final user = memberIssues.first.assignee!;
          name = user.fullName.isNotEmpty ? user.fullName : user.email;
          email = user.email;
          avatar = user.avatarUrl;
        } else {
          name = 'Member ($userId)';
        }
      }

      final total = memberIssues.length;
      final completed = memberIssues.where((i) => i.status == IssueStatus.done).length;
      final totalPts = memberIssues.fold(0.0, (acc, i) => acc + (i.estimate ?? 0.0));
      final donePts = memberIssues
          .where((i) => i.status == IssueStatus.done)
          .fold(0.0, (acc, i) => acc + (i.estimate ?? 0.0));

      list.add(AssigneeWorkloadModel(
        userId: userId,
        name: name,
        email: email,
        avatarUrl: avatar,
        role: role,
        totalIssues: total,
        completedIssues: completed,
        totalStoryPoints: totalPts,
        completedStoryPoints: donePts,
      ));
    }

    // Sort: members with most issues first, Unassigned last
    list.sort((a, b) {
      if (a.userId == null) return 1;
      if (b.userId == null) return -1;
      return b.totalIssues.compareTo(a.totalIssues);
    });

    return list;
  }

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    ProjectModel? project,
    List<SprintModel>? sprints,
    SprintModel? selectedSprint,
    bool clearSelectedSprint = false,
    SprintProgressModel? progress,
    bool clearProgress = false,
    List<IssueModel>? issues,
    List<ProjectMemberModel>? members,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      project: project ?? this.project,
      sprints: sprints ?? this.sprints,
      selectedSprint: clearSelectedSprint ? null : (selectedSprint ?? this.selectedSprint),
      progress: clearProgress ? null : (progress ?? this.progress),
      issues: issues ?? this.issues,
      members: members ?? this.members,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        errorMessage,
        project,
        sprints,
        selectedSprint,
        progress,
        issues,
        members,
      ];
}

/// Notifier handling dashboard state, sprint progress loading and burndown calculations.
class DashboardNotifier extends StateNotifier<DashboardState> {
  final SprintRepository _sprintRepository;
  final ProjectRepository _projectRepository;
  final String _projectId;

  DashboardNotifier({
    required SprintRepository sprintRepository,
    required ProjectRepository projectRepository,
    required String projectId,
  })  : _sprintRepository = sprintRepository,
        _projectRepository = projectRepository,
        _projectId = projectId,
        super(const DashboardState()) {
    loadDashboard();
  }

  /// Loads project information, all sprints, members, selects the active or primary sprint, and fetches its progress & issues.
  Future<void> loadDashboard({String? targetSprintId}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _projectRepository.getProject(_projectId),
        _sprintRepository.listProjectSprints(_projectId),
        _projectRepository
            .listProjectMembers(_projectId)
            .catchError((_) => <ProjectMemberModel>[]),
      ]);

      final project = results[0] as ProjectModel;
      final sprints = results[1] as List<SprintModel>;
      final members = results[2] as List<ProjectMemberModel>;

      SprintModel? selected;
      if (targetSprintId != null) {
        try {
          selected = sprints.firstWhere((s) => s.id == targetSprintId);
        } catch (_) {
          selected = null;
        }
      }

      // If no target specified or not found, prefer ACTIVE sprint, then PLANNED, then first available
      if (selected == null && sprints.isNotEmpty) {
        try {
          selected = sprints.firstWhere((s) => s.status == SprintStatus.active);
        } catch (_) {
          try {
            selected = sprints.firstWhere((s) => s.status == SprintStatus.planned);
          } catch (_) {
            selected = sprints.first;
          }
        }
      }

      SprintProgressModel? progress;
      List<IssueModel> issues = [];

      if (selected != null) {
        final sprintData = await Future.wait([
          _sprintRepository.getSprintProgress(selected.id).catchError((_) => SprintProgressModel(
                sprintId: selected!.id,
                sprintName: selected.name,
                status: selected.status,
                totalIssues: 0,
                completedIssues: 0,
                remainingIssues: 0,
                issueProgressPercentage: 0.0,
                totalStoryPoints: 0.0,
                completedStoryPoints: 0.0,
                remainingStoryPoints: 0.0,
                storyPointProgressPercentage: 0.0,
              )),
          _sprintRepository.getSprintIssues(selected.id).catchError((_) => <IssueModel>[]),
        ]);

        progress = sprintData[0] as SprintProgressModel;
        issues = sprintData[1] as List<IssueModel>;
      }

      state = state.copyWith(
        isLoading: false,
        project: project,
        sprints: sprints,
        selectedSprint: selected,
        clearSelectedSprint: selected == null,
        progress: progress,
        clearProgress: progress == null,
        issues: issues,
        members: members,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  /// Switches selected sprint and refreshes burndown and issue data.
  Future<void> selectSprint(String sprintId) async {
    await loadDashboard(targetSprintId: sprintId);
  }

  /// Refreshes dashboard data for the currently selected sprint.
  Future<void> refresh() async {
    await loadDashboard(targetSprintId: state.selectedSprint?.id);
  }

  void clearErrorMessage() {
    state = state.copyWith(clearError: true);
  }
}

/// Riverpod family provider for `DashboardNotifier`.
final dashboardProvider = StateNotifierProvider.autoDispose
    .family<DashboardNotifier, DashboardState, String>((ref, projectId) {
  final sprintRepo = ref.watch(sprintRepositoryProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);

  return DashboardNotifier(
    sprintRepository: sprintRepo,
    projectRepository: projectRepo,
    projectId: projectId,
  );
});
