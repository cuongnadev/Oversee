import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_activity_model.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';

/// State for the Issue Detail panel and inline editing forms.
class IssueDetailState extends Equatable {
  final IssueModel issue;
  final List<IssueModel> subIssues;
  final List<IssueActivityModel> activities;
  final List<ProjectMemberModel> members;
  final bool isLoading;
  final bool isSaving;
  final bool isCreatingSubTask;
  final String? errorMessage;

  const IssueDetailState({
    required this.issue,
    this.subIssues = const [],
    this.activities = const [],
    this.members = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.isCreatingSubTask = false,
    this.errorMessage,
  });

  int get totalSubIssues => subIssues.length;
  int get completedSubIssues =>
      subIssues.where((s) => s.status == IssueStatus.done || s.status == IssueStatus.canceled).length;
  double get subIssuesProgress =>
      totalSubIssues > 0 ? (completedSubIssues / totalSubIssues) : 0.0;

  IssueDetailState copyWith({
    IssueModel? issue,
    List<IssueModel>? subIssues,
    List<IssueActivityModel>? activities,
    List<ProjectMemberModel>? members,
    bool? isLoading,
    bool? isSaving,
    bool? isCreatingSubTask,
    String? Function()? errorMessage,
  }) {
    return IssueDetailState(
      issue: issue ?? this.issue,
      subIssues: subIssues ?? this.subIssues,
      activities: activities ?? this.activities,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isCreatingSubTask: isCreatingSubTask ?? this.isCreatingSubTask,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        issue,
        subIssues,
        activities,
        members,
        isLoading,
        isSaving,
        isCreatingSubTask,
        errorMessage,
      ];
}

class IssueDetailNotifier extends StateNotifier<IssueDetailState> {
  final String projectId;
  final IssueRepository _issueRepository;
  final ProjectRepository _projectRepository;

  IssueDetailNotifier({
    required this.projectId,
    required IssueModel initialIssue,
    required IssueRepository issueRepository,
    required ProjectRepository projectRepository,
  })  : _issueRepository = issueRepository,
        _projectRepository = projectRepository,
        super(IssueDetailState(issue: initialIssue, isLoading: true));

  Future<void> loadDetails() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final issueFuture = _issueRepository.getIssue(state.issue.id);
      final subIssuesFuture = _issueRepository
          .listSubIssues(state.issue.id)
          .catchError((_) => <IssueModel>[]);
      final activitiesFuture = _issueRepository
          .listIssueActivities(state.issue.id)
          .catchError((_) => <IssueActivityModel>[]);
      final membersFuture = _projectRepository
          .listProjectMembers(projectId)
          .catchError((_) => <ProjectMemberModel>[]);

      final results = await Future.wait([
        issueFuture,
        subIssuesFuture,
        activitiesFuture,
        membersFuture,
      ]);

      final freshIssue = results[0] as IssueModel;
      final subIssues = results[1] as List<IssueModel>;
      final activities = results[2] as List<IssueActivityModel>;
      final members = results[3] as List<ProjectMemberModel>;

