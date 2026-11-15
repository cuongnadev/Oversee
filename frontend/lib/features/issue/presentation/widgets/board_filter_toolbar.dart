import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';

/// Reusable filter and sorting toolbar for Backlog and Kanban Board.
class BoardFilterToolbar extends StatefulWidget {
  final IssueFilterState filter;
  final ValueChanged<IssueFilterState> onFilterChanged;
  final List<ProjectMemberModel> members;
  final String? currentUserId;

  const BoardFilterToolbar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    this.members = const [],
    this.currentUserId,
  });

  @override
  State<BoardFilterToolbar> createState() => _BoardFilterToolbarState();
}

class _BoardFilterToolbarState extends State<BoardFilterToolbar> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filter.searchQuery);
    _isExpanded = widget.filter.hasActiveFilters;
  }

  @override
  void didUpdateWidget(covariant BoardFilterToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.searchQuery != widget.filter.searchQuery &&
        _searchController.text != widget.filter.searchQuery) {
      _searchController.text = widget.filter.searchQuery;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onFilterChanged(widget.filter.copyWith(searchQuery: text.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filter = widget.filter;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Bar: Search, My Issues, Filter Toggle, Sort Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Left: Search Input & Quick "My Issues"
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search with Debounce
                    SizedBox(
                      width: 200,
                      height: 34,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search title or key...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 16),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _searchController.clear();
                                    _debounceTimer?.cancel();
                                    widget.onFilterChanged(
                                      widget.filter.copyWith(searchQuery: ''),
                                    );
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: isDark ? AppColors.cardDark : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick "My Issues" Filter Chip
                    FilterChip(
                      label: const Text('My Issues', style: TextStyle(fontSize: 11)),
                      avatar: const Icon(Icons.person, size: 14),
                      selected: filter.selectedAssigneeId == 'me',
                      onSelected: (selected) {
                        widget.onFilterChanged(
                          filter.copyWith(
                            selectedAssigneeId: selected ? 'me' : null,
                            clearAssigneeId: !selected,
                          ),
                        );
                      },
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),

                // Right: Sort by Dropdown, Sort Order, Filter Expansion Toggle, Clear All
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sort Field Dropdown
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<IssueSortField>(
                          value: filter.sortField,
                          isDense: true,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                          icon: const Icon(Icons.sort, size: 16),
                          items: IssueSortField.values.map((f) {
                            return DropdownMenuItem(
                              value: f,
                              child: Text(f.label),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              widget.onFilterChanged(filter.copyWith(sortField: val));
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Sort Order Toggle (Asc / Desc)
                    IconButton(
                      icon: Icon(
                        filter.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                      ),
                      tooltip: filter.sortAscending ? 'Ascending' : 'Descending',
                      onPressed: () {
                        widget.onFilterChanged(
                          filter.copyWith(sortAscending: !filter.sortAscending),
                        );
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),

                    // Filter Expansion Toggle Button with Count Badge
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                      icon: Icon(
                        _isExpanded ? Icons.tune : Icons.tune_outlined,
                        size: 16,
                        color: filter.hasActiveFilters
                            ? AppColors.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Filters', style: TextStyle(fontSize: 12)),
                          if (filter.activeFilterCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filter.activeFilterCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: filter.hasActiveFilters
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                      ),
                    ),

                    // Clear All Filters Button
                    if (filter.hasActiveFilters) ...[
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          _debounceTimer?.cancel();
                          widget.onFilterChanged(const IssueFilterState());
                        },
                        icon: const Icon(Icons.clear_all, size: 14),
                        label: const Text('Clear', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Collapsible Filter Chips Row: Multi-select Type, Multi-select Priority, Assignee
          if (_isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppColors.bgDark : Colors.grey.shade50,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Type Group
                    const Text(
                      'Type:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    ...[IssueType.story, IssueType.task, IssueType.bug, IssueType.epic].map((type) {
                      final isSelected = filter.selectedTypes.contains(type);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(type.label, style: const TextStyle(fontSize: 11)),
                          avatar: Icon(type.icon, size: 12, color: type.color),
                          selected: isSelected,
                          onSelected: (_) {
                            final updated = Set.of(filter.selectedTypes);
                            if (isSelected) {
                              updated.remove(type);
                            } else {
                              updated.add(type);
                            }
                            widget.onFilterChanged(filter.copyWith(selectedTypes: updated));
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      );
                    }),

                    const SizedBox(width: 10),
                    Container(width: 1, height: 20, color: isDark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(width: 10),

                    // Priority Group
                    const Text(
                      'Priority:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    ...[
                      IssuePriority.urgent,
                      IssuePriority.high,
                      IssuePriority.medium,
                      IssuePriority.low,
                      IssuePriority.lowest,
                    ].map((p) {
                      final isSelected = filter.selectedPriorities.contains(p);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(p.label, style: const TextStyle(fontSize: 11)),
                          avatar: Icon(p.icon, size: 12, color: p.color),
                          selected: isSelected,
                          onSelected: (_) {
                            final updated = Set.of(filter.selectedPriorities);
                            if (isSelected) {
                              updated.remove(p);
                            } else {
                              updated.add(p);
                            }
                            widget.onFilterChanged(filter.copyWith(selectedPriorities: updated));
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      );
                    }),

                    // Optional Project Members Dropdown
                    if (widget.members.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(width: 1, height: 20, color: isDark ? Colors.white24 : Colors.grey.shade300),
                      const SizedBox(width: 10),
                      const Text(
                        'Assignee:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String?>(
                        tooltip: 'Select assignee',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: filter.selectedAssigneeId != null && filter.selectedAssigneeId != 'me'
                                ? AppColors.primary.withAlpha(25)
                                : (isDark ? Colors.white12 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: filter.selectedAssigneeId != null && filter.selectedAssigneeId != 'me'
                                    ? AppColors.primary
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getAssigneeLabel(filter.selectedAssigneeId),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: filter.selectedAssigneeId != null && filter.selectedAssigneeId != 'me'
                                      ? AppColors.primary
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 16),
                            ],
                          ),
                        ),
                        itemBuilder: (context) {
                          return [
                            const PopupMenuItem<String?>(
                              value: null,
                              child: Text('All Assignees', style: TextStyle(fontSize: 12)),
                            ),
                            const PopupMenuItem<String?>(
                              value: 'unassigned',
                              child: Text('Unassigned', style: TextStyle(fontSize: 12)),
                            ),
                            ...widget.members.map((m) {
                              final name = m.user?.fullName ?? m.user?.email ?? m.userId;
                              return PopupMenuItem<String?>(
                                value: m.userId,
                                child: Text(name, style: const TextStyle(fontSize: 12)),
                              );
                            }),
                          ];
                        },
                        onSelected: (val) {
                          widget.onFilterChanged(
                            filter.copyWith(
                              selectedAssigneeId: val,
                              clearAssigneeId: val == null,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getAssigneeLabel(String? assigneeId) {
    if (assigneeId == null) return 'All';
    if (assigneeId == 'me') return 'My Issues';
    if (assigneeId == 'unassigned') return 'Unassigned';
    final member = widget.members.firstWhere(
      (m) => m.userId == assigneeId,
      orElse: () => ProjectMemberModel(
        id: '',
        projectId: '',
        userId: assigneeId,
        role: RoleType.viewer,
      ),
    );
    return member.user?.fullName ?? member.user?.email ?? 'Member';
  }
}
