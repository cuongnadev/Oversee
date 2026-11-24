import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/backlog_grouped_model.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';

class BacklogState extends Equatable {
  /// Unassigned product backlog issues (`sprint_id == null`).
  final List<IssueModel> issues;

  /// Sprint groups sorted by Active -> Planned -> Completed with per-sprint progress metrics.
  final List<BacklogSprintGroupModel> sprintGroups;

  /// Collapsed section IDs (sprint IDs or `'__backlog__'`).
  final Set<String> collapsedGroupIds;

  final ProjectModel? project;
  final bool isLoading;
  final bool isCreating;
  final bool isReordering;
  final String? errorMessage;
  final IssueFilterState filter;
  final List<ProjectMemberModel> members;
  final String? currentUserId;
  final String? _legacySearchQuery;
  final IssueType? _legacyType;
  final IssuePriority? _legacyPriority;

  const BacklogState({
    this.issues = const [],
    this.sprintGroups = const [],
    this.collapsedGroupIds = const {},
    this.project,
    this.isLoading = false,
    this.isCreating = false,
    this.isReordering = false,
    this.errorMessage,
    this.filter = const IssueFilterState(),
    this.members = const [],
    this.currentUserId,
    String? searchQuery,
    IssueType? selectedType,
    IssuePriority? selectedPriority,
  })  : _legacySearchQuery = searchQuery,
        _legacyType = selectedType,
        _legacyPriority = selectedPriority;

  IssueFilterState get effectiveFilter {
    IssueFilterState f = filter;
    final legacySearch = _legacySearchQuery;
    if (legacySearch != null && legacySearch.isNotEmpty) {
      f = f.copyWith(searchQuery: legacySearch);
    }
    final legacyType = _legacyType;
    if (legacyType != null) {
      f = f.copyWith(selectedTypes: {legacyType});
    }
    final legacyPriority = _legacyPriority;
    if (legacyPriority != null) {
      f = f.copyWith(selectedPriorities: {legacyPriority});
    }
    return f;
  }

  // Backward-compatible getters
  String get searchQuery => effectiveFilter.searchQuery;
  IssueType? get selectedType =>
      effectiveFilter.selectedTypes.isNotEmpty ? effectiveFilter.selectedTypes.first : null;
  IssuePriority? get selectedPriority =>
      effectiveFilter.selectedPriorities.isNotEmpty ? effectiveFilter.selectedPriorities.first : null;
  bool get hasActiveFilters => effectiveFilter.hasActiveFilters;

  /// Filtered unassigned backlog issues.
  List<IssueModel> get filteredIssues {
    return effectiveFilter.apply(
      issues,
      projectKey: project?.key ?? 'PROJ',
      currentUserId: currentUserId,
    );
  }

  /// Sprint groups with their issues filtered according to [effectiveFilter].
  List<BacklogSprintGroupModel> get filteredSprintGroups {
    final key = project?.key ?? 'PROJ';
    return sprintGroups.map((group) {
      final matching = effectiveFilter.apply(
        group.issues,
        projectKey: key,
        currentUserId: currentUserId,
      );
      return group.withIssues(matching);
    }).toList();
  }

  /// Total count of all issues (sprints + backlog) after active filters.
  int get totalAllIssuesCount {
    final sprintTotal = filteredSprintGroups.fold<int>(0, (sum, g) => sum + g.issues.length);
    return sprintTotal + filteredIssues.length;
  }

  /// Total story points across backlog issues (kept for backward compatibility).
  double get totalStoryPoints {
    return filteredIssues.fold<double>(
      0.0,
      (sum, issue) => sum + (issue.estimate ?? 0.0),
    );
  }

  /// Total story points across all sprints + backlog.
  double get totalAllStoryPoints {
    final sprintPts = filteredSprintGroups.fold<double>(0.0, (sum, g) => sum + g.totalStoryPoints);
    return sprintPts + totalStoryPoints;
  }

  BacklogState copyWith({
    List<IssueModel>? issues,
    List<BacklogSprintGroupModel>? sprintGroups,
    Set<String>? collapsedGroupIds,
    ProjectModel? project,
    bool? isLoading,
    bool? isCreating,
    bool? isReordering,
    String? Function()? errorMessage,
    IssueFilterState? filter,
    List<ProjectMemberModel>? members,
    String? currentUserId,
    String? searchQuery,
    IssueType? Function()? selectedType,
    IssuePriority? Function()? selectedPriority,
  }) {
    IssueFilterState updatedFilter = filter ?? effectiveFilter;
    if (searchQuery != null) {
      updatedFilter = updatedFilter.copyWith(searchQuery: searchQuery);
    }
    if (selectedType != null) {
      final t = selectedType();
      updatedFilter = updatedFilter.copyWith(
        selectedTypes: t != null ? {t} : const {},
      );
    }
    if (selectedPriority != null) {
      final p = selectedPriority();
      updatedFilter = updatedFilter.copyWith(
        selectedPriorities: p != null ? {p} : const {},
      );
    }

    return BacklogState(
      issues: issues ?? this.issues,
      sprintGroups: sprintGroups ?? this.sprintGroups,
      collapsedGroupIds: collapsedGroupIds ?? this.collapsedGroupIds,
      project: project ?? this.project,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isReordering: isReordering ?? this.isReordering,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      filter: updatedFilter,
      members: members ?? this.members,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  @override
  List<Object?> get props => [
        issues,
        sprintGroups,
        collapsedGroupIds,
        project,
        isLoading,
        isCreating,
        isReordering,
        errorMessage,
        effectiveFilter,
        members,
        currentUserId,
      ];
}
