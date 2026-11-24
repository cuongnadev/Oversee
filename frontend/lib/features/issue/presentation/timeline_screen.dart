import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/issue/application/project_issues_provider.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

enum TimelineZoom {
  day('Day', 46.0, 28),
  week('Week', 32.0, 42),
  month('Month', 18.0, 75);

  final String label;
  final double dayWidth;
  final int visibleDays;
  const TimelineZoom(this.label, this.dayWidth, this.visibleDays);
}

/// Interactive Timeline (Gantt) screen matching Figma Timeline Page (node 12:6560).
/// Supports dragging bars horizontally to shift dates, dragging bar edges to resize,
/// clicking unscheduled rows to place dates, and changing issue status inline or via drag.
class TimelineScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const TimelineScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  BoardSavedView _activeSavedView = BoardSavedView.all;
  TimelineZoom _zoom = TimelineZoom.week;
  late DateTime _windowStart;
  final Set<IssueStatus> _collapsedStatuses = {};
  final ScrollController _horizontalScrollController = ScrollController();

  static const double _leftPaneWidth = 264.0;
  static const double _headerHeight = 58.0;
  static const double _groupRowHeight = 38.0;
  static const double _issueRowHeight = 40.0;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _windowStart = today.subtract(const Duration(days: 10));
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _shiftWindow(int days) {
    setState(() {
      _windowStart = _windowStart.add(Duration(days: days));
    });
  }

  void _jumpToToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _windowStart = today.subtract(const Duration(days: 10));
    });
    if (_horizontalScrollController.hasClients) {
      _horizontalScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openCreateIssue(ProjectIssuesNotifier notifier) async {
    final today = _dateOnly(DateTime.now());
    final created = await QuickCreateDialog.show(
      context,
      projectId: widget.projectId,
      initialType: QuickCreateEntityType.issue,
      initialStartDate: today,
      initialEndDate: today.add(const Duration(days: 5)),
    );
    if (created == true && mounted) {
      await notifier.refresh();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final state = ref.watch(projectIssuesProvider(widget.projectId));
    final notifier = ref.read(projectIssuesProvider(widget.projectId).notifier);

    ref.listen(projectIssuesProvider(widget.projectId), (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        AppFeedback.showError(context, next.errorMessage!);
        notifier.clearError();
      }
    });

    final allFiltered = _activeSavedView == BoardSavedView.open
        ? state.filteredIssues
            .where((i) => i.status != IssueStatus.done && i.status != IssueStatus.canceled)
            .toList()
        : state.filteredIssues;

    final windowEnd = _windowStart.add(Duration(days: _zoom.visibleDays - 1));
    final rangeLabel =
        '${DateFormat('dd-MM').format(_windowStart)} — ${DateFormat('dd-MM, yyyy').format(windowEnd)}';

    const statusOrder = [
      IssueStatus.backlog,
      IssueStatus.todo,
      IssueStatus.inProgress,
      IssueStatus.inReview,
      IssueStatus.done,
      IssueStatus.canceled,
    ];

    final grouped = <IssueStatus, List<IssueModel>>{
      for (final s in statusOrder) s: allFiltered.where((i) => i.status == s).toList(),
    };

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'timeline',
      title: 'Timeline',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'timeline',
          ),

          BoardFilterToolbar(
            filter: state.filter,
            members: state.members,
            currentUserId: state.currentUserId,
            totalCount: allFiltered.length,
            activeSavedView: _activeSavedView,
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeView: 'timeline',
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Heading (Figma 12:7074)
                  _buildHeading(context, notifier, isDark),
                  const SizedBox(height: 16),

                  // Date Window Controls & Zoom Selector (Figma 12:7089)
                  _buildControlsBar(rangeLabel, isDark),
                  const SizedBox(height: 14),

                  // Gantt Split View (Figma 12:7112)
                  Expanded(
                    child: state.isLoading
                        ? const BacklogSkeleton()
                        : _buildTimelineCard(
                            context,
                            state: state,
                            notifier: notifier,
                            grouped: grouped,
                            statusOrder: statusOrder,
                            totalIssues: allFiltered.length,
                            isDark: isDark,
                            brightness: brightness,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading(
    BuildContext context,
    ProjectIssuesNotifier notifier,
    bool isDark,
  ) {
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final accentSolid = AppColors.accentSolidFor(isDark);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.7,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'All work, on a single timeline.',
                style: TextStyle(fontSize: 12.5, color: textSecondary),
              ),
            ],
          ),
        ),
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
              backgroundColor: accentSolid,
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
    );
  }

  Widget _buildControlsBar(String rangeLabel, bool isDark) {
    final surface = AppColors.surfaceFor(isDark);
    final surface2 = AppColors.surface2For(isDark);
    final border = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rangeLabel,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            _smallNavBtn(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous window',
              color: textSecondary,
              onTap: () => _shiftWindow(-7),
            ),
            const SizedBox(width: 4),
            _smallNavBtn(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next window',
              color: textSecondary,
              onTap: () => _shiftWindow(7),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _jumpToToday,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: border),
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Drag bars to change dates',
              style: TextStyle(fontSize: 11.5, color: textMuted),
            ),
            const SizedBox(width: 10),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TimelineZoom>(
                  value: _zoom,
                  isDense: true,
                  dropdownColor: surface,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textPrimary),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: textMuted),
                  items: TimelineZoom.values
                      .map((z) => DropdownMenuItem(value: z, child: Text(z.label)))
                      .toList(),
                  onChanged: (z) {
                    if (z != null) setState(() => _zoom = z);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _smallNavBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 17, color: color),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(26, 26),
        maximumSize: const Size(26, 26),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildTimelineCard(
    BuildContext context, {
    required ProjectIssuesState state,
    required ProjectIssuesNotifier notifier,
    required Map<IssueStatus, List<IssueModel>> grouped,
    required List<IssueStatus> statusOrder,
    required int totalIssues,
    required bool isDark,
    required Brightness brightness,
  }) {
    final surface = AppColors.surfaceFor(isDark);
    final surface2 = AppColors.surface2For(isDark);
    final surface3 = AppColors.surface3For(isDark);
    final border = AppColors.borderFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final accent = AppColors.accentFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final days = List<DateTime>.generate(
      _zoom.visibleDays,
      (i) => _windowStart.add(Duration(days: i)),
    );
    final totalTimelineWidth = days.length * _zoom.dayWidth;
    final today = _dateOnly(DateTime.now());
    final todayIndex = today.difference(_windowStart).inDays;

    // Flatten visible rows so left pane & right canvas stay 100% height-aligned
    final entries = <_TimelineRowEntry>[];
    for (final status in statusOrder) {
      final list = grouped[status] ?? const [];
      if (list.isEmpty && status == IssueStatus.canceled) continue;
      entries.add(_TimelineRowEntry.group(status, list.length));
      if (!_collapsedStatuses.contains(status)) {
        for (final issue in list) {
          entries.add(_TimelineRowEntry.issue(issue));
        }
      }
    }

    final totalRowsHeight = entries.fold<double>(
      0.0,
      (sum, e) => sum + (e.isGroup ? _groupRowHeight : _issueRowHeight),
    );

    // Month spans for top timeline header
    final monthSpans = <_MonthSpan>[];
    for (final d in days) {
      final label = DateFormat('MMM yyyy').format(d);
      if (monthSpans.isEmpty || monthSpans.last.label != label) {
        monthSpans.add(_MonthSpan(label: label, dayCount: 1));
      } else {
        monthSpans.last = _MonthSpan(label: label, dayCount: monthSpans.last.dayCount + 1);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT FIXED PANE: Status groups + issue list
            Container(
              width: _leftPaneWidth,
              decoration: BoxDecoration(
                color: surface,
                border: Border(right: BorderSide(color: border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header cell
                  Container(
                    height: _headerHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'ISSUE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: surface3,
                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          ),
                          child: Text(
                            '$totalIssues',
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 10,
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rows
                  for (final entry in entries)
                    if (entry.isGroup)
                      DragTarget<IssueModel>(
                        onWillAcceptWithDetails: (d) => d.data.status != entry.status,
                        onAcceptWithDetails: (d) =>
                            notifier.updateIssueStatus(d.data.id, entry.status!),
                        builder: (ctx, candidates, _) {
                          final hovering = candidates.isNotEmpty;
                          final s = entry.status!;
                          final sc = s.colorFor(brightness);
                          final collapsed = _collapsedStatuses.contains(s);
                          return InkWell(
                            onTap: () => setState(() {
                              if (collapsed) {
                                _collapsedStatuses.remove(s);
                              } else {
                                _collapsedStatuses.add(s);
                              }
                            }),
                            child: Container(
                              height: _groupRowHeight,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: hovering
                                    ? AppColors.accentSoftFor(isDark)
                                    : surface2.withValues(alpha: 0.75),
                                border: Border(bottom: BorderSide(color: borderSoft)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    collapsed
                                        ? Icons.keyboard_arrow_right_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: textMuted,
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(s.icon, size: 13.5, color: sc),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      s.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: surface3,
                                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                    ),
                                    child: Text(
                                      '${entry.count}',
                                      style: AppTypography.mono(
                                        isDark,
                                        fontSize: 10,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      _buildLeftIssueRow(
                        context,
                        issue: entry.issue!,
                        projectKey: state.projectKey,
                        notifier: notifier,
                        isDark: isDark,
                        brightness: brightness,
                      ),
                ],
              ),
            ),

            // RIGHT SCROLLABLE GANTT CANVAS
            Expanded(
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalTimelineWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month & Day Headers
                        Container(
                          height: _headerHeight,
                          decoration: BoxDecoration(
                            color: surface,
                            border: Border(bottom: BorderSide(color: border)),
                          ),
                          child: Column(
                            children: [
                              // Month Row
                              SizedBox(
                                height: 28,
                                child: Row(
                                  children: monthSpans.map((span) {
                                    return Container(
                                      width: span.dayCount * _zoom.dayWidth,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: borderSoft)),
                                      ),
                                      child: Text(
                                        span.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              // Day Number Row
                              SizedBox(
                                height: 29,
                                child: Row(
                                  children: days.map((d) {
                                    final isToday = d == today;
                                    final isWeekend =
                                        d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
                                    return Container(
                                      width: _zoom.dayWidth,
                                      alignment: Alignment.center,
                                      color: isWeekend
                                          ? surface2.withValues(alpha: 0.45)
                                          : Colors.transparent,
                                      child: Text(
                                        DateFormat('dd').format(d),
                                        style: AppTypography.mono(
                                          isDark,
                                          fontSize: 10,
                                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                          color: isToday ? accent : textMuted,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Grid + Bars + Today Line Stack
                        SizedBox(
                          width: totalTimelineWidth,
                          height: totalRowsHeight < 240 ? 240 : totalRowsHeight,
                          child: Stack(
                            children: [
                              // Background day columns
                              Positioned.fill(
                                child: Row(
                                  children: days.map((d) {
                                    final isWeekend =
                                        d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
                                    return Container(
                                      width: _zoom.dayWidth,
                                      decoration: BoxDecoration(
                                        color: isWeekend
                                            ? surface2.withValues(alpha: 0.35)
                                            : Colors.transparent,
                                        border: Border(
                                          right: BorderSide(color: borderSoft.withValues(alpha: 0.7)),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              // Horizontal rows & interactive draggable bars
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: entries.map((entry) {
                                  if (entry.isGroup) {
                                    return Container(
                                      height: _groupRowHeight,
                                      width: totalTimelineWidth,
                                      decoration: BoxDecoration(
                                        color: surface2.withValues(alpha: 0.45),
                                        border: Border(bottom: BorderSide(color: borderSoft)),
                                      ),
                                    );
                                  }
                                  return _TimelineBarRow(
                                    key: ValueKey('tl_bar_${entry.issue!.id}'),
                                    issue: entry.issue!,
                                    projectId: widget.projectId,
                                    projectKey: state.projectKey,
                                    windowStart: _windowStart,
                                    dayWidth: _zoom.dayWidth,
                                    visibleDays: _zoom.visibleDays,
                                    rowHeight: _issueRowHeight,
                                    onDatesCommitted: (start, end) {
                                      notifier.updateIssueDates(
                                        entry.issue!.id,
                                        startDate: start,
                                        endDate: end,
                                      );
                                    },
                                  );
                                }).toList(),
                              ),

                              // Vertical Today marker line (Figma purple line + date pill)
                              if (todayIndex >= 0 && todayIndex < days.length)
                                Positioned(
                                  left: (todayIndex + 0.5) * _zoom.dayWidth,
                                  top: 0,
                                  bottom: 0,
                                  child: IgnorePointer(
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 1.5,
                                          color: accent.withValues(alpha: 0.8),
                                        ),
                                        Positioned(
                                          left: 4,
                                          top: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentSoftFor(isDark),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              DateFormat('dd MMM').format(today).toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                color: accent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftIssueRow(
    BuildContext context, {
    required IssueModel issue,
    required String projectKey,
    required ProjectIssuesNotifier notifier,
    required bool isDark,
    required Brightness brightness,
  }) {
    final borderSoft = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final statusColor = issue.status.colorFor(brightness);

    final row = InkWell(
      onTap: () => IssueDetailDialog.show(
        context,
        projectId: widget.projectId,
        projectKey: projectKey,
        issue: issue,
      ),
      child: Container(
        height: _issueRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderSoft)),
        ),
        child: Row(
          children: [
            // Inline status switcher menu
            PopupMenuButton<IssueStatus>(
              tooltip: 'Change status (${issue.status.label})',
              onSelected: (nextStatus) => notifier.updateIssueStatus(issue.id, nextStatus),
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
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(issue.status.icon, size: 13, color: statusColor),
              ),
            ),
            Text(
              issue.formattedKey(projectKey),
              style: AppTypography.mono(
                isDark,
                fontSize: 10,
                color: textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                issue.title,
                style: TextStyle(
                  fontSize: 11.5,
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
    );

    return Draggable<IssueModel>(
      data: issue,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.accentFor(isDark)),
          ),
          child: Text(
            '${issue.formattedKey(projectKey)}  ${issue.title}',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      child: row,
    );
  }
}

class _TimelineRowEntry {
  final bool isGroup;
  final IssueStatus? status;
  final int count;
  final IssueModel? issue;

  const _TimelineRowEntry.group(this.status, this.count)
      : isGroup = true,
        issue = null;

  const _TimelineRowEntry.issue(this.issue)
      : isGroup = false,
        status = null,
        count = 0;
}

class _MonthSpan {
  final String label;
  final int dayCount;
  const _MonthSpan({required this.label, required this.dayCount});
}

/// Interactive Gantt bar row supporting horizontal move-drag, left/right edge resize-drag,
/// and click-to-schedule for unscheduled issues.
class _TimelineBarRow extends StatefulWidget {
  final IssueModel issue;
  final String projectId;
  final String projectKey;
  final DateTime windowStart;
  final double dayWidth;
  final int visibleDays;
  final double rowHeight;
  final void Function(DateTime start, DateTime end) onDatesCommitted;

  const _TimelineBarRow({
    super.key,
    required this.issue,
    required this.projectId,
    required this.projectKey,
    required this.windowStart,
    required this.dayWidth,
    required this.visibleDays,
    required this.rowHeight,
    required this.onDatesCommitted,
  });

  @override
  State<_TimelineBarRow> createState() => _TimelineBarRowState();
}

class _TimelineBarRowState extends State<_TimelineBarRow> {
  double _moveDx = 0;
  double _leftResizeDx = 0;
  double _rightResizeDx = 0;
  bool _isDragging = false;
  bool _isHovered = false;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final borderSoft = AppColors.borderSoftFor(isDark);
    final accent = AppColors.accentFor(isDark);
    final statusColor = widget.issue.status.colorFor(brightness);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final rawStart = widget.issue.startDate ?? widget.issue.endDate;
    final rawEnd = widget.issue.endDate ?? widget.issue.startDate;
    final totalWidth = widget.visibleDays * widget.dayWidth;

    // Unscheduled row: show "Unscheduled" label + click anywhere on grid to schedule!
    if (rawStart == null || rawEnd == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final dayOffset = (details.localPosition.dx / widget.dayWidth).floor().clamp(0, widget.visibleDays - 1);
          final pickedStart = widget.windowStart.add(Duration(days: dayOffset));
          widget.onDatesCommitted(pickedStart, pickedStart.add(const Duration(days: 4)));
        },
        child: Container(
          height: widget.rowHeight,
          width: totalWidth,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderSoft)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 10),
          child: Tooltip(
            message: 'Click on any date column to schedule this issue',
            child: Text(
              'Unscheduled',
              style: TextStyle(fontSize: 10.5, color: textMuted, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }

    final baseStart = _dateOnly(rawStart);
    final baseEnd = _dateOnly(rawEnd).isBefore(baseStart) ? baseStart : _dateOnly(rawEnd);

    final moveDays = (_moveDx / widget.dayWidth).round();
    final leftDays = (_leftResizeDx / widget.dayWidth).round();
    final rightDays = (_rightResizeDx / widget.dayWidth).round();

    DateTime previewStart = baseStart.add(Duration(days: moveDays + leftDays));
    DateTime previewEnd = baseEnd.add(Duration(days: moveDays + rightDays));
    if (previewEnd.isBefore(previewStart)) {
      if (_leftResizeDx != 0) {
        previewStart = previewEnd;
      } else {
        previewEnd = previewStart;
      }
    }

    final startOffsetDays = previewStart.difference(widget.windowStart).inDays;
    final spanDays = previewEnd.difference(previewStart).inDays + 1;
    final barLeft = startOffsetDays * widget.dayWidth;
    final barWidth = (spanDays * widget.dayWidth).clamp(widget.dayWidth, totalWidth * 2);

    final dateRangeTooltip =
        '${DateFormat('MMM d').format(previewStart)} — ${DateFormat('MMM d, yyyy').format(previewEnd)}';

    return Container(
      height: widget.rowHeight,
      width: totalWidth,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderSoft)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: barLeft,
            top: 7,
            width: barWidth,
            height: widget.rowHeight - 14,
            child: MouseRegion(
              cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: Tooltip(
                message: '${widget.issue.title}\n$dateRangeTooltip',
                child: Container(
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? AppColors.accentSoftFor(isDark)
                        : (isDark
                            ? AppColors.surface2For(isDark)
                            : const Color(0xFFEEEBF6)),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(
                      color: _isDragging
                          ? accent
                          : (_isHovered
                              ? statusColor.withValues(alpha: 0.75)
                              : AppColors.borderFor(isDark)),
                      width: _isDragging ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Left resize handle
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                          onHorizontalDragUpdate: (d) =>
                              setState(() => _leftResizeDx += d.delta.dx),
                          onHorizontalDragEnd: (_) {
                            final delta = (_leftResizeDx / widget.dayWidth).round();
                            setState(() {
                              _leftResizeDx = 0;
                              _isDragging = false;
                            });
                            if (delta != 0) {
                              var nextStart = baseStart.add(Duration(days: delta));
                              if (nextStart.isAfter(baseEnd)) nextStart = baseEnd;
                              widget.onDatesCommitted(nextStart, baseEnd);
                            }
                          },
                          child: Container(
                            width: 8,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: _isHovered || _isDragging
                                  ? statusColor.withValues(alpha: 0.35)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(AppColors.radiusMd - 1),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Draggable bar center
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => IssueDetailDialog.show(
                            context,
                            projectId: widget.projectId,
                            projectKey: widget.projectKey,
                            issue: widget.issue,
                          ),
                          onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                          onHorizontalDragUpdate: (d) => setState(() => _moveDx += d.delta.dx),
                          onHorizontalDragEnd: (_) {
                            final delta = (_moveDx / widget.dayWidth).round();
                            setState(() {
                              _moveDx = 0;
                              _isDragging = false;
                            });
                            if (delta != 0) {
                              widget.onDatesCommitted(
                                baseStart.add(Duration(days: delta)),
                                baseEnd.add(Duration(days: delta)),
                              );
                            }
                          },
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                widget.issue.title,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Right resize handle
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                          onHorizontalDragUpdate: (d) =>
                              setState(() => _rightResizeDx += d.delta.dx),
                          onHorizontalDragEnd: (_) {
                            final delta = (_rightResizeDx / widget.dayWidth).round();
                            setState(() {
                              _rightResizeDx = 0;
                              _isDragging = false;
                            });
                            if (delta != 0) {
                              var nextEnd = baseEnd.add(Duration(days: delta));
                              if (nextEnd.isBefore(baseStart)) nextEnd = baseStart;
                              widget.onDatesCommitted(baseStart, nextEnd);
                            }
                          },
                          child: Container(
                            width: 8,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: _isHovered || _isDragging
                                  ? statusColor.withValues(alpha: 0.35)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(AppColors.radiusMd - 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
