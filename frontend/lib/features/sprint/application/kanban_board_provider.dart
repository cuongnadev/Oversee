import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/sprint/application/kanban_board_state.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';

/// StateNotifier managing Kanban Board data fetching, optimistic status updates, and filtering.
class KanbanBoardNotifier extends StateNotifier<KanbanBoardState> {
  final SprintRepository _sprintRepository;
  final IssueRepository _issueRepository;
  final ProjectRepository _projectRepository;
  final String _projectId;
  final String? _currentUserId;

  KanbanBoardNotifier({
    required SprintRepository sprintRepository,
    required IssueRepository issueRepository,
    required ProjectRepository projectRepository,
    required String projectId,
    String? currentUserId,
  })  : _sprintRepository = sprintRepository,
        _issueRepository = issueRepository,
        _projectRepository = projectRepository,
        _projectId = projectId,
        _currentUserId = currentUserId,
        super(KanbanBoardState(isLoading: true, currentUserId: currentUserId)) {
    loadBoard();
  }

  /// Loads project key, project members, active sprint, and sprint issues.
  Future<void> loadBoard() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      // 1. Fetch project info to get the project key
      String projectKey = state.projectKey;
      try {
        final project = await _projectRepository.getProject(_projectId);
        projectKey = project.key;
      } catch (_) {
        // Fallback to existing or default key if project endpoint is unavailable
      }

      // 2. Fetch project members for assignee filtering
      List<ProjectMemberModel> members = [];
      try {
        members = await _projectRepository.listProjectMembers(_projectId);
      } catch (_) {
        // Fallback if members endpoint fails
      }

      // 3. Query for active sprint
      final activeSprint = await _sprintRepository.getActiveSprint(_projectId);

      if (activeSprint == null) {
        state = state.copyWith(
          isLoading: false,
          clearActiveSprint: true,
          allIssues: [],
          projectKey: projectKey,
          members: members,
          currentUserId: _currentUserId,
        );
        return;
      }

      // 4. Query all issues in the active sprint
      final sprintIssues = await _sprintRepository.getSprintIssues(activeSprint.id);

