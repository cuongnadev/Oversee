import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/application/project_issues_provider.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Full Issues Table Screen matching Figma Issues List Page (node 12:10428).
class IssuesListScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const IssuesListScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<IssuesListScreen> createState() => _IssuesListScreenState();
}

class _IssuesListScreenState extends ConsumerState<IssuesListScreen> {
  BoardSavedView _activeSavedView = BoardSavedView.all;

  void _handleSavedViewChanged(
    BoardSavedView view,
    ProjectIssuesState state,
    ProjectIssuesNotifier notifier,
  ) {
    setState(() => _activeSavedView = view);
    if (view == BoardSavedView.mine) {
      notifier.setFilter(state.filter.copyWith(selectedAssigneeId: 'me'));
    } else if (state.filter.selectedAssigneeId == 'me') {
      notifier.setFilter(state.filter.copyWith(clearAssigneeId: true));
    }
  }

  void _toggleSort(
    ProjectIssuesState state,
    ProjectIssuesNotifier notifier,
    IssueSortField field,
  ) {
    if (state.filter.sortField == field) {
      notifier.setFilter(state.filter.copyWith(sortAscending: !state.filter.sortAscending));
    } else {
      notifier.setFilter(state.filter.copyWith(sortField: field, sortAscending: true));
    }
  }

  Future<void> _openCreateIssue(ProjectIssuesNotifier notifier) async {
    final created = await QuickCreateDialog.show(
      context,
      projectId: widget.projectId,
      initialType: QuickCreateEntityType.issue,
    );
    if (created == true && mounted) {
      await notifier.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final state = ref.watch(projectIssuesProvider(widget.projectId));
    final notifier = ref.read(projectIssuesProvider(widget.projectId).notifier);

    ref.listen(projectIssuesProvider(widget.projectId), (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        AppFeedback.showError(context, next.errorMessage!);
        notifier.clearError();
      }
    });

    final issues = _activeSavedView == BoardSavedView.open
        ? state.filteredIssues
            .where((i) => i.status != IssueStatus.done && i.status != IssueStatus.canceled)
            .toList()
        : state.filteredIssues;

    final surface = AppColors.surfaceFor(isDark);
    final border = AppColors.borderFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'issues',
      title: 'Issues',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'issues',
          ),

