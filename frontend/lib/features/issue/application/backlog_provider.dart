import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/issue/application/backlog_state.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/backlog_grouped_model.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';

/// Provider for sprint-grouped Backlog state parameterized by projectId.
final AutoDisposeStateNotifierProviderFamily<BacklogNotifier, BacklogState, String>
    backlogNotifierProvider =
    StateNotifierProvider.autoDispose.family<BacklogNotifier, BacklogState, String>(
        (ref, projectId) {
  final issueRepository = ref.watch(issueRepositoryProvider);
  final projectRepository = ref.watch(projectRepositoryProvider);
  final sprintRepository = ref.watch(sprintRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);

  final notifier = BacklogNotifier(
    projectId: projectId,
    issueRepository: issueRepository,
    projectRepository: projectRepository,
    sprintRepository: sprintRepository,
    currentUserId: authState.user?.id,
  );

  notifier.loadBacklog();
  return notifier;
});

class BacklogNotifier extends StateNotifier<BacklogState> {
  final String projectId;
  final IssueRepository _issueRepository;
  final ProjectRepository _projectRepository;
  final SprintRepository? _sprintRepository;
  final String? _currentUserId;

  BacklogNotifier({
    required this.projectId,
    required IssueRepository issueRepository,
    required ProjectRepository projectRepository,
    SprintRepository? sprintRepository,
    String? currentUserId,
    BacklogState? initialState,
  })  : _issueRepository = issueRepository,
        _projectRepository = projectRepository,
        _sprintRepository = sprintRepository,
        _currentUserId = currentUserId,
        super(initialState ?? BacklogState(isLoading: true, currentUserId: currentUserId));

  Future<void> loadBacklog() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      // Prefer the new grouped endpoint (/backlog/grouped), falling back gracefully to /backlog
      // if an older server or isolated test fake only implements listBacklogIssues.
      BacklogOverviewModel? grouped;
      try {
        grouped = await _issueRepository.getGroupedBacklog(projectId);
      } catch (e) {
        if (e is AppException && (e.statusCode == 401 || e.statusCode == 403)) {
          rethrow;
        }
        grouped = null;
      }

      if (grouped != null) {
        final results = await Future.wait([
          _projectRepository.getProject(projectId),
          _projectRepository
              .listProjectMembers(projectId)
              .catchError((_) => <ProjectMemberModel>[]),
        ]);
        final project = results[0] as ProjectModel;
        final members = results[1] as List<ProjectMemberModel>;

        final List<IssueModel> backlogList = List<IssueModel>.from(grouped.backlogIssues);
        backlogList.sort((a, b) {
          final rankCmp = a.backlogRank.compareTo(b.backlogRank);
          if (rankCmp != 0) return rankCmp;
          return a.issueNumber.compareTo(b.issueNumber);
        });

        state = state.copyWith(
          project: project,
          issues: backlogList,
          sprintGroups: grouped.sprints,
          members: members,
          currentUserId: _currentUserId,
          isLoading: false,
          errorMessage: () => null,
        );
        return;
      }

      // Fallback path using listBacklogIssues
      final results = await Future.wait([
        _projectRepository.getProject(projectId),
        _issueRepository.listBacklogIssues(projectId),
        _projectRepository
            .listProjectMembers(projectId)
            .catchError((_) => <ProjectMemberModel>[]),
      ]);
      final project = results[0] as ProjectModel;
      final page = results[1] as IssuePageModel;
      final members = results[2] as List<ProjectMemberModel>;

      final List<IssueModel> issues = List<IssueModel>.from(page.items);
      issues.sort((a, b) {
        final rankCmp = a.backlogRank.compareTo(b.backlogRank);
        if (rankCmp != 0) return rankCmp;
        return a.issueNumber.compareTo(b.issueNumber);
      });

