import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';

/// Represents the UI state of the Kanban Board screen.
class KanbanBoardState extends Equatable {
  final bool isLoading;
  final bool isUpdating;
  final String? errorMessage;
  final SprintModel? activeSprint;
  final List<IssueModel> allIssues;
  final String projectKey;
  final String searchQuery;
  final Set<IssueType> selectedTypes;
  final Set<IssuePriority> selectedPriorities;
  final String? selectedAssigneeId;

  const KanbanBoardState({
    this.isLoading = false,
    this.isUpdating = false,
    this.errorMessage,
    this.activeSprint,
    this.allIssues = const [],
    this.projectKey = 'OVS',
    this.searchQuery = '',
    this.selectedTypes = const {},
    this.selectedPriorities = const {},
    this.selectedAssigneeId,
  });

  bool get hasActiveSprint => activeSprint != null;

  /// Returns issues filtered by current search query and chip filters.
  List<IssueModel> get filteredIssues {
    return allIssues.where((issue) {
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchesTitle = issue.title.toLowerCase().contains(query);
        final matchesKey = issue.formattedKey(projectKey).toLowerCase().contains(query);
        if (!matchesTitle && !matchesKey) return false;
      }

      if (selectedTypes.isNotEmpty && !selectedTypes.contains(issue.type)) {
        return false;
      }

      if (selectedPriorities.isNotEmpty && !selectedPriorities.contains(issue.priority)) {
        return false;
      }

      if (selectedAssigneeId != null && issue.assigneeId != selectedAssigneeId) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Returns filtered issues belonging to a specific workflow status.
  List<IssueModel> issuesForStatus(IssueStatus status) {
    return filteredIssues.where((issue) => issue.status == status).toList();
  }

  /// Number of issues in a specific status column.
  int countForStatus(IssueStatus status) {
    return issuesForStatus(status).length;
  }

  /// Sum of Story Points (estimates) for a specific status column.
  double storyPointsForStatus(IssueStatus status) {
    return issuesForStatus(status).fold<double>(
      0.0,
      (sum, issue) => sum + (issue.estimate ?? 0.0),
    );
  }

  /// Total count of all filtered issues currently on the board.
  int get totalIssues => filteredIssues.length;

  /// Total Story Points of all filtered issues on the board.
  double get totalStoryPoints {
    return filteredIssues.fold<double>(
      0.0,
      (sum, issue) => sum + (issue.estimate ?? 0.0),
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedTypes.isNotEmpty ||
      selectedPriorities.isNotEmpty ||
      selectedAssigneeId != null;

  KanbanBoardState copyWith({
    bool? isLoading,
    bool? isUpdating,
    String? errorMessage,
    bool clearErrorMessage = false,
    SprintModel? activeSprint,
    bool clearActiveSprint = false,
    List<IssueModel>? allIssues,
    String? projectKey,
    String? searchQuery,
    Set<IssueType>? selectedTypes,
    Set<IssuePriority>? selectedPriorities,
    String? selectedAssigneeId,
    bool clearAssigneeId = false,
  }) {
    return KanbanBoardState(
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      activeSprint: clearActiveSprint ? null : (activeSprint ?? this.activeSprint),
      allIssues: allIssues ?? this.allIssues,
      projectKey: projectKey ?? this.projectKey,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      selectedPriorities: selectedPriorities ?? this.selectedPriorities,
      selectedAssigneeId:
          clearAssigneeId ? null : (selectedAssigneeId ?? this.selectedAssigneeId),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isUpdating,
        errorMessage,
        activeSprint,
        allIssues,
        projectKey,
        searchQuery,
        selectedTypes,
        selectedPriorities,
        selectedAssigneeId,
      ];
}
