import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
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

/// Project Progress Dashboard screen with interactive Burndown Chart and velocity metrics.
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
          // Project Sub-Navigation Tab Bar
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'dashboard',
          ),

          // Main Dashboard Body
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
                                context.go(AppRoutes.projectSprintPlanningPath(widget.workspaceId, widget.projectId));
                              },
                            )
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Toolbar with Sprint Selector
                                  _buildTopToolbar(context, state, notifier, isDark),
                                  const SizedBox(height: 18),

                                  // KPI Metric Summary Cards
                                  ProgressSummaryCards(state: state, isDark: isDark),
                                  const SizedBox(height: 20),

                                  // Interactive Burndown Chart
                                  if (state.progress != null) ...[
                                    BurndownChartWidget(
                                      progress: state.progress!,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // Responsive 2-Column Statistics & Workload Grid
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isWide = constraints.maxWidth >= 900;

                                      if (isWide) {
                                        return Column(
                                          children: [
                                            // Row 1: Status Distribution (Donut) + Priority Breakdown (Bar)
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: StatusDistributionWidget(
                                                    state: state,
                                                    isDark: isDark,
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                  child: PriorityBreakdownWidget(
                                                    state: state,
                                                    isDark: isDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),

                                            // Row 2: Workload by Assignee + Attention Required (Risks)
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: WorkloadByAssigneeWidget(
                                                    state: state,
                                                    isDark: isDark,
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                  child: RiskIssuesWidget(
                                                    state: state,
                                                    workspaceId: widget.workspaceId,
                                                    projectId: widget.projectId,
                                                    isDark: isDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      }

                                      // Narrow / Mobile Layout
                                      return Column(
                                        children: [
                                          StatusDistributionWidget(
                                            state: state,
                                            isDark: isDark,
                                          ),
                                          const SizedBox(height: 20),
                                          PriorityBreakdownWidget(
                                            state: state,
                                            isDark: isDark,
                                          ),
                                          const SizedBox(height: 20),
                                          WorkloadByAssigneeWidget(
                                            state: state,
                                            isDark: isDark,
                                          ),
                                          const SizedBox(height: 20),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        final sprintSelector = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSprint.id,
              isDense: true,
              dropdownColor: isDark ? AppColors.cardDark : Colors.white,
              items: state.sprints.map((sprint) {
                return DropdownMenuItem<String>(
                  value: sprint.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sprint.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: sprint.status.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sprint.status.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: sprint.status.color,
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
              icon: const Icon(Icons.timer_outlined, size: 16),
              label: const Text('Sprint Overview'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              onPressed: () {
                context.go(AppRoutes.projectSprintsPath(widget.workspaceId, widget.projectId));
              },
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_outlined, size: 20),
              tooltip: 'Keyboard shortcuts (?)',
              onPressed: () => KeyboardShortcutsDialog.show(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh metrics (R)',
              onPressed: () => notifier.refresh(),
            ),
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Sprint Progress:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                sprintSelector,
              ],
            ),
            actionButtons,
          ],
        );
      },
    );
  }
}
