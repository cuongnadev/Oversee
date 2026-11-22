import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/application/backlog_state.dart';
import 'package:frontend/features/issue/domain/backlog_grouped_model.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/backlog_item_card.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/features/issue/presentation/widgets/quick_create_issue_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_complete_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:frontend/features/sprint/presentation/widgets/complete_sprint_dialog.dart';
import 'package:frontend/features/sprint/presentation/widgets/start_sprint_dialog.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Sprint-grouped Backlog Screen matching Figma Backlog Page (node 12:3289).
class BacklogScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const BacklogScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<BacklogScreen> createState() => _BacklogScreenState();
}

class _BacklogScreenState extends ConsumerState<BacklogScreen> {
  BoardSavedView _activeSavedView = BoardSavedView.all;
  final Set<String> _selectedIssueIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final queryParams = GoRouterState.of(context).uri.queryParameters;
        if (queryParams.isNotEmpty) {
          ref
              .read(backlogNotifierProvider(widget.projectId).notifier)
              .initFilterFromParams(queryParams);
        }
      } catch (_) {
        // Router state may not be ready in isolated test harness
      }
    });
  }

  void _updateUrlWithFilters(IssueFilterState filter) {
    try {
      final queryParams = filter.toQueryParams();
      final uri = Uri(
        path: AppRoutes.projectBacklogPath(widget.workspaceId, widget.projectId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      context.go(uri.toString());
    } catch (_) {}
  }

  void _handleSavedViewChanged(
    BoardSavedView view,
    BacklogState state,
    BacklogNotifier notifier,
  ) {
    setState(() => _activeSavedView = view);
    if (view == BoardSavedView.mine) {
      final next = state.filter.copyWith(selectedAssigneeId: 'me');
      notifier.setFilter(next);
      _updateUrlWithFilters(next);
    } else if (state.filter.selectedAssigneeId == 'me') {
      final next = state.filter.copyWith(clearAssigneeId: true);
      notifier.setFilter(next);
      _updateUrlWithFilters(next);
    }
  }

  Future<void> _openCreateIssue(
    BacklogNotifier notifier, {
    String? sprintId,
    IssueStatus? status,
  }) async {
    final created = await QuickCreateDialog.show(
      context,
      projectId: widget.projectId,
      initialType: QuickCreateEntityType.issue,
      initialSprintId: sprintId,
      initialStatus: status ?? (sprintId != null ? IssueStatus.todo : IssueStatus.backlog),
    );
    if (created == true && mounted) {
      await notifier.refresh();
    }
  }

  Future<void> _openCreateSprint(BacklogNotifier notifier) async {
    final created = await QuickCreateDialog.show(
      context,
      projectId: widget.projectId,
      initialType: QuickCreateEntityType.sprint,
    );
    if (created == true && mounted) {
      await notifier.refresh();
    }
  }

  Future<void> _openStartSprintDialog(SprintModel sprint, BacklogNotifier notifier) async {
    final sprintRepo = ref.read(sprintRepositoryProvider);
    final started = await showDialog<bool>(
      context: context,
      builder: (ctx) => StartSprintDialog(
        sprint: sprint,
        onStart: ({startDate, endDate}) async {
          await sprintRepo.startSprint(
            sprint.id,
            startDate: startDate,
            endDate: endDate,
          );
          return true;
        },
      ),
    );
    if (started == true && mounted) {
      AppFeedback.showSuccess(context, 'Sprint "${sprint.name}" started!');
      await notifier.refresh();
    }
  }

  Future<void> _openCompleteSprintDialog(
    BacklogSprintGroupModel group,
    BacklogState state,
    BacklogNotifier notifier,
  ) async {
    final sprintRepo = ref.read(sprintRepositoryProvider);
    final plannedSprints = state.sprintGroups
        .map((g) => g.sprint)
        .where((s) => s.status == SprintStatus.planned)
        .toList();
    final progress = SprintProgressModel(
      sprintId: group.sprint.id,
      sprintName: group.sprint.name,
      status: group.sprint.status,
      totalIssues: group.totalIssues,
      completedIssues: group.completedIssues,
      remainingIssues: group.totalIssues - group.completedIssues,
      issueProgressPercentage: group.completionPercentage,
      totalStoryPoints: group.totalStoryPoints,
      completedStoryPoints: group.completedStoryPoints,
      remainingStoryPoints: group.totalStoryPoints - group.completedStoryPoints,
      storyPointProgressPercentage: group.totalStoryPoints > 0
          ? (group.completedStoryPoints / group.totalStoryPoints * 100)
          : 0,
    );

    final result = await showDialog<SprintCompleteModel>(
      context: context,
      builder: (ctx) => CompleteSprintDialog(
        sprint: group.sprint,
        progress: progress,
        plannedSprints: plannedSprints,
        onComplete: ({targetSprintId}) => sprintRepo.completeSprint(
          group.sprint.id,
          targetSprintId: targetSprintId,
        ),
      ),
    );
    if (result != null && mounted) {
      AppFeedback.showSuccess(context, 'Sprint "${group.sprint.name}" completed!');
      await notifier.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(backlogNotifierProvider(widget.projectId));
    final notifier = ref.read(backlogNotifierProvider(widget.projectId).notifier);
    final projectKey = state.project?.key ?? 'PROJ';

    final visibleSprintGroups = state.filteredSprintGroups.map((group) {
      if (_activeSavedView == BoardSavedView.open) {
        return group.withIssues(
          group.issues
              .where((i) => i.status != IssueStatus.done && i.status != IssueStatus.canceled)
              .toList(),
        );
      }
      return group;
    }).toList();

    final visibleBacklogIssues = _activeSavedView == BoardSavedView.open
        ? state.filteredIssues
            .where((i) => i.status != IssueStatus.done && i.status != IssueStatus.canceled)
            .toList()
        : state.filteredIssues;

    final totalCount = visibleSprintGroups.fold<int>(0, (s, g) => s + g.issues.length) +
        visibleBacklogIssues.length;

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'backlog',
      title: 'Product Backlog',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'backlog',
          ),

          // Unified Figma WorkToolbar with 5-view switcher
          BoardFilterToolbar(
            filter: state.filter,
            members: state.members,
            currentUserId: state.currentUserId,
            totalCount: totalCount,
            activeSavedView: _activeSavedView,
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeView: 'backlog',
            onSavedViewChanged: (view) => _handleSavedViewChanged(view, state, notifier),
            onFilterChanged: (newFilter) {
              if (newFilter.selectedAssigneeId != 'me' &&
                  _activeSavedView == BoardSavedView.mine) {
                setState(() => _activeSavedView = BoardSavedView.all);
              }
              notifier.setFilter(newFilter);
              _updateUrlWithFilters(newFilter);
            },
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: BacklogSkeleton(),
                    )
                  : state.errorMessage != null &&
                          state.issues.isEmpty &&
                          state.sprintGroups.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(22),
                          child: AppErrorView(
                            error: state.errorMessage,
                            onRetry: () => notifier.loadBacklog(),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 28.0),
                          children: [
                            // Page Heading (Figma 12:3803)
                            _buildPageHeading(context, state, notifier, totalCount, isDark),
                            const SizedBox(height: 14.0),

                            // Inline Quick Create Issue Bar
                            QuickCreateIssueBar(projectId: widget.projectId),
                            const SizedBox(height: 18.0),

                            // Sprint-Grouped Sections (Active -> Planned -> Completed)
                            for (final group in visibleSprintGroups) ...[
                              _buildSprintGroupSection(
                                context,
                                group: group,
                                state: state,
                                notifier: notifier,
                                projectKey: projectKey,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16.0),
                            ],

                            // Unassigned Product Backlog Section
                            _buildUnassignedBacklogSection(
                              context,
                              issues: visibleBacklogIssues,
                              state: state,
                              notifier: notifier,
                              projectKey: projectKey,
                              isDark: isDark,
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeading(
    BuildContext context,
    BacklogState state,
    BacklogNotifier notifier,
    int totalCount,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final accentSolid = AppColors.accentSolidFor(isDark);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12.0,
      runSpacing: 10.0,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Backlog',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 24.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.7,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 10.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.surface3For(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Text(
                    '$totalCount issues',
                    style: AppTypography.mono(
                      isDark,
                      fontSize: 10.5,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoftFor(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Text(
                    state.totalAllStoryPoints % 1 == 0
                        ? '${state.totalAllStoryPoints.toInt()} SP'
                        : '${state.totalAllStoryPoints} SP',
                    style: AppTypography.mono(
                      isDark,
                      fontSize: 10.5,
                      color: AppColors.accentFor(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(
              '$totalCount Issues · Plan, prioritize, and organize work for the next sprint.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12.5,
                color: textSecondary,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh backlog',
              size: 32.0,
              backgroundColor: AppColors.surface2For(isDark),
              onPressed: () => notifier.refresh(),
            ),
            AppOutlinedButton(
              label: 'Create Sprint',
              icon: Icons.flag_outlined,
              height: 32.0,
              onPressed: () => _openCreateSprint(notifier),
            ),
            SizedBox(
              height: 32.0,
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
        ),
      ],
    );
  }

  Widget _buildSprintGroupSection(
    BuildContext context, {
    required BacklogSprintGroupModel group,
    required BacklogState state,
    required BacklogNotifier notifier,
    required String projectKey,
    required bool isDark,
  }) {
    final sprint = group.sprint;
    final isCollapsed = state.collapsedGroupIds.contains(sprint.id);
    final surface = AppColors.surfaceFor(isDark);
    final surface2 = AppColors.surface2For(isDark);
    final surface3 = AppColors.surface3For(isDark);
    final border = AppColors.borderFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final accent = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final success = AppColors.successFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final dateFmt = DateFormat('yyyy-MM-dd');
    final hasDateRange = sprint.startDate != null || sprint.endDate != null;
    final dateRangeStr = hasDateRange
        ? '${sprint.startDate != null ? dateFmt.format(sprint.startDate!) : 'TBD'} — ${sprint.endDate != null ? dateFmt.format(sprint.endDate!) : 'TBD'}'
        : null;

    final ptsLabel = group.totalStoryPoints % 1 == 0
        ? '${group.totalStoryPoints.toInt()} pts'
        : '${group.totalStoryPoints.toStringAsFixed(1)} pts';

    Color badgeBg;
    Color badgeFg;
    String badgeText;
    switch (sprint.status) {
      case SprintStatus.active:
        badgeBg = accentSoft;
        badgeFg = accent;
        badgeText = 'ACTIVE';
        break;
      case SprintStatus.planned:
        badgeBg = surface3;
        badgeFg = textSecondary;
        badgeText = 'PLANNED';
        break;
      case SprintStatus.completed:
        badgeBg = AppColors.greenSoftFor(isDark);
        badgeFg = success;
        badgeText = 'COMPLETED';
        break;
      case SprintStatus.closed:
        badgeBg = surface3;
        badgeFg = textMuted;
        badgeText = 'CLOSED';
        break;
    }

    return DragTarget<IssueModel>(
      onWillAcceptWithDetails: (details) =>
          sprint.status != SprintStatus.completed &&
          sprint.status != SprintStatus.closed &&
          details.data.sprintId != sprint.id,
      onAcceptWithDetails: (details) => notifier.moveIssueToSprint(details.data, sprint.id),
      builder: (context, candidateData, rejectedData) {
        final isDropHover = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: isDropHover ? accent : border,
              width: isDropHover ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sprint Header Bar (Figma 12:3824)
              Container(
                color: surface2,
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12.0,
                  runSpacing: 8.0,
                  children: [
                    // Left: Collapse Chevron + Sprint Name + Issue Count + Status Pill
                    InkWell(
                      onTap: () => notifier.toggleGroupCollapsed(sprint.id),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCollapsed
                                  ? Icons.keyboard_arrow_right_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sprint.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
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
                                '${group.totalIssues}',
                                style: AppTypography.mono(
                                  isDark,
                                  fontSize: 10,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: badgeFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right: Points + Done/Total + Progress Bar + Action Button + '+'
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 6.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$ptsLabel · ${group.completedIssues}/${group.totalIssues} done',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Linear finishing progress bar (Figma 12:3839: 64x4px)
                        Tooltip(
                          message: '${group.completionPercentage.toStringAsFixed(0)}% completed',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: SizedBox(
                              width: 64,
                              height: 4,
                              child: LinearProgressIndicator(
                                value: group.completionRatio,
                                backgroundColor: surface3,
                                valueColor: AlwaysStoppedAnimation<Color>(success),
                              ),
                            ),
                          ),
                        ),
                        if (sprint.isActive)
                          OutlinedButton.icon(
                            onPressed: () => _openCompleteSprintDialog(group, state, notifier),
                            icon: Icon(Icons.check_rounded, size: 13, color: textPrimary),
                            label: Text(
                              'Complete Sprint',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: surface,
                              side: BorderSide(color: border),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              minimumSize: const Size(0, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                              ),
                            ),
                          )
                        else if (sprint.isPlanned)
                          OutlinedButton.icon(
                            onPressed: () => _openStartSprintDialog(sprint, notifier),
                            icon: Icon(Icons.play_arrow_rounded, size: 14, color: accent),
                            label: Text(
                              'Start Sprint',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: surface,
                              side: BorderSide(color: accent.withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              minimumSize: const Size(0, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                              ),
                            ),
                          ),
                        if (sprint.status != SprintStatus.completed &&
                            sprint.status != SprintStatus.closed)
                          IconButton(
                            icon: Icon(Icons.add_rounded, size: 16, color: textSecondary),
                            tooltip: 'Add issue to ${sprint.name}',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(26, 26),
                              maximumSize: const Size(26, 26),
                            ),
                            onPressed: () => _openCreateIssue(
                              notifier,
                              sprintId: sprint.id,
                              status: IssueStatus.todo,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              if (!isCollapsed) ...[
                // Goal & Date Range bar (Figma 12:3850)
                if ((sprint.goal != null && sprint.goal!.trim().isNotEmpty) ||
                    dateRangeStr != null) ...[
                  Divider(height: 1, color: borderSoft),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 9.0),
                    color: surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sprint.goal?.trim().isNotEmpty == true ? sprint.goal!.trim() : '',
                            style: TextStyle(fontSize: 11.5, color: textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (dateRangeStr != null)
                          Text(
                            dateRangeStr,
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                Divider(height: 1, color: borderSoft),

                if (group.issues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Center(
                      child: Text(
                        'No issues in ${sprint.name}. Drag issues here or click + to add.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ),
                  )
                else
                  _buildSprintIssueTable(
                    context,
                    issues: group.issues,
                    projectKey: projectKey,
                    notifier: notifier,
                    isDark: isDark,
                    sprints: state.sprintGroups.map((g) => g.sprint).toList(),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSprintIssueTable(
    BuildContext context, {
    required List<IssueModel> issues,
    required String projectKey,
    required BacklogNotifier notifier,
    required bool isDark,
    required List<SprintModel> sprints,
  }) {
    final isCompact = ResponsiveBreakpoints.isMobile(context);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isCompact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.bgFor(isDark).withValues(alpha: 0.6),
              border: Border(bottom: BorderSide(color: borderSoft)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 44), // Checkbox + Drag handle
                Expanded(
                  flex: 5,
                  child: Text('Issue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                ),
                SizedBox(
                  width: 126,
                  child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                ),
                SizedBox(
                  width: 100,
                  child: Text('Priority', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                ),
                SizedBox(
                  width: 104,
                  child: Text('Labels', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                ),
                SizedBox(
                  width: 72,
                  child: Text('Assignee', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                ),
                SizedBox(
                  width: 78,
                  child: Text('Due date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    'Pts',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted),
                  ),
                ),
              ],
            ),
          ),
        for (int i = 0; i < issues.length; i++)
          _SprintIssueTableRow(
            key: ValueKey('sprint_issue_${issues[i].id}'),
            issue: issues[i],
            projectId: widget.projectId,
            projectKey: projectKey,
            isSelected: _selectedIssueIds.contains(issues[i].id),
            isCompact: isCompact,
            showDivider: i < issues.length - 1,
            onToggleSelect: (selected) {
              setState(() {
                if (selected) {
                  _selectedIssueIds.add(issues[i].id);
                } else {
                  _selectedIssueIds.remove(issues[i].id);
                }
              });
            },
            onStatusChanged: (nextStatus) =>
                notifier.updateIssueStatusInline(issues[i], nextStatus),
          ),
      ],
    );
  }

  Widget _buildUnassignedBacklogSection(
    BuildContext context, {
    required List<IssueModel> issues,
    required BacklogState state,
    required BacklogNotifier notifier,
    required String projectKey,
    required bool isDark,
  }) {
    const groupKey = '__backlog__';
    final isCollapsed = state.collapsedGroupIds.contains(groupKey);
    final surface = AppColors.surfaceFor(isDark);
    final surface2 = AppColors.surface2For(isDark);
    final surface3 = AppColors.surface3For(isDark);
    final border = AppColors.borderFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final accent = AppColors.accentFor(isDark);
    final success = AppColors.successFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final doneCount = issues.where((i) => i.status == IssueStatus.done).length;
    final pts = issues.fold<double>(0.0, (s, i) => s + (i.estimate ?? 0.0));
    final ptsLabel = pts % 1 == 0 ? '${pts.toInt()} pts' : '${pts.toStringAsFixed(1)} pts';
    final ratio = issues.isNotEmpty ? (doneCount / issues.length).clamp(0.0, 1.0) : 0.0;

    return DragTarget<IssueModel>(
      onWillAcceptWithDetails: (details) => details.data.sprintId != null,
      onAcceptWithDetails: (details) => notifier.moveIssueToBacklog(details.data),
      builder: (context, candidateData, rejectedData) {
        final isDropHover = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: isDropHover ? accent : border,
              width: isDropHover ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Backlog Section Header (Figma 12:4695)
              Container(
                color: surface2,
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12.0,
                  runSpacing: 8.0,
                  children: [
                    InkWell(
                      onTap: () => notifier.toggleGroupCollapsed(groupKey),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCollapsed
                                ? Icons.keyboard_arrow_right_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Product Backlog',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
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
                              '${issues.length}',
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$ptsLabel · $doneCount/${issues.length} done',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: SizedBox(
                            width: 64,
                            height: 4,
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: surface3,
                              valueColor: AlwaysStoppedAnimation<Color>(success),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.add_rounded, size: 16, color: textSecondary),
                          tooltip: 'Add issue to backlog',
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(26, 26),
                            maximumSize: const Size(26, 26),
                          ),
                          onPressed: () => _openCreateIssue(
                            notifier,
                            sprintId: null,
                            status: IssueStatus.backlog,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (!isCollapsed) ...[
                Divider(height: 1, color: borderSoft),
                if (issues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: state.hasActiveFilters
                          ? 'No matching backlog issues'
                          : 'Your Product Backlog is empty',
                      description: state.hasActiveFilters
                          ? 'Try adjusting your search terms or filters.'
                          : 'Quickly create issues using the input bar above to start planning.',
                      action: state.hasActiveFilters
                          ? AppOutlinedButton(
                              icon: Icons.filter_alt_off_rounded,
                              label: 'Clear Filters',
                              onPressed: () {
                                notifier.clearFilters();
                                _updateUrlWithFilters(const IssueFilterState());
                              },
                            )
                          : null,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: issues.length,
                      buildDefaultDragHandles: false,
                      onReorderItem: (oldIndex, newIndex) {
                        final adjusted = oldIndex < newIndex ? newIndex + 1 : newIndex;
                        notifier.reorderBacklog(oldIndex, adjusted);
                      },
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 6.0,
                          color: Colors.transparent,
                          shadowColor: Colors.black38,
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final issue = issues[index];
                        return Padding(
                          key: ValueKey('backlog_item_${issue.id}'),
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Draggable<IssueModel>(
                            data: issue,
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(AppColors.radiusMd),
                              child: Container(
                                width: 320,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                  border: Border.all(color: accent),
                                ),
                                child: Text(
                                  '${issue.formattedKey(projectKey)}  ${issue.title}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            child: BacklogItemCard(
                              index: index,
                              issue: issue,
                              projectKey: projectKey,
                              projectId: widget.projectId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Figma-aligned issue row inside a Sprint section on the Backlog Page.
class _SprintIssueTableRow extends StatefulWidget {
  final IssueModel issue;
  final String projectId;
  final String projectKey;
  final bool isSelected;
  final bool isCompact;
  final bool showDivider;
  final ValueChanged<bool> onToggleSelect;
  final ValueChanged<IssueStatus> onStatusChanged;

  const _SprintIssueTableRow({
    super.key,
    required this.issue,
    required this.projectId,
    required this.projectKey,
    required this.isSelected,
    required this.isCompact,
    required this.showDivider,
    required this.onToggleSelect,
    required this.onStatusChanged,
  });

  @override
  State<_SprintIssueTableRow> createState() => _SprintIssueTableRowState();
}

class _SprintIssueTableRowState extends State<_SprintIssueTableRow> {
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
    final dueText = issue.endDate != null ? DateFormat('dd-MM').format(issue.endDate!) : '—';

    final rowContent = MouseRegion(
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hoverFor(isDark) : Colors.transparent,
            border: widget.showDivider ? Border(bottom: BorderSide(color: borderSoft)) : null,
          ),
          child: Row(
            children: [
              // Checkbox + Drag handle
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: widget.isSelected,
                  onChanged: (v) => widget.onToggleSelect(v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.drag_indicator_rounded,
                size: 15,
                color: textMuted.withValues(alpha: _hovered ? 0.9 : 0.45),
              ),
              const SizedBox(width: 8),

              // Issue Key + Title
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Text(
                      issue.formattedKey(widget.projectKey),
                      style: AppTypography.mono(
                        isDark,
                        fontSize: 11,
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
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

              if (!widget.isCompact) ...[
                // Status (inline clickable)
                SizedBox(
                  width: 126,
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

                // Priority
                SizedBox(
                  width: 100,
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

                // Label / Type pill
                SizedBox(
                  width: 104,
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

                // Assignee
                SizedBox(
                  width: 72,
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
                            child: Icon(Icons.person_outline_rounded, size: 13, color: textMuted),
                          ),
                  ),
                ),

                // Due date
                SizedBox(
                  width: 78,
                  child: Text(
                    dueText,
                    style: AppTypography.mono(isDark, fontSize: 11, color: textSecondary),
                  ),
                ),

                // Points
                SizedBox(
                  width: 42,
                  child: Text(
                    issue.estimate != null
                        ? (issue.estimate! % 1 == 0
                            ? '${issue.estimate!.toInt()}'
                            : '${issue.estimate}')
                        : '—',
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
            ],
          ),
        ),
      ),
    );

    return Draggable<IssueModel>(
      data: issue,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.accentFor(isDark)),
          ),
          child: Text(
            '${issue.formattedKey(widget.projectKey)}  ${issue.title}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      child: rowContent,
    );
  }
}
