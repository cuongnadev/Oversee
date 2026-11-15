import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';

/// Represents the UI state of the Kanban Board screen.
class KanbanBoardState extends Equatable {
  final bool isLoading;
  final bool isUpdating;
  final String? errorMessage;
  final SprintModel? activeSprint;
  final List<IssueModel> allIssues;
  final String projectKey;
  final IssueFilterState filter;
  final List<ProjectMemberModel> members;
  final String? currentUserId;
  final String? _legacySearchQuery;
  final Set<IssueType>? _legacyTypes;
  final Set<IssuePriority>? _legacyPriorities;
  final String? _legacyAssigneeId;

  const KanbanBoardState({
    this.isLoading = false,
    this.isUpdating = false,
    this.errorMessage,
    this.activeSprint,
    this.allIssues = const [],
    this.projectKey = 'OVS',
    this.filter = const IssueFilterState(),
    this.members = const [],
    this.currentUserId,
    String? searchQuery,
    Set<IssueType>? selectedTypes,
    Set<IssuePriority>? selectedPriorities,
    String? selectedAssigneeId,
  })  : _legacySearchQuery = searchQuery,
        _legacyTypes = selectedTypes,
        _legacyPriorities = selectedPriorities,
        _legacyAssigneeId = selectedAssigneeId;

  IssueFilterState get effectiveFilter {
    IssueFilterState f = filter;
    final legacySearch = _legacySearchQuery;
    if (legacySearch != null && legacySearch.isNotEmpty) {
      f = f.copyWith(searchQuery: legacySearch);
    }
    final legacyTypes = _legacyTypes;
    if (legacyTypes != null && legacyTypes.isNotEmpty) {
      f = f.copyWith(selectedTypes: legacyTypes);
    }
    final legacyPriorities = _legacyPriorities;
    if (legacyPriorities != null && legacyPriorities.isNotEmpty) {
      f = f.copyWith(selectedPriorities: legacyPriorities);
    }
    final legacyAssignee = _legacyAssigneeId;
    if (legacyAssignee != null) {
      f = f.copyWith(selectedAssigneeId: legacyAssignee);
    }
    return f;
  }

  bool get hasActiveSprint => activeSprint != null;

  // Convenience getters delegating to effectiveFilter
  String get searchQuery => effectiveFilter.searchQuery;
  Set<IssueType> get selectedTypes => effectiveFilter.selectedTypes;
  Set<IssuePriority> get selectedPriorities => effectiveFilter.selectedPriorities;
  String? get selectedAssigneeId => effectiveFilter.selectedAssigneeId;
  bool get hasActiveFilters => effectiveFilter.hasActiveFilters;

  /// Returns issues filtered and sorted according to the current filter state.
  List<IssueModel> get filteredIssues =>
      effectiveFilter.apply(allIssues, projectKey: projectKey, currentUserId: currentUserId);

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

  KanbanBoardState copyWith({
    bool? isLoading,
    bool? isUpdating,
    String? errorMessage,
    bool clearErrorMessage = false,
    SprintModel? activeSprint,
    bool clearActiveSprint = false,
    List<IssueModel>? allIssues,
    String? projectKey,
    IssueFilterState? filter,
    List<ProjectMemberModel>? members,
    String? currentUserId,
    String? searchQuery,
    Set<IssueType>? selectedTypes,
    Set<IssuePriority>? selectedPriorities,
    String? selectedAssigneeId,
    bool clearAssigneeId = false,
  }) {
    IssueFilterState updatedFilter = filter ?? effectiveFilter;
    if (searchQuery != null) {
      updatedFilter = updatedFilter.copyWith(searchQuery: searchQuery);
    }
    if (selectedTypes != null) {
      updatedFilter = updatedFilter.copyWith(selectedTypes: selectedTypes);
    }
    if (selectedPriorities != null) {
      updatedFilter = updatedFilter.copyWith(selectedPriorities: selectedPriorities);
    }
    if (clearAssigneeId) {
      updatedFilter = updatedFilter.copyWith(clearAssigneeId: true);
    } else if (selectedAssigneeId != null) {
      updatedFilter = updatedFilter.copyWith(selectedAssigneeId: selectedAssigneeId);
    }

    return KanbanBoardState(
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      activeSprint: clearActiveSprint ? null : (activeSprint ?? this.activeSprint),
      allIssues: allIssues ?? this.allIssues,
      projectKey: projectKey ?? this.projectKey,
      filter: updatedFilter,
      members: members ?? this.members,
      currentUserId: currentUserId ?? this.currentUserId,
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
        effectiveFilter,
        members,
        currentUserId,
      ];
}
