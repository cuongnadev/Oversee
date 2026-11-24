import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';
import 'package:frontend/features/dashboard/presentation/widgets/burndown_chart_widget.dart';
import 'package:frontend/features/dashboard/presentation/widgets/priority_breakdown_widget.dart';
import 'package:frontend/features/dashboard/presentation/widgets/progress_summary_cards.dart';
import 'package:frontend/features/dashboard/presentation/widgets/risk_issues_widget.dart';
import 'package:frontend/features/dashboard/presentation/widgets/status_distribution_widget.dart';
import 'package:frontend/features/dashboard/presentation/widgets/workload_by_assignee_widget.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Project Progress Dashboard screen aligned with Figma Dashboard.
class DashboardScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const DashboardScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider(widget.projectId));
    final notifier = ref.read(dashboardProvider(widget.projectId).notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppKeyboardShortcuts(
      onRefresh: () => notifier.refresh(),
      child: ProjectScreenScaffold(
        workspaceId: widget.workspaceId,
        projectId: widget.projectId,
        currentRoute: 'dashboard',
        title: 'Project Dashboard',
        body: Column(
          children: [
            ProjectNavigationTabBar(
              workspaceId: widget.workspaceId,
              projectId: widget.projectId,
              activeTab: 'dashboard',
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => notifier.refresh(),
                child: state.isLoading
                    ? const DashboardSkeleton()
                    : state.errorMessage != null
                        ? AppErrorView(
                            error: state.errorMessage,
                            onRetry: () => notifier.refresh(),
                          )
                        : state.selectedSprint == null
                            ? AppEmptyState.noSprints(
                                onGoToPlanning: () {
                                  context.go(AppRoutes.projectSprintPlanningPath(
                                    widget.workspaceId,
                                    widget.projectId,
                                  ));
                                },
                              )
                            : SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1560),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Heading & Sprint Selector Toolbar
                                        _buildTopToolbar(context, state, notifier, isDark),
                                        const SizedBox(height: 18),

                                        // Figma Active Sprint Highlight Banner
                                        _buildSprintBanner(context, state, isDark),
                                        const SizedBox(height: 18),

                                        // KPI Metric Summary Cards (4-col)
                                        ProgressSummaryCards(state: state, isDark: isDark),
                                        const SizedBox(height: 18),

                                        // Main Analytics Grid (Figma .dashboard-grid)
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final isWide = constraints.maxWidth >= 920;

                                            if (isWide) {
                                              return Column(
                                                children: [
                                                  // Row 1: Burndown (flex 4) + Status Donut (flex 2), equal height
                                                  if (state.progress != null) ...[
                                                    IntrinsicHeight(
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: [
                                                          Expanded(
                                                            flex: 4,
                                                            child: BurndownChartWidget(
                                                              progress: state.progress!,
                                                              isDark: isDark,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 18),
                                                          Expanded(
                                                            flex: 2,
                                                            child: StatusDistributionWidget(
                                                              state: state,
                                                              isDark: isDark,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 18),
                                                  ] else ...[
                                                    StatusDistributionWidget(
                                                      state: state,
                                                      isDark: isDark,
                                                    ),
                                                    const SizedBox(height: 18),
                                                  ],

                                                  // Row 2: Priority Breakdown Bar + Workload by Assignee, equal height
                                                  IntrinsicHeight(
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                                      children: [
                                                        Expanded(
                                                          child: PriorityBreakdownWidget(
                                                            state: state,
                                                            isDark: isDark,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 18),
                                                        Expanded(
                                                          child: WorkloadByAssigneeWidget(
                                                            state: state,
                                                            isDark: isDark,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 18),

                                                  // Row 3: Attention Required (Full Width)
                                                  RiskIssuesWidget(
                                                    state: state,
                                                    workspaceId: widget.workspaceId,
                                                    projectId: widget.projectId,
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              );
                                            }

                                            // Compact / Mobile stacked layout
                                            return Column(
                                              children: [
                                                if (state.progress != null) ...[
                                                  BurndownChartWidget(
                                                    progress: state.progress!,
                                                    isDark: isDark,
                                                  ),
                                                  const SizedBox(height: 16),
                                                ],
                                                StatusDistributionWidget(
                                                  state: state,
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(height: 16),
                                                PriorityBreakdownWidget(
                                                  state: state,
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(height: 16),
                                                WorkloadByAssigneeWidget(
                                                  state: state,
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(height: 16),
                                                RiskIssuesWidget(
                                                  state: state,
                                                  workspaceId: widget.workspaceId,
                                                  projectId: widget.projectId,
                                                  isDark: isDark,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                    ),
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

  Widget _buildTopToolbar(
    BuildContext context,
    DashboardState state,
    DashboardNotifier notifier,
    bool isDark,
  ) {
    final selectedSprint = state.selectedSprint!;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final borderColor = AppColors.borderFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        final sprintSelector = Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSprint.id,
              isDense: true,
              dropdownColor: AppColors.surfaceFor(isDark),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: AppColors.textMutedFor(isDark)),
              items: state.sprints.map((sprint) {
                final statusColor = sprint.status.colorFor(brightness);
                return DropdownMenuItem<String>(
                  value: sprint.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: Text(
                          sprint.status.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.selectSprint(val);
                }
              },
            ),
          ),
        );

        final actionButtons = Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.timer_outlined, size: 15),
              label: const Text('Sprint Overview'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface2For(isDark),
                foregroundColor: textPrimary,
                side: BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                minimumSize: const Size(0, 34),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
              ),
              onPressed: () {
                context.go(AppRoutes.projectSprintsPath(widget.workspaceId, widget.projectId));
              },
            ),
            AppIconButton(
              icon: Icons.keyboard_outlined,
              tooltip: 'Keyboard shortcuts (?)',
              size: 34,
              backgroundColor: AppColors.surface2For(isDark),
              onPressed: () => KeyboardShortcutsDialog.show(context),
            ),
            AppIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh metrics (R)',
              size: 34,
              backgroundColor: AppColors.surface2For(isDark),
              onPressed: () => notifier.refresh(),
            ),
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WORKSPACE OVERVIEW', style: AppTypography.eyebrow(isDark).copyWith(fontSize: 9)),
              const SizedBox(height: 6),
              sprintSelector,
              const SizedBox(height: 10),
              actionButtons,
            ],
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('WORKSPACE OVERVIEW', style: AppTypography.eyebrow(isDark).copyWith(fontSize: 9)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded, color: accentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Sprint Progress:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                    const SizedBox(width: 10),
                    sprintSelector,
                  ],
                ),
              ],
            ),
            actionButtons,
          ],
        );
      },
    );
  }

  /// Figma `.sprint-banner` gradient hero card summarizing the selected sprint.
  Widget _buildSprintBanner(BuildContext context, DashboardState state, bool isDark) {
    final sprint = state.selectedSprint!;
    final progress = state.progress;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final completed = progress?.completedIssues ?? state.completedTasks;
    final total = progress?.totalIssues ?? state.totalTasks;
    final pct = total > 0 ? (completed / total * 100).round() : 0;
    final memberNames = state.members
        .map((m) => m.user?.fullName.isNotEmpty == true ? m.user!.fullName : (m.user?.email ?? m.userId))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;

        final infoSection = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isCompact) ...[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppColors.radiusXl),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.timer_outlined, color: accentColor, size: 22),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        sprint.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4.5,
                              height: 4.5,
                              decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              sprint.status == SprintStatus.active
                                  ? 'ACTIVE SPRINT'
                                  : sprint.status.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (sprint.goal != null && sprint.goal!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sprint.goal!,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (memberNames.isNotEmpty)
                        UserAvatarGroup(
                          names: memberNames,
                          size: UserAvatarSize.xs,
                          maxVisible: 4,
                        ),
                      Text(
                        '${state.members.length} ${state.members.length == 1 ? 'member' : 'members'} · ${sprint.dateRangeText}',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        final progressSection = SizedBox(
          width: isCompact ? double.infinity : 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Completion', style: TextStyle(fontSize: 11, color: textSecondary)),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0,
                  minHeight: 4.5,
                  backgroundColor: accentColor.withValues(alpha: 0.16),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$completed/$total issues done',
                      style: TextStyle(fontSize: 10.5, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (sprint.daysRemaining != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${sprint.daysRemaining}d left',
                      style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => context.go(AppRoutes.projectBoardPath(widget.workspaceId, widget.projectId)),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open Sprint Board',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: accentColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentSoft.withValues(alpha: isDark ? 0.72 : 0.60),
                AppColors.surfaceFor(isDark),
              ],
              stops: const [0.0, 0.75],
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: Color.lerp(borderColor, accentColor, 0.25) ?? borderColor,
            ),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoSection,
                    const SizedBox(height: 14),
                    progressSection,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: infoSection),
                    const SizedBox(width: 20),
                    progressSection,
                  ],
                ),
        );
      },
    );
  }
}