      state = state.copyWith(
        isLoading: false,
        activeSprint: activeSprint,
        allIssues: sprintIssues,
        projectKey: projectKey,
        members: members,
        currentUserId: _currentUserId,
      );
    } catch (e) {
      final message = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
    }
  }

  /// Refreshes the board data.
  Future<void> refresh() async {
    await loadBoard();
  }

  /// Updates the complete filter state.
  void setFilter(IssueFilterState filter) {
    state = state.copyWith(filter: filter);
  }

  /// Initializes or updates the filter state from URL query parameters.
  void initFilterFromParams(Map<String, String> params) {
    if (params.isEmpty && !state.filter.hasActiveFilters) return;
    final newFilter = IssueFilterState.fromQueryParams(params);
    if (newFilter != state.filter) {
      state = state.copyWith(filter: newFilter);
    }
  }

  /// Optimistically updates an issue's status, rolling back if the backend rejects it.
  Future<bool> updateIssueStatus(
    String issueId,
    IssueStatus newStatus, {
    bool? allowOpenSubissues,
  }) async {
    final index = state.allIssues.indexWhere((issue) => issue.id == issueId);
    if (index == -1) return false;

    final targetIssue = state.allIssues[index];
    if (targetIssue.status == newStatus) return true;

    // Check workflow validation constraint: Sub-issues must be completed before moving to DONE
    if (newStatus == IssueStatus.done && targetIssue.subIssueCount > 0) {
      if (targetIssue.completedSubIssueCount < targetIssue.subIssueCount) {
        final remaining = targetIssue.subIssueCount - targetIssue.completedSubIssueCount;
        state = state.copyWith(
          errorMessage:
              'Cannot move to Done: "${targetIssue.title}" has $remaining open sub-issue${remaining > 1 ? 's' : ''}. Complete all sub-issues first.',
        );
        return false;
      }
    }

    final previousIssues = List.of(state.allIssues);
    final updatedList = List.of(state.allIssues);
    updatedList[index] = targetIssue.copyWith(status: newStatus);

    // Optimistic UI update
    state = state.copyWith(
      allIssues: updatedList,
      isUpdating: true,
      clearErrorMessage: true,
    );

    try {
      final updatedIssue = await _issueRepository.updateIssueStatus(
        issueId,
        status: newStatus,
        allowOpenSubissues: allowOpenSubissues,
      );

      final committedList = List.of(state.allIssues);
      final committedIndex = committedList.indexWhere((i) => i.id == issueId);
      if (committedIndex != -1) {
        committedList[committedIndex] = updatedIssue;
      }

      state = state.copyWith(
        allIssues: committedList,
        isUpdating: false,
      );
      return true;
    } catch (e) {
      final errorMsg = e is AppException ? e.message : e.toString();
      // Rollback to previous state on failure
      state = state.copyWith(
        allIssues: previousIssues,
        isUpdating: false,
        errorMessage: errorMsg,
      );
      return false;
    }
  }

  /// Sets the search query for filtering issue titles or keys.
  void setSearchQuery(String query) {
    state = state.copyWith(
      filter: state.filter.copyWith(searchQuery: query.trim()),
    );
  }

  /// Toggles an issue type filter chip.
  void toggleTypeFilter(IssueType type) {
    final current = Set.of(state.filter.selectedTypes);
    if (current.contains(type)) {
      current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(
      filter: state.filter.copyWith(selectedTypes: current),
    );
  }

  /// Toggles an issue priority filter chip.
  void togglePriorityFilter(IssuePriority priority) {
    final current = Set.of(state.filter.selectedPriorities);
    if (current.contains(priority)) {
      current.remove(priority);
    } else {
      current.add(priority);
    }
    state = state.copyWith(
      filter: state.filter.copyWith(selectedPriorities: current),
    );
  }

  /// Sets or clears the assignee filter.
  void setAssigneeFilter(String? assigneeId) {
    state = state.copyWith(
      filter: state.filter.copyWith(
        selectedAssigneeId: assigneeId,
        clearAssigneeId: assigneeId == null,
      ),
    );
  }

  /// Clears any active error message.
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// Updates an issue directly in local board state for instantaneous cross-component reflection
  /// without triggering a full-page refetch/reload.
  void updateIssueInState(IssueModel updatedIssue) {
    final activeSprintId = state.activeSprint?.id;
    final exists = state.allIssues.any((i) => i.id == updatedIssue.id);
    if (activeSprintId != null && updatedIssue.sprintId != activeSprintId) {
      if (exists) {
        state = state.copyWith(
          allIssues: state.allIssues.where((i) => i.id != updatedIssue.id).toList(),
        );
      }
      return;
    }
    if (exists) {
      final updatedList = state.allIssues.map((issue) {
        return issue.id == updatedIssue.id ? updatedIssue : issue;
      }).toList();
      state = state.copyWith(allIssues: updatedList);
    } else if (activeSprintId != null && updatedIssue.sprintId == activeSprintId) {
      state = state.copyWith(allIssues: [...state.allIssues, updatedIssue]);
    }
  }

  /// Clears all active filters.
  void clearFilters() {
    state = state.copyWith(
      filter: const IssueFilterState(),
    );
  }
}

/// Family provider keyed by `projectId` delivering `KanbanBoardState`.
final kanbanBoardProvider =
    StateNotifierProvider.autoDispose.family<KanbanBoardNotifier, KanbanBoardState, String>(
  (ref, projectId) {
    final sprintRepo = ref.watch(sprintRepositoryProvider);
    final issueRepo = ref.watch(issueRepositoryProvider);
    final projectRepo = ref.watch(projectRepositoryProvider);
    final authState = ref.watch(authNotifierProvider);
    return KanbanBoardNotifier(
      sprintRepository: sprintRepo,
      issueRepository: issueRepo,
      projectRepository: projectRepo,
      projectId: projectId,
      currentUserId: authState.user?.id,
    );
  },
);
