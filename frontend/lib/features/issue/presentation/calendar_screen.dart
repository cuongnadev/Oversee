import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/application/project_issues_provider.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

enum CalendarViewMode {
  month('Month'),
  week('Week');

  final String label;
  const CalendarViewMode(this.label);
}

/// Interactive Monthly / Weekly Calendar screen matching Figma Calendar Page (node 12:8449).
/// Supports dragging issues between calendar day cells and dragging unscheduled issues
/// from the right panel onto any day to schedule them dynamically.
class CalendarScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const CalendarScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  BoardSavedView _activeSavedView = BoardSavedView.all;
  CalendarViewMode _viewMode = CalendarViewMode.month;
  late DateTime _focusedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDate = DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _stepPeriod(int direction) {
    setState(() {
      if (_viewMode == CalendarViewMode.month) {
        _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + direction, 1);
      } else {
        _focusedDate = _focusedDate.add(Duration(days: 7 * direction));
      }
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDate = DateTime(now.year, now.month, now.day);
    });
  }

  /// Generates all visible day cells (Monday-first) for either Month (5-6 weeks) or Week (7 days).
  List<DateTime> _buildVisibleDays() {
    if (_viewMode == CalendarViewMode.week) {
      final weekdayOffset = _focusedDate.weekday - DateTime.monday;
      final monday = _focusedDate.subtract(Duration(days: weekdayOffset));
      return List<DateTime>.generate(7, (i) => monday.add(Duration(days: i)));
    }

    final firstOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final leadingDays = firstOfMonth.weekday - DateTime.monday;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingDays));
    final lastOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
    final totalNeeded = leadingDays + lastOfMonth.day;
    final weeks = (totalNeeded / 7).ceil().clamp(5, 6);
    return List<DateTime>.generate(weeks * 7, (i) => gridStart.add(Duration(days: i)));
  }

  DateTime? _issueCalendarDate(IssueModel issue) {
    final anchor = issue.endDate ?? issue.startDate;
    return anchor != null ? _dateOnly(anchor) : null;
  }

  Future<void> _rescheduleIssueToDay(
    ProjectIssuesNotifier notifier,
    IssueModel issue,
    DateTime targetDay,
  ) async {
    final target = _dateOnly(targetDay);
    DateTime nextStart = target;
    DateTime nextEnd = target;

    if (issue.startDate != null && issue.endDate != null) {
      final oldStart = _dateOnly(issue.startDate!);
      final oldEnd = _dateOnly(issue.endDate!);
      final durationDays = oldEnd.difference(oldStart).inDays;
      if (durationDays >= 0) {
        nextEnd = target;
        nextStart = target.subtract(Duration(days: durationDays));
      }
    }

    await notifier.updateIssueDates(
      issue.id,
      startDate: nextStart,
      endDate: nextEnd,
    );
  }

  Future<void> _openCreateIssue(
    ProjectIssuesNotifier notifier, {
    DateTime? date,
  }) async {
    final created = await QuickCreateDialog.show(
      context,
      projectId: widget.projectId,
      initialType: QuickCreateEntityType.issue,
      initialStartDate: date,
      initialEndDate: date,
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
    final isWide = !ResponsiveBreakpoints.isMobile(context) && MediaQuery.sizeOf(context).width >= 960;
    final state = ref.watch(projectIssuesProvider(widget.projectId));
    final notifier = ref.read(projectIssuesProvider(widget.projectId).notifier);

    ref.listen(projectIssuesProvider(widget.projectId), (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        AppFeedback.showError(context, next.errorMessage!);
        notifier.clearError();
      }
    });

    final filtered = _activeSavedView == BoardSavedView.open
        ? state.filteredIssues
            .where((i) => i.status != IssueStatus.done && i.status != IssueStatus.canceled)
            .toList()
        : state.filteredIssues;

    final unscheduled = filtered.where((i) => _issueCalendarDate(i) == null).toList();
    final issuesByDay = <DateTime, List<IssueModel>>{};
    for (final issue in filtered) {
      final day = _issueCalendarDate(issue);
      if (day != null) {
        issuesByDay.putIfAbsent(day, () => []).add(issue);
      }
    }

    final visibleDays = _buildVisibleDays();
    final today = _dateOnly(DateTime.now());
    final periodTitle = _viewMode == CalendarViewMode.month
        ? DateFormat('MMMM yyyy').format(_focusedDate)
        : '${DateFormat('MMM d').format(visibleDays.first)} — ${DateFormat('MMM d, yyyy').format(visibleDays.last)}';

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'calendar',
      title: 'Calendar',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'calendar',
          ),

          BoardFilterToolbar(
            filter: state.filter,
            members: state.members,
            currentUserId: state.currentUserId,
            totalCount: filtered.length,
            activeSavedView: _activeSavedView,
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeView: 'calendar',
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
                  _buildHeading(notifier, isDark),
                  const SizedBox(height: 16),
                  _buildControlsRow(periodTitle, isDark),
                  const SizedBox(height: 14),
                  Expanded(
                    child: state.isLoading
                        ? const BacklogSkeleton()
                        : isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _buildCalendarGridCard(
                                      visibleDays: visibleDays,
                                      today: today,
                                      issuesByDay: issuesByDay,
                                      projectKey: state.projectKey,
                                      notifier: notifier,
                                      isDark: isDark,
                                      brightness: brightness,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 248,
                                    child: _buildUnscheduledSidebar(
                                      unscheduled: unscheduled,
                                      projectKey: state.projectKey,
                                      notifier: notifier,
                                      isDark: isDark,
                                      brightness: brightness,
                                    ),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: 540,
                                      child: _buildCalendarGridCard(
                                        visibleDays: visibleDays,
                                        today: today,
                                        issuesByDay: issuesByDay,
                                        projectKey: state.projectKey,
                                        notifier: notifier,
                                        isDark: isDark,
                                        brightness: brightness,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 260,
                                      child: _buildUnscheduledSidebar(
                                        unscheduled: unscheduled,
                                        projectKey: state.projectKey,
                                        notifier: notifier,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading(ProjectIssuesNotifier notifier, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendar',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.7,
                  color: AppColors.textPrimaryFor(isDark),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'A clear view of upcoming dates and deadlines.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryFor(isDark)),
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
    );
  }

  Widget _buildControlsRow(String periodTitle, bool isDark) {
    final surface = AppColors.surfaceFor(isDark);
    final surface2 = AppColors.surface2For(isDark);
    final border = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);

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
              periodTitle,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Previous',
              icon: Icon(Icons.chevron_left_rounded, size: 17, color: textSecondary),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(26, 26),
                maximumSize: const Size(26, 26),
              ),
              onPressed: () => _stepPeriod(-1),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Next',
              icon: Icon(Icons.chevron_right_rounded, size: 17, color: textSecondary),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(26, 26),
                maximumSize: const Size(26, 26),
              ),
              onPressed: () => _stepPeriod(1),
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

        // Segmented Month / Week Toggle (Figma 12:8992)
        Container(
          height: 28,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: surface2,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: CalendarViewMode.values.map((mode) {
              final active = _viewMode == mode;
              return InkWell(
                onTap: () => setState(() => _viewMode = mode),
                borderRadius: BorderRadius.circular(AppColors.radiusSm + 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm + 1),
                    border: active ? Border.all(color: border) : null,
                  ),
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? textPrimary : textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGridCard({
    required List<DateTime> visibleDays,
    required DateTime today,
    required Map<DateTime, List<IssueModel>> issuesByDay,
    required String projectKey,
    required ProjectIssuesNotifier notifier,
    required bool isDark,
    required Brightness brightness,
  }) {
    final surface = AppColors.surfaceFor(isDark);
    final border = AppColors.borderFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final numRows = (visibleDays.length / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Weekday Header Row (Figma 12:8999)
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: surface,
              border: Border(bottom: BorderSide(color: borderSoft)),
            ),
            child: Row(
              children: weekdays.map((dayName) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Day Rows
          Expanded(
            child: Column(
              children: List<Widget>.generate(numRows, (rowIndex) {
                return Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List<Widget>.generate(7, (colIndex) {
                      final day = visibleDays[rowIndex * 7 + colIndex];
                      final isCurrentMonth =
                          _viewMode == CalendarViewMode.week || day.month == _focusedDate.month;
                      final isToday = day == today;
                      final dayIssues = issuesByDay[day] ?? const [];

                      return Expanded(
                        child: _CalendarDayCell(
                          key: ValueKey('cal_day_${day.year}_${day.month}_${day.day}'),
                          day: day,
                          isCurrentMonth: isCurrentMonth,
                          isToday: isToday,
                          showRightBorder: colIndex < 6,
                          showBottomBorder: rowIndex < numRows - 1,
                          issues: dayIssues,
                          projectId: widget.projectId,
                          projectKey: projectKey,
                          isDark: isDark,
                          brightness: brightness,
                          onIssueDropped: (issue) =>
                              _rescheduleIssueToDay(notifier, issue, day),
                          onAddIssueForDay: () => _openCreateIssue(notifier, date: day),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnscheduledSidebar({
    required List<IssueModel> unscheduled,
    required String projectKey,
    required ProjectIssuesNotifier notifier,
    required bool isDark,
    required Brightness brightness,
  }) {
    final surface = AppColors.surfaceFor(isDark);
    final surface2 = AppColors.surface2For(isDark);
    final surface3 = AppColors.surface3For(isDark);
    final border = AppColors.borderFor(isDark);
    final accent = AppColors.accentFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return DragTarget<IssueModel>(
      onWillAcceptWithDetails: (d) => _issueCalendarDate(d.data) != null,
      onAcceptWithDetails: (d) => notifier.updateIssueDates(
        d.data.id,
        clearStartDate: true,
        clearEndDate: true,
      ),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: hovering ? accent : border,
              width: hovering ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (Figma 12:9402)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Text(
                      'Unscheduled',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: surface3,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Text(
                        '${unscheduled.length}',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  hovering
                      ? 'Drop here to remove due date.'
                      : 'Drag an issue onto a day to schedule it.',
                  style: TextStyle(
                    fontSize: 11,
                    color: hovering ? accent : textMuted,
                  ),
                ),
              ),

              // Draggable Unscheduled Cards
              Expanded(
                child: unscheduled.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'All issues are scheduled!',
                            style: TextStyle(fontSize: 11.5, color: textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: unscheduled.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final issue = unscheduled[index];
                          final sc = issue.status.colorFor(brightness);
                          final card = InkWell(
                            onTap: () => IssueDetailDialog.show(
                              context,
                              projectId: widget.projectId,
                              projectKey: projectKey,
                              issue: issue,
                            ),
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: surface2,
                                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                border: Border.all(color: border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(issue.status.icon, size: 12.5, color: sc),
                                      const SizedBox(width: 6),
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
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        issue.formattedKey(projectKey),
                                        style: AppTypography.mono(
                                          isDark,
                                          fontSize: 10,
                                          color: textMuted,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (issue.assignee != null)
                                        UserAvatar(
                                          name: issue.assignee!.fullName.isNotEmpty
                                              ? issue.assignee!.fullName
                                              : issue.assignee!.email,
                                          size: UserAvatarSize.xs,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          return Draggable<IssueModel>(
                            data: issue,
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(AppColors.radiusMd),
                              child: SizedBox(
                                width: 210,
                                child: Opacity(opacity: 0.92, child: card),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: 0.4, child: card),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: card,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarDayCell extends StatefulWidget {
  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final bool showRightBorder;
  final bool showBottomBorder;
  final List<IssueModel> issues;
  final String projectId;
  final String projectKey;
  final bool isDark;
  final Brightness brightness;
  final ValueChanged<IssueModel> onIssueDropped;
  final VoidCallback onAddIssueForDay;

  const _CalendarDayCell({
    super.key,
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.showRightBorder,
    required this.showBottomBorder,
    required this.issues,
    required this.projectId,
    required this.projectKey,
    required this.isDark,
    required this.brightness,
    required this.onIssueDropped,
    required this.onAddIssueForDay,
  });

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _isCellHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderSoft = AppColors.borderSoftFor(widget.isDark);
    final accent = AppColors.accentFor(widget.isDark);
    final accentSolid = AppColors.accentSolidFor(widget.isDark);
    final accentSoft = AppColors.accentSoftFor(widget.isDark);
    final textPrimary = AppColors.textPrimaryFor(widget.isDark);
    final textMuted = AppColors.textMutedFor(widget.isDark);

    return DragTarget<IssueModel>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => widget.onIssueDropped(details.data),
      builder: (context, candidates, _) {
        final isDragHover = candidates.isNotEmpty;
        final cellBg = isDragHover
            ? accentSoft.withValues(alpha: widget.isDark ? 0.85 : 0.95)
            : widget.isToday
                ? accentSoft.withValues(alpha: widget.isDark ? 0.35 : 0.45)
                : (!widget.isCurrentMonth
                    ? AppColors.bgFor(widget.isDark).withValues(alpha: 0.45)
                    : Colors.transparent);

        return MouseRegion(
          onEnter: (_) => setState(() => _isCellHovered = true),
          onExit: (_) => setState(() => _isCellHovered = false),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cellBg,
              border: Border(
                right: widget.showRightBorder ? BorderSide(color: borderSoft) : BorderSide.none,
                bottom: widget.showBottomBorder ? BorderSide(color: borderSoft) : BorderSide.none,
                top: isDragHover ? BorderSide(color: accent, width: 1.5) : BorderSide.none,
                left: isDragHover ? BorderSide(color: accent, width: 1.5) : BorderSide.none,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Day number header + hover '+' quick-add
                Row(
                  children: [
                    if (widget.isToday)
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accentSolid,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${widget.day.day}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        child: Text(
                          '${widget.day.day}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: widget.isCurrentMonth ? FontWeight.w500 : FontWeight.w400,
                            color: widget.isCurrentMonth
                                ? textPrimary
                                : textMuted.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (_isCellHovered)
                      InkWell(
                        onTap: widget.onAddIssueForDay,
                        borderRadius: BorderRadius.circular(4),
                        child: Tooltip(
                          message: 'Add issue on ${DateFormat('MMM d').format(widget.day)}',
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.add_rounded, size: 13, color: textMuted),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Issue chips inside this day
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: widget.issues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 3),
                    itemBuilder: (context, idx) {
                      final issue = widget.issues[idx];
                      final sc = issue.status.colorFor(widget.brightness);
                      final chip = InkWell(
                        onTap: () => IssueDetailDialog.show(
                          context,
                          projectId: widget.projectId,
                          projectKey: widget.projectKey,
                          issue: issue,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceFor(widget.isDark),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.borderSoftFor(widget.isDark),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(issue.status.icon, size: 11, color: sc),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  issue.title,
                                  style: TextStyle(
                                    fontSize: 10.5,
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
                          borderRadius: BorderRadius.circular(5),
                          child: SizedBox(width: 170, child: chip),
                        ),
                        childWhenDragging: Opacity(opacity: 0.35, child: chip),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: chip,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