      state = state.copyWith(
        issue: freshIssue,
        subIssues: subIssues,
        activities: activities,
        members: members,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => msg,
      );
    }
  }

  Future<bool> updateTitle(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == state.issue.title) return true;

    final prev = state.issue;
    state = state.copyWith(
      issue: state.issue.copyWith(title: trimmed),
      isSaving: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssue(state.issue.id, title: trimmed);
      state = state.copyWith(
        issue: updated,
        isSaving: false,
      );
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issue: prev,
        isSaving: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> updateDescription(String description) async {
    final trimmed = description.trim();
    if (trimmed == (state.issue.description ?? '')) return true;

    final prev = state.issue;
    state = state.copyWith(
      issue: state.issue.copyWith(description: trimmed),
      isSaving: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssue(state.issue.id, description: trimmed);
      state = state.copyWith(
        issue: updated,
        isSaving: false,
      );
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issue: prev,
        isSaving: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> updateStatus(IssueStatus newStatus, {bool? allowOpenSubissues}) async {
    if (newStatus == state.issue.status) return true;

    // Check open sub-issues if moving to DONE
    if (newStatus == IssueStatus.done && (allowOpenSubissues != true)) {
      final hasOpenSub = state.subIssues.any(
        (s) => s.status != IssueStatus.done && s.status != IssueStatus.canceled,
      );
      if (hasOpenSub) {
        state = state.copyWith(
          errorMessage: () =>
              'Cannot move to Done: Issue has open sub-tasks. Resolve all sub-tasks first.',
        );
        return false;
      }
    }

    final prev = state.issue;
    state = state.copyWith(
      issue: state.issue.copyWith(status: newStatus),
      isSaving: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssueStatus(
        state.issue.id,
        status: newStatus,
        allowOpenSubissues: allowOpenSubissues,
      );
      state = state.copyWith(
        issue: updated,
        isSaving: false,
      );
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issue: prev,
        isSaving: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> updatePriority(IssuePriority priority) async {
    if (priority == state.issue.priority) return true;

    final prev = state.issue;
    state = state.copyWith(
      issue: state.issue.copyWith(priority: priority),
      isSaving: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssuePriority(state.issue.id, priority);
      state = state.copyWith(
        issue: updated,
        isSaving: false,
      );
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issue: prev,
        isSaving: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> updateAssignee(String? assigneeId) async {
    if (assigneeId == state.issue.assigneeId) return true;

    final prev = state.issue;
    state = state.copyWith(
      issue: state.issue.copyWith(assigneeId: assigneeId),
      isSaving: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssueAssignee(state.issue.id, assigneeId);
      state = state.copyWith(
        issue: updated,
        isSaving: false,
      );
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issue: prev,
        isSaving: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> updateEstimate(double? estimate) async {
    if (estimate == state.issue.estimate) return true;

    final prev = state.issue;
    state = state.copyWith(
      issue: state.issue.copyWith(estimate: estimate),
      isSaving: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssue(state.issue.id, estimate: estimate);
      state = state.copyWith(
        issue: updated,
        isSaving: false,
      );
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issue: prev,
        isSaving: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> updateType(IssueType type) async {
    if (type == state.issue.type) return true;

    final prev = state.issue;
    state = state.copyWith(
      issue: state.issue.copyWith(type: type),
      isSaving: true,
      errorMessage: () => null,
    );

    try {
      final updated = await _issueRepository.updateIssue(state.issue.id, type: type);
      state = state.copyWith(
        issue: updated,
        isSaving: false,
      );
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issue: prev,
        isSaving: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> createSubTask(String title, {double? estimate}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;

    state = state.copyWith(isCreatingSubTask: true, errorMessage: () => null);

    try {
      final created = await _issueRepository.createSubIssue(
        projectId,
        state.issue.id,
        title: trimmed,
        estimate: estimate,
      );

      final updatedSubIssues = List<IssueModel>.from(state.subIssues)..add(created);
      final updatedParent = state.issue.copyWith(
        subIssueCount: state.issue.subIssueCount + 1,
      );

      state = state.copyWith(
        issue: updatedParent,
        subIssues: updatedSubIssues,
        isCreatingSubTask: false,
      );
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        isCreatingSubTask: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> toggleSubTaskStatus(String subIssueId, bool isDone) async {
    final index = state.subIssues.indexWhere((s) => s.id == subIssueId);
    if (index == -1) return false;

    final target = state.subIssues[index];
    final newStatus = isDone ? IssueStatus.done : IssueStatus.todo;
    if (target.status == newStatus) return true;

    final prevSubIssues = List<IssueModel>.from(state.subIssues);
    final optimisticList = List<IssueModel>.from(state.subIssues);
    optimisticList[index] = target.copyWith(status: newStatus);

    final completedCount = optimisticList
        .where((s) => s.status == IssueStatus.done || s.status == IssueStatus.canceled)
        .length;

    state = state.copyWith(
      subIssues: optimisticList,
      issue: state.issue.copyWith(completedSubIssueCount: completedCount),
      errorMessage: () => null,
    );

    try {
      final updatedSub = await _issueRepository.updateIssueStatus(
        subIssueId,
        status: newStatus,
      );
      final finalizedList = List<IssueModel>.from(state.subIssues);
      final targetIdx = finalizedList.indexWhere((s) => s.id == subIssueId);
      if (targetIdx != -1) {
        finalizedList[targetIdx] = updatedSub;
      }
      state = state.copyWith(subIssues: finalizedList);
      await _refreshActivitiesQuietly();
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        subIssues: prevSubIssues,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<void> _refreshActivitiesQuietly() async {
    try {
      final activities = await _issueRepository.listIssueActivities(state.issue.id);
      state = state.copyWith(activities: activities);
    } catch (_) {}
  }
}

/// Family provider keyed by issue ID and project ID.
final issueDetailProvider = StateNotifierProvider.autoDispose
    .family<IssueDetailNotifier, IssueDetailState, ({String projectId, IssueModel initialIssue})>(
  (ref, args) {
    final issueRepo = ref.watch(issueRepositoryProvider);
    final projectRepo = ref.watch(projectRepositoryProvider);
    final notifier = IssueDetailNotifier(
      projectId: args.projectId,
      initialIssue: args.initialIssue,
      issueRepository: issueRepo,
      projectRepository: projectRepo,
    );
    notifier.loadDetails();
    return notifier;
  },
);
