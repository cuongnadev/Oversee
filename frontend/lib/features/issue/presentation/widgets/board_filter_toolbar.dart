import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Saved view presets displayed in Figma WorkToolbar Row 1 (node 6:382).
enum BoardSavedView {
  all('All'),
  mine('Mine'),
  open('Open');

  final String label;
  const BoardSavedView(this.label);
}

/// Reusable filter and sorting toolbar aligned with Figma WorkToolbar (node 6:381 & 12:3668).
class BoardFilterToolbar extends StatefulWidget {
  final IssueFilterState filter;
  final ValueChanged<IssueFilterState> onFilterChanged;
  final List<ProjectMemberModel> members;
  final String? currentUserId;
  final int? totalCount;
  final BoardSavedView? activeSavedView;
  final ValueChanged<BoardSavedView>? onSavedViewChanged;
  final String? workspaceId;
  final String? projectId;
  final String? activeView; // 'backlog' | 'board' | 'timeline' | 'calendar' | 'issues'

  const BoardFilterToolbar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    this.members = const [],
    this.currentUserId,
    this.totalCount,
    this.activeSavedView,
    this.onSavedViewChanged,
    this.workspaceId,
    this.projectId,
    this.activeView,
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
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onFilterChanged(widget.filter.copyWith(searchQuery: text.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final filter = widget.filter;

    final bgColor = AppColors.bgFor(isDark);
    final surfaceColor = AppColors.surfaceFor(isDark);
    final surface2Color = AppColors.surface2For(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoftColor = AppColors.borderSoftFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSolid = AppColors.accentSolidFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final errorColor = AppColors.errorFor(isDark);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Optional Saved Views Strip (Figma WorkToolbar Row 1: node 6:382)
          if (widget.onSavedViewChanged != null) ...[
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderSoftColor)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: BoardSavedView.values.map((view) {
                    final isSelected = (widget.activeSavedView ?? BoardSavedView.all) == view;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => widget.onSavedViewChanged!(view),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        child: Container(
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? accentSoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (view == BoardSavedView.all) ...[
                                Icon(
                                  Icons.view_kanban_outlined,
                                  size: 13.5,
                                  color: isSelected ? accentColor : textMuted,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                view.label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? textPrimary : textSecondary,
                                ),
                              ),
                              if (view == BoardSavedView.all && widget.totalCount != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.totalCount}',
                                  style: AppTypography.mono(
                                    isDark,
                                    fontSize: 10,
                                    color: textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // Main Toolbar Row (Figma .filters-row)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Left: Search Input, My Issues chip, Quick Assignee Avatar filters
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search with Debounce
                    SizedBox(
                      width: 210,
                      height: 32,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search title or key...',
                          hintStyle: TextStyle(fontSize: 12, color: textMuted),
                          prefixIcon: Icon(Icons.search_rounded, size: 15, color: textMuted),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, size: 14, color: textMuted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
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
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          filled: true,
                          fillColor: surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            borderSide: BorderSide(color: accentColor, width: 1.4),
                          ),
                        ),
                      ),
                    ),

                    Container(width: 1, height: 16, color: borderColor),

                    // Quick "My Issues" Filter Chip
                    FilterChip(
                      label: Text(
                        'My Issues',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: filter.selectedAssigneeId == 'me' ? accentColor : textSecondary,
                        ),
                      ),
                      avatar: Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: filter.selectedAssigneeId == 'me' ? accentColor : textMuted,
                      ),
                      selected: filter.selectedAssigneeId == 'me',
                      showCheckmark: false,
                      selectedColor: accentSoft,
                      backgroundColor: surface2Color,
                      side: BorderSide(
                        color: filter.selectedAssigneeId == 'me'
                            ? accentColor.withValues(alpha: 0.4)
                            : borderColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                      onSelected: (selected) {
                        widget.onFilterChanged(
                          filter.copyWith(
                            selectedAssigneeId: selected ? 'me' : null,
                            clearAssigneeId: !selected,
                          ),
                        );
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    ),

                    // Quick Assignee Avatar Filter Pills (Figma .assignee-filters)
                    if (widget.members.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.members.take(4).map((member) {
                          final isSelected = filter.selectedAssigneeId == member.userId;
                          final memberName = member.user?.fullName.isNotEmpty == true
                              ? member.user!.fullName
                              : (member.user?.email ?? member.userId);
                          return Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Tooltip(
                              message: 'Filter: $memberName',
                              child: InkWell(
                                onTap: () {
                                  widget.onFilterChanged(
                                    filter.copyWith(
                                      selectedAssigneeId: isSelected ? null : member.userId,
                                      clearAssigneeId: isSelected,
                                    ),
                                  );
                                },
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(1.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? accentColor : Colors.transparent,
                                      width: 1.8,
                                    ),
                                  ),
                                  child: UserAvatar(
                                    name: memberName,
                                    size: UserAvatarSize.xs,
                                    showTooltip: false,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),

                // Right: Sort Dropdown, Order Toggle, Filter Expansion, Clear
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Sort Field Dropdown
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        color: surface2Color,
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<IssueSortField>(
                          value: filter.sortField,
                          isDense: true,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                          dropdownColor: surfaceColor,
                          icon: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.sort, size: 15, color: textMuted),
                          ),
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

                    // Sort Order Toggle (Asc / Desc)
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: surface2Color,
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(color: borderColor),
                      ),
                      child: IconButton(
                        icon: Icon(
                          filter.sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 15,
                          color: textSecondary,
                        ),
                        tooltip: filter.sortAscending ? 'Ascending' : 'Descending',
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          widget.onFilterChanged(
                            filter.copyWith(sortAscending: !filter.sortAscending),
                          );
                        },
                      ),
                    ),

                    // Filter Expansion Toggle Button with Count Badge
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _isExpanded = !_isExpanded),
                        icon: Icon(
                          _isExpanded ? Icons.tune_rounded : Icons.tune_outlined,
                          size: 14.5,
                          color: filter.hasActiveFilters ? accentColor : textSecondary,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: filter.hasActiveFilters ? accentColor : textPrimary,
                              ),
                            ),
                            if (filter.activeFilterCount > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: accentSolid,
                                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                ),
                                child: Text(
                                  '${filter.activeFilterCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: filter.hasActiveFilters ? accentSoft : surface2Color,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          ),
                          side: BorderSide(
                            color: filter.hasActiveFilters
                                ? accentColor.withValues(alpha: 0.45)
                                : borderColor,
                          ),
                        ),
                      ),
                    ),

