import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';

class BacklogState extends Equatable {
  final List<IssueModel> issues;
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

  List<IssueModel> get filteredIssues {
    return effectiveFilter.apply(
      issues,
      projectKey: project?.key ?? 'PROJ',
      currentUserId: currentUserId,
    );
  }

  double get totalStoryPoints {
    return filteredIssues.fold<double>(
      0.0,
      (sum, issue) => sum + (issue.estimate ?? 0.0),
    );
  }

  BacklogState copyWith({
    List<IssueModel>? issues,
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
