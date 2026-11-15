import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/sprint/application/kanban_board_state.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';

/// StateNotifier managing Kanban Board data fetching, optimistic status updates, and filtering.
class KanbanBoardNotifier extends StateNotifier<KanbanBoardState> {
  final SprintRepository _sprintRepository;
  final IssueRepository _issueRepository;
  final ProjectRepository _projectRepository;
  final String _projectId;

  KanbanBoardNotifier({
    required SprintRepository sprintRepository,
    required IssueRepository issueRepository,
    required ProjectRepository projectRepository,
    required String projectId,
  })  : _sprintRepository = sprintRepository,
        _issueRepository = issueRepository,
        _projectRepository = projectRepository,
        _projectId = projectId,
        super(const KanbanBoardState(isLoading: true)) {
    loadBoard();
  }

  /// Loads project key, active sprint, and all issues belonging to the active sprint.
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

      // 2. Query for active sprint
      final activeSprint = await _sprintRepository.getActiveSprint(_projectId);

      if (activeSprint == null) {
        state = state.copyWith(
          isLoading: false,
          clearActiveSprint: true,
          allIssues: [],
          projectKey: projectKey,
        );
        return;
      }

      // 3. Query all issues in the active sprint
      final sprintIssues = await _sprintRepository.getSprintIssues(activeSprint.id);

      state = state.copyWith(
        isLoading: false,
        activeSprint: activeSprint,
        allIssues: sprintIssues,
        projectKey: projectKey,
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
        state = state.copyWith(
          errorMessage:
              'Cannot move to Done: ${targetIssue.subIssueCount - targetIssue.completedSubIssueCount} sub-issues are still open.',
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
    state = state.copyWith(searchQuery: query.trim());
  }

  /// Toggles an issue type filter chip.
  void toggleTypeFilter(IssueType type) {
    final current = Set.of(state.selectedTypes);
    if (current.contains(type)) {
      current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(selectedTypes: current);
  }

  /// Toggles an issue priority filter chip.
  void togglePriorityFilter(IssuePriority priority) {
    final current = Set.of(state.selectedPriorities);
    if (current.contains(priority)) {
      current.remove(priority);
    } else {
      current.add(priority);
    }
    state = state.copyWith(selectedPriorities: current);
  }

  /// Sets or clears the assignee filter.
  void setAssigneeFilter(String? assigneeId) {
    state = state.copyWith(
      selectedAssigneeId: assigneeId,
      clearAssigneeId: assigneeId == null,
    );
  }

  /// Clears all active filters.
  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedTypes: {},
      selectedPriorities: {},
      clearAssigneeId: true,
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
    return KanbanBoardNotifier(
      sprintRepository: sprintRepo,
      issueRepository: issueRepo,
      projectRepository: projectRepo,
      projectId: projectId,
    );
  },
);