                    // Clear All Filters Button
                    if (filter.hasActiveFilters)
                      SizedBox(
                        height: 32,
                        child: TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            _debounceTimer?.cancel();
                            widget.onFilterChanged(const IssueFilterState());
                            setState(() {});
                          },
                          icon: Icon(Icons.clear_all_rounded, size: 15, color: errorColor),
                          label: Text(
                            'Clear',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: errorColor),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                            backgroundColor: AppColors.dangerSoftFor(isDark).withValues(alpha: 0.65),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            ),
                          ),
                        ),
                      ),

                    // Figma 5-View Switcher (Backlog, Board, Timeline, Calendar, Issues Table)
                    if (widget.workspaceId != null && widget.projectId != null) ...[
                      Container(width: 1, height: 18, color: borderColor),
                      _WorkViewSwitcher(
                        workspaceId: widget.workspaceId!,
                        projectId: widget.projectId!,
                        activeView: widget.activeView ?? '',
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Collapsible Filter Chips Row: Multi-select Type, Multi-select Priority, Assignee
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(top: BorderSide(color: borderSoftColor)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'Type:',
                      style: AppTypography.eyebrow(isDark).copyWith(fontSize: 10.5, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    ...[IssueType.story, IssueType.task, IssueType.bug, IssueType.epic].map((type) {
                      final isSelected = filter.selectedTypes.contains(type);
                      final typeColor = type.colorFor(brightness);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? accentColor : textSecondary,
                            ),
                          ),
                          avatar: Icon(type.icon, size: 13, color: typeColor),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: accentSoft,
                          backgroundColor: surface2Color,
                          side: BorderSide(
                            color: isSelected ? accentColor.withValues(alpha: 0.4) : borderColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          ),
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
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                        ),
                      );
                    }),

                    const SizedBox(width: 10),
                    Container(width: 1, height: 18, color: borderColor),
                    const SizedBox(width: 12),

                    Text(
                      'Priority:',
                      style: AppTypography.eyebrow(isDark).copyWith(fontSize: 10.5, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    ...[
                      IssuePriority.urgent,
                      IssuePriority.high,
                      IssuePriority.medium,
                      IssuePriority.low,
                      IssuePriority.lowest,
                    ].map((p) {
                      final isSelected = filter.selectedPriorities.contains(p);
                      final priorityColor = p.colorFor(brightness);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? accentColor : textSecondary,
                            ),
                          ),
                          avatar: Icon(p.icon, size: 13, color: priorityColor),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: accentSoft,
                          backgroundColor: surface2Color,
                          side: BorderSide(
                            color: isSelected ? accentColor.withValues(alpha: 0.4) : borderColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          ),
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
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                        ),
                      );
                    }),

                    if (widget.members.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(width: 1, height: 18, color: borderColor),
                      const SizedBox(width: 12),
                      Text(
                        'Assignee:',
                        style: AppTypography.eyebrow(isDark).copyWith(fontSize: 10.5, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String?>(
                        tooltip: 'Select assignee',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: filter.selectedAssigneeId != null && filter.selectedAssigneeId != 'me'
                                ? accentSoft
                                : surface2Color,
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            border: Border.all(
                              color: filter.selectedAssigneeId != null && filter.selectedAssigneeId != 'me'
                                  ? accentColor.withValues(alpha: 0.4)
                                  : borderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: filter.selectedAssigneeId != null && filter.selectedAssigneeId != 'me'
                                    ? accentColor
                                    : textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _getAssigneeLabel(filter.selectedAssigneeId),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: filter.selectedAssigneeId != null && filter.selectedAssigneeId != 'me'
                                      ? accentColor
                                      : textPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: textMuted),
                            ],
                          ),
                        ),
                        itemBuilder: (context) {
                          return [
                            const PopupMenuItem<String?>(
                              value: null,
                              child: Text('All Assignees', style: TextStyle(fontSize: 12.5)),
                            ),
                            const PopupMenuItem<String?>(
                              value: 'unassigned',
                              child: Text('Unassigned', style: TextStyle(fontSize: 12.5)),
                            ),
                            ...widget.members.map((m) {
                              final name = m.user?.fullName ?? m.user?.email ?? m.userId;
                              return PopupMenuItem<String?>(
                                value: m.userId,
                                child: Text(name, style: const TextStyle(fontSize: 12.5)),
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

class _WorkViewSwitcher extends StatelessWidget {
  final String workspaceId;
  final String projectId;
  final String activeView;
  final bool isDark;

  const _WorkViewSwitcher({
    required this.workspaceId,
    required this.projectId,
    required this.activeView,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface2 = AppColors.surface2For(isDark);
    final surface = AppColors.surfaceFor(isDark);
    final border = AppColors.borderFor(isDark);
    final accent = AppColors.accentFor(isDark);
    final muted = AppColors.textMutedFor(isDark);

    final items = <(String, String, IconData, String)>[
      ('backlog', 'Backlog', Icons.layers_outlined, AppRoutes.projectBacklogPath(workspaceId, projectId)),
      ('board', 'Board', Icons.view_kanban_outlined, AppRoutes.projectBoardPath(workspaceId, projectId)),
      ('timeline', 'Timeline', Icons.timeline_outlined, AppRoutes.projectTimelinePath(workspaceId, projectId)),
      ('calendar', 'Calendar', Icons.calendar_today_outlined, AppRoutes.projectCalendarPath(workspaceId, projectId)),
      ('issues', 'Issues List', Icons.table_rows_outlined, AppRoutes.projectIssuesPath(workspaceId, projectId)),
    ];

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((entry) {
          final (key, label, icon, path) = entry;
          final selected = activeView == key;
          return Tooltip(
            message: label,
            child: InkWell(
              onTap: () {
                if (!selected) {
                  context.go(path);
                }
              },
              borderRadius: BorderRadius.circular(AppColors.radiusSm + 1),
              child: Container(
                width: 28,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm + 1),
                  border: selected ? Border.all(color: border) : null,
                ),
                child: Icon(
                  icon,
                  size: 14.5,
                  color: selected ? accent : muted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
