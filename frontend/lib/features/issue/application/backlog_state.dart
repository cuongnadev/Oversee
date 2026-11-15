import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';

class BacklogState extends Equatable {
  final List<IssueModel> issues;
  final ProjectModel? project;
  final bool isLoading;
  final bool isCreating;
  final bool isReordering;
  final String? errorMessage;
  final String searchQuery;
  final IssueType? selectedType;
  final IssuePriority? selectedPriority;

  const BacklogState({
    this.issues = const [],
    this.project,
    this.isLoading = false,
    this.isCreating = false,
    this.isReordering = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedType,
    this.selectedPriority,
  });

  List<IssueModel> get filteredIssues {
    final key = project?.key ?? '';
    return issues.where((issue) {
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchTitle = issue.title.toLowerCase().contains(query);
        final matchKey = issue.formattedKey(key).toLowerCase().contains(query);
        if (!matchTitle && !matchKey) return false;
      }

      if (selectedType != null && issue.type != selectedType) {
        return false;
      }

      if (selectedPriority != null && issue.priority != selectedPriority) {
        return false;
      }

      return true;
    }).toList();
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
    String? searchQuery,
    IssueType? Function()? selectedType,
    IssuePriority? Function()? selectedPriority,
  }) {
    return BacklogState(
      issues: issues ?? this.issues,
      project: project ?? this.project,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isReordering: isReordering ?? this.isReordering,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: selectedType != null ? selectedType() : this.selectedType,
      selectedPriority: selectedPriority != null ? selectedPriority() : this.selectedPriority,
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
        searchQuery,
        selectedType,
        selectedPriority,
      ];
}
