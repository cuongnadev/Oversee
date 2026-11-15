import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/features/sprint/application/sprint_overview_provider.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_complete_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:frontend/features/sprint/presentation/widgets/complete_sprint_dialog.dart';
import 'package:frontend/features/sprint/presentation/widgets/create_sprint_dialog.dart';
import 'package:frontend/features/sprint/presentation/widgets/start_sprint_dialog.dart';

/// Sprint overview screen displaying active, planned, and completed sprints with lifecycle actions.
class SprintOverviewScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const SprintOverviewScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<SprintOverviewScreen> createState() => _SprintOverviewScreenState();
}

class _SprintOverviewScreenState extends ConsumerState<SprintOverviewScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sprintOverviewProvider(widget.projectId));
    final notifier = ref.read(sprintOverviewProvider(widget.projectId).notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listen to success or error messages
    ref.listen<SprintOverviewState>(sprintOverviewProvider(widget.projectId), (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        notifier.clearMessages();
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppColors.success,
          ),
        );
        notifier.clearMessages();
      }
    });

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'sprints',
      title: 'Sprint Overview',
      body: Column(
        children: [
          // Project Sub-Navigation Tab Bar
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'sprints',
          ),

          // Main Screen Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.loadOverview(),
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Action Bar
                          _buildTopActionBar(context, state, notifier, isDark),
                          const SizedBox(height: 20),

                          // Active Sprint Section (Hero Card)
                          if (state.statusFilter == null || state.statusFilter == SprintStatus.active)
                            _buildActiveSprintSection(context, state, notifier, isDark),
                          const SizedBox(height: 24),

                          // Planned Sprints Section
                          if (state.statusFilter == null || state.statusFilter == SprintStatus.planned)
                            _buildPlannedSprintsSection(context, state, notifier, isDark),

                          // Completed Sprints Section
                          if (state.statusFilter == null ||
                              state.statusFilter == SprintStatus.completed ||
                              state.statusFilter == SprintStatus.closed) ...[
                            const SizedBox(height: 24),
                            _buildCompletedSprintsSection(context, state, isDark),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionBar(
    BuildContext context,
    SprintOverviewState state,
    SprintOverviewNotifier notifier,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        final filterChips = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterChip('All', state.statusFilter == null, () => notifier.setStatusFilter(null), isDark),
            const SizedBox(width: 6),
            _buildFilterChip('Active', state.statusFilter == SprintStatus.active,
                () => notifier.setStatusFilter(SprintStatus.active), isDark),
            const SizedBox(width: 6),
            _buildFilterChip('Planned', state.statusFilter == SprintStatus.planned,
                () => notifier.setStatusFilter(SprintStatus.planned), isDark),
            const SizedBox(width: 6),
            _buildFilterChip('Completed', state.statusFilter == SprintStatus.completed,
                () => notifier.setStatusFilter(SprintStatus.completed), isDark),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.tune_outlined, size: 16),
              label: const Text('Sprint Planning'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              onPressed: () {
                context.go(AppRoutes.projectSprintPlanningPath(widget.workspaceId, widget.projectId));
              },
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Sprint'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => _openCreateSprintDialog(context, notifier),
            ),
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: filterChips),
              const SizedBox(height: 12),
              actionButtons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            filterChips,
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSprintSection(
    BuildContext context,
    SprintOverviewState state,
    SprintOverviewNotifier notifier,
    bool isDark,
  ) {
    final activeSprint = state.activeSprint;
    final progress = state.activeSprintProgress;

    if (activeSprint == null) {
      if (state.statusFilter == SprintStatus.active) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Column(
            children: [
              Icon(Icons.timer_off_outlined, size: 40, color: isDark ? Colors.white38 : Colors.grey.shade400),
              const SizedBox(height: 10),
              const Text(
                'No Active Sprint',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'There is currently no active sprint. Start a planned sprint below to kick off your iteration.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final issueProgress = progress?.issueProgressPercentage ?? 0.0;
    final pointsProgress = progress?.storyPointProgressPercentage ?? 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt, size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'ACTIVE SPRINT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      activeSprint.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  activeSprint.dateRangeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          // Body Metrics & Progress
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeSprint.goal != null && activeSprint.goal!.isNotEmpty) ...[
                  Text(
                    'Goal: ${activeSprint.goal}',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Two Progress Bars (Issue progress & Story points progress)
                Row(
                  children: [
                    // Issue progress bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Issue Progress',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${progress?.completedIssues ?? 0} / ${progress?.totalIssues ?? 0} (${issueProgress.toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (issueProgress / 100.0).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Story points progress bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Points Progress',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${(progress?.completedStoryPoints ?? 0).toInt()} / ${(progress?.totalStoryPoints ?? 0).toInt()} pts (${pointsProgress.toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (pointsProgress / 100.0).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status Breakdown chips
                if (progress != null && progress.statusBreakdown.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: progress.statusBreakdown.entries.map((entry) {
                      final statusKey = entry.key.toUpperCase();
                      final count = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Text(
                          '$statusKey: $count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons (Complete Sprint & View Board)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.view_kanban_outlined, size: 16),
                      label: const Text('View Board'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () {
                        context.go(AppRoutes.projectBoardPath(widget.workspaceId, widget.projectId));
                      },
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => _openCompleteSprintDialog(context, activeSprint, progress, state, notifier),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 16),
                          SizedBox(width: 6),
                          Text('Complete Sprint'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannedSprintsSection(
    BuildContext context,
    SprintOverviewState state,
    SprintOverviewNotifier notifier,
    bool isDark,
  ) {
    final plannedSprints = state.plannedSprints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Planned Sprints (${plannedSprints.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (plannedSprints.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Center(
              child: Text(
                'No planned sprints yet. Click "New Sprint" to create one.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
          )
        else
          ...plannedSprints.map((sprint) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              sprint.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PLANNED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sprint.dateRangeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        if (sprint.goal != null && sprint.goal!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Goal: ${sprint.goal}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Actions: Plan or Start
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          context.go(AppRoutes.projectSprintPlanningPath(widget.workspaceId, widget.projectId));
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Plan'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _openStartSprintDialog(context, sprint, state.hasActiveSprint, notifier),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, size: 16),
                            SizedBox(width: 4),
                            Text('Start Sprint'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCompletedSprintsSection(
    BuildContext context,
    SprintOverviewState state,
    bool isDark,
  ) {
    final completedSprints = state.completedSprints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'Completed Sprints (${completedSprints.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (completedSprints.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Center(
              child: Text(
                'No completed sprints yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
          )
        else
          ...completedSprints.map((sprint) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sprint.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'COMPLETED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sprint.dateRangeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.done_all, color: AppColors.success, size: 20),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _openStartSprintDialog(
    BuildContext context,
    SprintModel sprint,
    bool hasActiveSprint,
    SprintOverviewNotifier notifier,
  ) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => StartSprintDialog(
        sprint: sprint,
        hasOtherActiveSprint: hasActiveSprint,
        onStart: ({startDate, endDate}) => notifier.startSprint(
          sprint.id,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
  }

  void _openCompleteSprintDialog(
    BuildContext context,
    SprintModel sprint,
    SprintProgressModel? progress,
    SprintOverviewState state,
    SprintOverviewNotifier notifier,
  ) {
    showDialog<SprintCompleteModel>(
      context: context,
      builder: (ctx) => CompleteSprintDialog(
        sprint: sprint,
        progress: progress,
        plannedSprints: state.plannedSprints,
        onComplete: ({targetSprintId}) => notifier.completeSprint(
          sprint.id,
          targetSprintId: targetSprintId,
        ),
      ),
    );
  }

  void _openCreateSprintDialog(
    BuildContext context,
    SprintOverviewNotifier notifier,
  ) {
    CreateSprintDialog.show(
      context,
      onSubmit: ({
        required String name,
        String? goal,
        DateTime? startDate,
        DateTime? endDate,
        double? capacity,
      }) async {
        try {
          await ref.read(sprintRepositoryProvider).createSprint(
            widget.projectId,
            name: name,
            goal: goal,
            startDate: startDate,
            endDate: endDate,
            capacity: capacity,
          );
          await notifier.loadOverview();
          return true;
        } catch (_) {
          return false;
        }
      },
    );
  }
}
