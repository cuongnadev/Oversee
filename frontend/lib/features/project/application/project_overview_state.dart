import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';

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
  });

  bool get isOwner => currentUserRole == RoleType.owner;
  bool get isAdmin => currentUserRole == RoleType.admin || isOwner;
  bool get canEdit => isAdmin;

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
      ];
}
