import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/issue/application/backlog_state.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';

/// Provider for Product Backlog state parameterized by projectId.
final AutoDisposeStateNotifierProviderFamily<BacklogNotifier, BacklogState, String>
    backlogNotifierProvider =
    StateNotifierProvider.autoDispose.family<BacklogNotifier, BacklogState, String>(
        (ref, projectId) {
  final issueRepository = ref.watch(issueRepositoryProvider);
  final projectRepository = ref.watch(projectRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);

  final notifier = BacklogNotifier(
    projectId: projectId,
    issueRepository: issueRepository,
    projectRepository: projectRepository,
    currentUserId: authState.user?.id,
  );

  notifier.loadBacklog();
  return notifier;
});

class BacklogNotifier extends StateNotifier<BacklogState> {
  final String projectId;
  final IssueRepository _issueRepository;
  final ProjectRepository _projectRepository;
  final String? _currentUserId;

  BacklogNotifier({
    required this.projectId,
    required IssueRepository issueRepository,
    required ProjectRepository projectRepository,
    String? currentUserId,
    BacklogState? initialState,
  })  : _issueRepository = issueRepository,
        _projectRepository = projectRepository,
        _currentUserId = currentUserId,
        super(initialState ?? BacklogState(isLoading: true, currentUserId: currentUserId));

  Future<void> loadBacklog() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final projectFuture = _projectRepository.getProject(projectId);
      final backlogFuture = _issueRepository.listBacklogIssues(projectId);
      final membersFuture = _projectRepository.listProjectMembers(projectId).catchError((_) => <ProjectMemberModel>[]);

      final results = await Future.wait([projectFuture, backlogFuture, membersFuture]);
      final project = results[0] as ProjectModel;
      final page = results[1] as IssuePageModel;
      final members = results[2] as List<ProjectMemberModel>;

      final List<IssueModel> issues = List<IssueModel>.from(page.items);
      // Sort issues by backlogRank ascending, then issueNumber ascending
      issues.sort((a, b) {
        final rankCmp = a.backlogRank.compareTo(b.backlogRank);
        if (rankCmp != 0) return rankCmp;
        return a.issueNumber.compareTo(b.issueNumber);
      });

      state = state.copyWith(
        project: project,
        issues: issues,
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
      );

      // Add to backlog
      try {
        await _issueRepository.addIssueToBacklog(projectId, issueId: created.id);
      } catch (_) {
        // Backend createIssue already defaults to backlog if sprint_id is null
      }

      final updatedList = List<IssueModel>.from(state.issues)..add(created);
      state = state.copyWith(
        issues: updatedList,
        isCreating: false,
        errorMessage: () => null,
      );
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
    // Optimistic state update
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

      // Update the moved issue with calculated rank
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
      // Rollback to previous list on failure
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

  Future<void> refresh() async {
    await loadBacklog();
  }
}
