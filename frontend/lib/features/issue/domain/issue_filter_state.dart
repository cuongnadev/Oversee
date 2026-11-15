import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';

/// Supported sort fields across Backlog and Kanban Board.
enum IssueSortField {
  rank('rank', 'Rank / Position'),
  priority('priority', 'Priority'),
  estimate('estimate', 'Story Points'),
  issueNumber('key', 'Issue Key'),
  updated('updated', 'Recently Updated');

  final String value;
  final String label;
  const IssueSortField(this.value, this.label);

  static IssueSortField fromString(String? val) {
    if (val == null) return IssueSortField.rank;
    return IssueSortField.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => IssueSortField.rank,
    );
  }
}

/// Unified filter and sort state for both Backlog and Kanban Board views.
class IssueFilterState extends Equatable {
  final String searchQuery;
  final Set<IssueType> selectedTypes;
  final Set<IssuePriority> selectedPriorities;
  final String? selectedAssigneeId; // 'me', 'unassigned', or specific user UUID
  final IssueSortField sortField;
  final bool sortAscending;

  const IssueFilterState({
    this.searchQuery = '',
    this.selectedTypes = const {},
    this.selectedPriorities = const {},
    this.selectedAssigneeId,
    this.sortField = IssueSortField.rank,
    this.sortAscending = true,
  });

  /// Counts the total number of active filter criteria.
  int get activeFilterCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count++;
    if (selectedTypes.isNotEmpty) count += selectedTypes.length;
    if (selectedPriorities.isNotEmpty) count += selectedPriorities.length;
    if (selectedAssigneeId != null) count++;
    if (sortField != IssueSortField.rank) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  /// Serializes active filters into URL query parameters for GoRouter.
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (searchQuery.trim().isNotEmpty) {
      params['search'] = searchQuery.trim();
    }
    if (selectedTypes.isNotEmpty) {
      params['type'] = selectedTypes.map((t) => t.value).join(',');
    }
    if (selectedPriorities.isNotEmpty) {
      params['priority'] = selectedPriorities.map((p) => p.value).join(',');
    }
    if (selectedAssigneeId != null && selectedAssigneeId!.isNotEmpty) {
      params['assignee'] = selectedAssigneeId!;
    }
    if (sortField != IssueSortField.rank) {
      params['sort'] = sortField.value;
      params['order'] = sortAscending ? 'asc' : 'desc';
    }
    return params;
  }

  /// Deserializes URL query parameters from GoRouter into an `IssueFilterState`.
  factory IssueFilterState.fromQueryParams(Map<String, String> params) {
    final search = params['search'] ?? '';

    final typeParam = params['type'];
    final types = <IssueType>{};
    if (typeParam != null && typeParam.isNotEmpty) {
      for (final t in typeParam.split(',')) {
        types.add(IssueType.fromString(t.trim()));
      }
    }

    final priorityParam = params['priority'];
    final priorities = <IssuePriority>{};
    if (priorityParam != null && priorityParam.isNotEmpty) {
      for (final p in priorityParam.split(',')) {
        priorities.add(IssuePriority.fromString(p.trim()));
      }
    }

    final assignee = params['assignee'];

    final sort = IssueSortField.fromString(params['sort']);
    final order = params['order'] ?? 'asc';
    final sortAscending = order.toLowerCase() != 'desc';

    return IssueFilterState(
      searchQuery: search,
      selectedTypes: types,
      selectedPriorities: priorities,
      selectedAssigneeId: assignee,
      sortField: sort,
      sortAscending: sortAscending,
    );
  }

  /// Filters and sorts a list of issues according to the current filter state.
  List<IssueModel> apply(
    List<IssueModel> issues, {
    String projectKey = 'OVS',
    String? currentUserId,
  }) {
    // 1. Filtering
    final filtered = issues.where((issue) {
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
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

      if (selectedAssigneeId != null && selectedAssigneeId!.isNotEmpty) {
        if (selectedAssigneeId == 'me') {
          if (issue.assigneeId != currentUserId) return false;
        } else if (selectedAssigneeId == 'unassigned') {
          if (issue.assigneeId != null && issue.assigneeId!.isNotEmpty) return false;
        } else {
          if (issue.assigneeId != selectedAssigneeId) return false;
        }
      }

      return true;
    }).toList();

    // 2. Sorting
    filtered.sort((a, b) {
      int cmp = 0;
      switch (sortField) {
        case IssueSortField.rank:
          cmp = a.backlogRank.compareTo(b.backlogRank);
          if (cmp == 0) cmp = a.issueNumber.compareTo(b.issueNumber);
          break;
        case IssueSortField.priority:
          // Higher index (urgent = 4) comes first
          cmp = b.priority.index.compareTo(a.priority.index);
          break;
        case IssueSortField.estimate:
          final estA = a.estimate ?? 0.0;
          final estB = b.estimate ?? 0.0;
          cmp = estB.compareTo(estA);
          break;
        case IssueSortField.issueNumber:
          cmp = a.issueNumber.compareTo(b.issueNumber);
          break;
        case IssueSortField.updated:
          final dateA = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = dateB.compareTo(dateA);
          break;
      }
      return sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  IssueFilterState copyWith({
    String? searchQuery,
    Set<IssueType>? selectedTypes,
    Set<IssuePriority>? selectedPriorities,
    String? selectedAssigneeId,
    bool clearAssigneeId = false,
    IssueSortField? sortField,
    bool? sortAscending,
  }) {
    return IssueFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      selectedPriorities: selectedPriorities ?? this.selectedPriorities,
      selectedAssigneeId:
          clearAssigneeId ? null : (selectedAssigneeId ?? this.selectedAssigneeId),
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  @override
  List<Object?> get props => [
        searchQuery,
        selectedTypes,
        selectedPriorities,
        selectedAssigneeId,
        sortField,
        sortAscending,
      ];
}
