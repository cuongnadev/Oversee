import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';

/// Shared state for project-wide issue views (Timeline, Calendar, Issues List).
class ProjectIssuesState extends Equatable {
  final ProjectModel? project;
  final List<IssueModel> issues;
  final List<ProjectMemberModel> members;
  final List<SprintModel> sprints;
  final IssueFilterState filter;
  final String? currentUserId;
  final bool isLoading;
  final bool isUpdating;
  final String? errorMessage;

  const ProjectIssuesState({
    this.project,
    this.issues = const [],
    this.members = const [],
    this.sprints = const [],
    this.filter = const IssueFilterState(),
    this.currentUserId,
    this.isLoading = false,
    this.isUpdating = false,
    this.errorMessage,
  });

  String get projectKey => project?.key ?? 'OVS';

  List<IssueModel> get filteredIssues => filter.apply(
        issues,
        projectKey: projectKey,
        currentUserId: currentUserId,
      );

  ProjectIssuesState copyWith({
    ProjectModel? project,
    List<IssueModel>? issues,
    List<ProjectMemberModel>? members,
    List<SprintModel>? sprints,
    IssueFilterState? filter,
    String? currentUserId,
    bool? isLoading,
    bool? isUpdating,
    String? Function()? errorMessage,
  }) {
    return ProjectIssuesState(
      project: project ?? this.project,
      issues: issues ?? this.issues,
      members: members ?? this.members,
      sprints: sprints ?? this.sprints,
      filter: filter ?? this.filter,
      currentUserId: currentUserId ?? this.currentUserId,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        project,
        issues,
        members,
        sprints,
        filter,
        currentUserId,
        isLoading,
        isUpdating,
        errorMessage,
      ];
}

class ProjectIssuesNotifier extends StateNotifier<ProjectIssuesState> {
  final String projectId;
  final IssueRepository _issueRepository;
  final ProjectRepository _projectRepository;
  final SprintRepository _sprintRepository;
  final String? _currentUserId;

  ProjectIssuesNotifier({
    required this.projectId,
    required IssueRepository issueRepository,
    required ProjectRepository projectRepository,
    required SprintRepository sprintRepository,
    String? currentUserId,
  })  : _issueRepository = issueRepository,
        _projectRepository = projectRepository,
        _sprintRepository = sprintRepository,
        _currentUserId = currentUserId,
        super(ProjectIssuesState(isLoading: true, currentUserId: currentUserId));

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final results = await Future.wait([
        _projectRepository.getProject(projectId).then<ProjectModel?>((p) => p).catchError((_) => null),
        _issueRepository.listProjectIssues(projectId, page: 1, pageSize: 100),
        _projectRepository.listProjectMembers(projectId).catchError((_) => <ProjectMemberModel>[]),
        _sprintRepository.listProjectSprints(projectId).catchError((_) => <SprintModel>[]),
      ]);

      final project = results[0] as ProjectModel?;
      final page = results[1] as IssuePageModel;
      final members = results[2] as List<ProjectMemberModel>;
      final sprints = results[3] as List<SprintModel>;

      state = state.copyWith(
        project: project,
        issues: page.items,
        members: members,
        sprints: sprints,
        currentUserId: _currentUserId,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      final msg = e is AppException ? e.message : 'Failed to load project issues: $e';
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => msg,
      );
    }
  }

  Future<void> refresh() => load();

  void setFilter(IssueFilterState filter) {
    state = state.copyWith(filter: filter);
  }

  void clearError() {
    state = state.copyWith(errorMessage: () => null);
  }

  /// Updates an issue directly in local state without refetching the page.
  void updateIssueInState(IssueModel updatedIssue) {
    final idx = state.issues.indexWhere((i) => i.id == updatedIssue.id);
    if (idx != -1) {
      final next = List<IssueModel>.from(state.issues);
      next[idx] = updatedIssue;
      state = state.copyWith(issues: next);
    } else if (updatedIssue.projectId == projectId) {
      state = state.copyWith(issues: [...state.issues, updatedIssue]);
    }
  }

  /// Optimistically updates issue start/end dates (for Timeline drag/resize & Calendar drag).
  Future<bool> updateIssueDates(
    String issueId, {
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    final idx = state.issues.indexWhere((i) => i.id == issueId);
    if (idx == -1) return false;
    final prevList = List<IssueModel>.from(state.issues);
    final current = prevList[idx];

    final nextStart = clearStartDate ? null : (startDate ?? current.startDate);
    final nextEnd = clearEndDate ? null : (endDate ?? current.endDate);
    if (nextStart != null && nextEnd != null && nextEnd.isBefore(nextStart)) {
      state = state.copyWith(errorMessage: () => 'End date cannot be earlier than start date.');
      return false;
    }

    final optimisticList = List<IssueModel>.from(prevList);
    optimisticList[idx] = current.copyWith(
      startDate: startDate,
      clearStartDate: clearStartDate,
      endDate: endDate,
      clearEndDate: clearEndDate,
    );
    state = state.copyWith(
      issues: optimisticList,
      isUpdating: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssue(
        issueId,
        startDate: startDate,
        clearStartDate: clearStartDate,
        endDate: endDate,
        clearEndDate: clearEndDate,
      );
      updateIssueInState(updated);
      state = state.copyWith(isUpdating: false);
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issues: prevList,
        isUpdating: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  /// Optimistically updates an issue's workflow status.
  Future<bool> updateIssueStatus(String issueId, IssueStatus newStatus) async {
    final idx = state.issues.indexWhere((i) => i.id == issueId);
    if (idx == -1) return false;
    final prevList = List<IssueModel>.from(state.issues);
    final current = prevList[idx];
    if (current.status == newStatus) return true;

    final optimisticList = List<IssueModel>.from(prevList);
    optimisticList[idx] = current.copyWith(status: newStatus);
    state = state.copyWith(
      issues: optimisticList,
      isUpdating: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssueStatus(issueId, status: newStatus);
      updateIssueInState(updated);
      state = state.copyWith(isUpdating: false);
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issues: prevList,
        isUpdating: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  /// Optimistically updates an issue's priority.
  Future<bool> updateIssuePriority(String issueId, IssuePriority priority) async {
    final idx = state.issues.indexWhere((i) => i.id == issueId);
    if (idx == -1) return false;
    final prevList = List<IssueModel>.from(state.issues);
    final current = prevList[idx];
    if (current.priority == priority) return true;

    final optimisticList = List<IssueModel>.from(prevList);
    optimisticList[idx] = current.copyWith(priority: priority);
    state = state.copyWith(issues: optimisticList, isUpdating: true, errorMessage: () => null);

    try {
      final updated = await _issueRepository.updateIssuePriority(issueId, priority);
      updateIssueInState(updated);
      state = state.copyWith(isUpdating: false);
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issues: prevList,
        isUpdating: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }
}

final projectIssuesProvider = StateNotifierProvider.autoDispose
    .family<ProjectIssuesNotifier, ProjectIssuesState, String>((ref, projectId) {
  final issueRepo = ref.watch(issueRepositoryProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  final sprintRepo = ref.watch(sprintRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);

  final notifier = ProjectIssuesNotifier(
    projectId: projectId,
    issueRepository: issueRepo,
    projectRepository: projectRepo,
    sprintRepository: sprintRepo,
    currentUserId: authState.user?.id,
  );
  notifier.load();
  return notifier;
});