          BoardFilterToolbar(
            filter: state.filter,
            members: state.members,
            currentUserId: state.currentUserId,
            totalCount: issues.length,
            activeSavedView: _activeSavedView,
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeView: 'issues',
            onSavedViewChanged: (view) => _handleSavedViewChanged(view, state, notifier),
            onFilterChanged: (newFilter) {
              if (newFilter.selectedAssigneeId != 'me' &&
                  _activeSavedView == BoardSavedView.mine) {
                setState(() => _activeSavedView = BoardSavedView.all);
              }
              notifier.setFilter(newFilter);
            },
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Page Heading (Figma 12:10941)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Issues',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.7,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${issues.length} Issues · All project work in one table.',
                                style: TextStyle(fontSize: 12.5, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        AppIconButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Refresh issues',
                          size: 32,
                          backgroundColor: AppColors.surface2For(isDark),
                          onPressed: () => notifier.refresh(),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            onPressed: () => _openCreateIssue(notifier),
                            icon: const Icon(Icons.add_rounded, size: 15),
                            label: const Text(
                              'Create Issue',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentSolidFor(isDark),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // IssueTable Card (Figma 12:10950)
                    Expanded(
                      child: state.isLoading
                          ? const BacklogSkeleton()
                          : issues.isEmpty
                              ? Center(
                                  child: AppEmptyState(
                                    icon: Icons.table_rows_outlined,
                                    title: state.filter.hasActiveFilters
                                        ? 'No matching issues'
                                        : 'No issues yet',
                                    description: state.filter.hasActiveFilters
                                        ? 'Try clearing or adjusting your active filters.'
                                        : 'Create your first issue to start tracking work in this project.',
                                    action: state.filter.hasActiveFilters
                                        ? AppOutlinedButton(
                                            label: 'Clear Filters',
                                            icon: Icons.filter_alt_off_rounded,
                                            onPressed: () =>
                                                notifier.setFilter(const IssueFilterState()),
                                          )
                                        : AppPrimaryButton(
                                            label: 'Create Issue',
                                            icon: Icons.add_rounded,
                                            onPressed: () => _openCreateIssue(notifier),
                                          ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(AppColors.radiusLg),
                                    border: Border.all(color: border),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      if (!isMobile)
                                        Container(
                                          height: 34,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: BoxDecoration(
                                            color: AppColors.bgFor(isDark).withValues(alpha: 0.55),
                                            border: Border(bottom: BorderSide(color: borderSoft)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: _SortableHeaderCell(
                                                  label: 'Issue',
                                                  active:
                                                      state.filter.sortField == IssueSortField.issueNumber,
                                                  ascending: state.filter.sortAscending,
                                                  color: textMuted,
                                                  onTap: () => _toggleSort(
                                                    state,
                                                    notifier,
                                                    IssueSortField.issueNumber,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 144,
                                                child: Text(
                                                  'Status',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: textMuted,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 118,
                                                child: _SortableHeaderCell(
                                                  label: 'Priority',
                                                  active:
                                                      state.filter.sortField == IssueSortField.priority,
                                                  ascending: state.filter.sortAscending,
                                                  color: textMuted,
                                                  onTap: () => _toggleSort(
                                                    state,
                                                    notifier,
                                                    IssueSortField.priority,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 120,
                                                child: Text(
                                                  'Labels',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: textMuted,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 96,
                                                child: Text(
                                                  'Assignee',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: textMuted,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 96,
                                                child: Text(
                                                  'Due date',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: textMuted,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 52,
                                                child: Align(
                                                  alignment: Alignment.centerRight,
                                                  child: _SortableHeaderCell(
                                                    label: 'Pts',
                                                    active:
                                                        state.filter.sortField == IssueSortField.estimate,
                                                    ascending: state.filter.sortAscending,
                                                    color: textMuted,
                                                    onTap: () => _toggleSort(
                                                      state,
                                                      notifier,
                                                      IssueSortField.estimate,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: issues.length,
                                          itemBuilder: (context, index) {
                                            final issue = issues[index];
                                            return _IssueTableRow(
                                              key: ValueKey('issues_row_${issue.id}'),
                                              issue: issue,
                                              projectId: widget.projectId,
                                              projectKey: state.projectKey,
                                              isMobile: isMobile,
                                              showDivider: index < issues.length - 1,
                                              onStatusChanged: (next) =>
                                                  notifier.updateIssueStatus(issue.id, next),
                                              onPriorityChanged: (next) =>
                                                  notifier.updateIssuePriority(issue.id, next),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortableHeaderCell extends StatelessWidget {
  final String label;
  final bool active;
  final bool ascending;
  final Color color;
  final VoidCallback onTap;

  const _SortableHeaderCell({
    required this.label,
    required this.active,
    required this.ascending,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
          if (active) ...[
            const SizedBox(width: 3),
            Icon(
              ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 11,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

class _IssueTableRow extends StatefulWidget {
  final IssueModel issue;
  final String projectId;
  final String projectKey;
  final bool isMobile;
  final bool showDivider;
  final ValueChanged<IssueStatus> onStatusChanged;
  final ValueChanged<IssuePriority> onPriorityChanged;

  const _IssueTableRow({
    super.key,
    required this.issue,
    required this.projectId,
    required this.projectKey,
    required this.isMobile,
    required this.showDivider,
    required this.onStatusChanged,
    required this.onPriorityChanged,
  });

  @override
  State<_IssueTableRow> createState() => _IssueTableRowState();
}

class _IssueTableRowState extends State<_IssueTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final issue = widget.issue;
    final statusColor = issue.status.colorFor(brightness);
    final priorityColor = issue.priority.colorFor(brightness);
    final typeColor = issue.type.colorFor(brightness);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);

    final dueDateText = issue.endDate != null
        ? DateFormat('dd-MM').format(issue.endDate!)
        : '—';
    final ptsText = issue.estimate != null
        ? (issue.estimate! % 1 == 0 ? '${issue.estimate!.toInt()}' : '${issue.estimate}')
        : '—';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: () => IssueDetailDialog.show(
          context,
          projectId: widget.projectId,
          projectKey: widget.projectKey,
          issue: issue,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hoverFor(isDark) : Colors.transparent,
            border: widget.showDivider ? Border(bottom: BorderSide(color: borderSoft)) : null,
          ),
          child: widget.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          issue.formattedKey(widget.projectKey),
                          style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issue.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(issue.status.icon, size: 12.5, color: statusColor),
                            const SizedBox(width: 4),
                            Text(issue.status.label, style: TextStyle(fontSize: 11, color: statusColor)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(issue.priority.icon, size: 12.5, color: priorityColor),
                            const SizedBox(width: 4),
                            Text(issue.priority.label, style: TextStyle(fontSize: 11, color: priorityColor)),
                          ],
                        ),
                        Text(dueDateText, style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted)),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Issue column: grip icon + monospace key + title
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_indicator_rounded,
                            size: 14,
                            color: textMuted.withValues(alpha: _hovered ? 0.85 : 0.4),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            issue.formattedKey(widget.projectKey),
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 11,
                              color: textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              issue.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status column (inline editable)
                    SizedBox(
                      width: 144,
                      child: PopupMenuButton<IssueStatus>(
                        tooltip: 'Change status',
                        onSelected: widget.onStatusChanged,
                        itemBuilder: (_) => IssueStatus.values.map((s) {
                          final c = s.colorFor(brightness);
                          return PopupMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                Icon(s.icon, size: 14, color: c),
                                const SizedBox(width: 8),
                                Text(s.label, style: TextStyle(fontSize: 12.5, color: c)),
                              ],
                            ),
                          );
                        }).toList(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(issue.status.icon, size: 14, color: statusColor),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                issue.status.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Priority column (inline editable)
                    SizedBox(
                      width: 118,
                      child: PopupMenuButton<IssuePriority>(
                        tooltip: 'Change priority',
                        onSelected: widget.onPriorityChanged,
                        itemBuilder: (_) => IssuePriority.values.map((p) {
                          final c = p.colorFor(brightness);
                          return PopupMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                Icon(p.icon, size: 14, color: c),
                                const SizedBox(width: 8),
                                Text(p.label, style: TextStyle(fontSize: 12.5, color: c)),
                              ],
                            ),
                          );
                        }).toList(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(issue.priority.icon, size: 13.5, color: priorityColor),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                issue.priority.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: priorityColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Labels column
                    SizedBox(
                      width: 120,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface2For(isDark),
                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                            border: Border.all(color: AppColors.borderFor(isDark)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                issue.type.label,
                                style: TextStyle(fontSize: 10.5, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Assignee column
                    SizedBox(
                      width: 96,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: issue.assignee != null
                            ? UserAvatar(
                                name: issue.assignee!.fullName.isNotEmpty
                                    ? issue.assignee!.fullName
                                    : issue.assignee!.email,
                                size: UserAvatarSize.xs,
                              )
                            : Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.surface3For(isDark),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.borderFor(isDark)),
                                ),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
                                  color: textMuted,
                                ),
                              ),
                      ),
                    ),

                    // Due date column
                    SizedBox(
                      width: 96,
                      child: Text(
                        dueDateText,
                        style: AppTypography.mono(
                          isDark,
                          fontSize: 11.5,
                          color: textSecondary,
                        ),
                      ),
                    ),

                    // Pts column
                    SizedBox(
                      width: 52,
                      child: Text(
                        ptsText,
                        textAlign: TextAlign.right,
                        style: AppTypography.mono(
                          isDark,
                          fontSize: 11.5,
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