      state = state.copyWith(
        project: project,
        issues: issues,
        sprintGroups: const [],
        members: members,
        currentUserId: _currentUserId,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      final msg = e is AppException ? e.message : 'Failed to load product backlog: $e';
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => msg,
      );
    }
  }

  void toggleGroupCollapsed(String groupId) {
    final next = Set<String>.from(state.collapsedGroupIds);
    if (next.contains(groupId)) {
      next.remove(groupId);
    } else {
      next.add(groupId);
    }
    state = state.copyWith(collapsedGroupIds: next);
  }

  void setFilter(IssueFilterState filter) {
    state = state.copyWith(filter: filter);
  }

  void initFilterFromParams(Map<String, String> params) {
    if (params.isEmpty && !state.filter.hasActiveFilters) return;
    final newFilter = IssueFilterState.fromQueryParams(params);
    if (newFilter != state.filter) {
      state = state.copyWith(filter: newFilter);
    }
  }

  Future<bool> quickCreateIssue(
    String title, {
    IssueType type = IssueType.task,
    IssuePriority priority = IssuePriority.medium,
    double? estimate,
    String? sprintId,
  }) async {
    if (title.trim().isEmpty) return false;

    state = state.copyWith(isCreating: true, errorMessage: () => null);
    try {
      final created = await _issueRepository.createIssue(
        projectId,
        title: title.trim(),
        type: type,
        priority: priority,
        estimate: estimate,
        sprintId: sprintId,
        status: sprintId != null ? IssueStatus.todo : IssueStatus.backlog,
      );

      if (sprintId == null) {
        try {
          await _issueRepository.addIssueToBacklog(projectId, issueId: created.id);
        } catch (_) {
          // Backend createIssue already defaults to backlog if sprint_id is null
        }
      }

      updateIssueInState(created);
      state = state.copyWith(isCreating: false, errorMessage: () => null);
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : 'Failed to create issue: $e';
      state = state.copyWith(
        isCreating: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> moveIssueToSprint(IssueModel issue, String targetSprintId) async {
    if (issue.sprintId == targetSprintId) return true;
    final prevIssues = state.issues;
    final prevGroups = state.sprintGroups;

    final optimistic = issue.copyWith(sprintId: targetSprintId, isBacklog: false);
    updateIssueInState(optimistic);

    try {
      if (_sprintRepository != null) {
        await _sprintRepository.addIssueToSprint(targetSprintId, issue.id);
      } else {
        await _issueRepository.updateIssue(issue.id, sprintId: targetSprintId);
      }
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : 'Failed to move issue to sprint: $e';
      state = state.copyWith(
        issues: prevIssues,
        sprintGroups: prevGroups,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> moveIssueToBacklog(IssueModel issue) async {
    if (issue.sprintId == null) return true;
    final prevIssues = state.issues;
    final prevGroups = state.sprintGroups;

    final optimistic = issue.copyWith(clearSprint: true, isBacklog: true);
    updateIssueInState(optimistic);

    try {
      await _issueRepository.addIssueToBacklog(projectId, issueId: issue.id);
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : 'Failed to move issue to backlog: $e';
      state = state.copyWith(
        issues: prevIssues,
        sprintGroups: prevGroups,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> updateIssueStatusInline(IssueModel issue, IssueStatus nextStatus) async {
    if (issue.status == nextStatus) return true;
    final prevIssues = state.issues;
    final prevGroups = state.sprintGroups;

    updateIssueInState(issue.copyWith(status: nextStatus));
    try {
      final updated = await _issueRepository.updateIssueStatus(issue.id, status: nextStatus);
      updateIssueInState(updated);
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        issues: prevIssues,
        sprintGroups: prevGroups,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> reorderBacklog(int oldIndex, int newIndex) async {
    final currentList = List<IssueModel>.from(state.issues);
    if (oldIndex < 0 || oldIndex >= currentList.length) return false;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0 || newIndex >= currentList.length) return false;
    if (oldIndex == newIndex) return true;

    final movedItem = currentList.removeAt(oldIndex);
    currentList.insert(newIndex, movedItem);

    final previousList = List<IssueModel>.from(state.issues);
    state = state.copyWith(
      issues: currentList,
      isReordering: true,
      errorMessage: () => null,
    );

    try {
      final String? prevId = newIndex > 0 ? currentList[newIndex - 1].id : null;
      final String? nextId = newIndex < currentList.length - 1 ? currentList[newIndex + 1].id : null;

      final updatedIssue = await _issueRepository.reorderBacklog(
        projectId,
        issueId: movedItem.id,
        previousIssueId: prevId,
        nextIssueId: nextId,
      );

      final finalizedList = currentList.map((issue) {
        return issue.id == movedItem.id ? updatedIssue : issue;
      }).toList();

      state = state.copyWith(
        issues: finalizedList,
        isReordering: false,
        errorMessage: () => null,
      );
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : 'Failed to save new order: $e';
      state = state.copyWith(
        issues: previousList,
        isReordering: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      filter: state.filter.copyWith(searchQuery: query.trim()),
    );
  }

  void setTypeFilter(IssueType? type) {
    state = state.copyWith(
      filter: state.filter.copyWith(
        selectedTypes: type != null ? {type} : const {},
      ),
    );
  }

  void setPriorityFilter(IssuePriority? priority) {
    state = state.copyWith(
      filter: state.filter.copyWith(
        selectedPriorities: priority != null ? {priority} : const {},
      ),
    );
  }

  void clearFilters() {
    state = state.copyWith(
      filter: const IssueFilterState(),
    );
  }

  /// Updates an issue directly across sprint groups and unassigned backlog without page refetch.
  void updateIssueInState(IssueModel updatedIssue) {
    final targetSprintId = updatedIssue.sprintId;

    // Update unassigned backlog list
    final nextBacklog = state.issues.where((i) => i.id != updatedIssue.id).toList();
    if (targetSprintId == null) {
      final existingIdx = state.issues.indexWhere((i) => i.id == updatedIssue.id);
      if (existingIdx != -1) {
        nextBacklog.insert(existingIdx.clamp(0, nextBacklog.length), updatedIssue);
      } else {
        nextBacklog.add(updatedIssue);
      }
    }

    // Update sprint groups & recalculate done/total progress
    final nextGroups = state.sprintGroups.map((group) {
      final withoutIssue = group.issues.where((i) => i.id != updatedIssue.id).toList();
      if (group.sprint.id == targetSprintId) {
        final existingIdx = group.issues.indexWhere((i) => i.id == updatedIssue.id);
        if (existingIdx != -1) {
          withoutIssue.insert(existingIdx.clamp(0, withoutIssue.length), updatedIssue);
        } else {
          withoutIssue.add(updatedIssue);
        }
      }
      return group.withIssues(withoutIssue);
    }).toList();

    state = state.copyWith(
      issues: nextBacklog,
      sprintGroups: nextGroups,
    );
  }

  Future<void> refresh() async {
    await loadBacklog();
  }
}
