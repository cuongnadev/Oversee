import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
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

/// Sprint overview screen aligned with Figma Sprints view.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<SprintOverviewState>(sprintOverviewProvider(widget.projectId), (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.errorFor(isDark),
          ),
        );
        notifier.clearMessages();
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppColors.successFor(isDark),
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
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'sprints',
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.loadOverview(),
              child: state.isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.accentFor(isDark)))
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopActionBar(context, state, notifier, isDark),
                          const SizedBox(height: 18),

                          if (state.statusFilter == null || state.statusFilter == SprintStatus.active)
                            _buildActiveSprintSection(context, state, notifier, isDark),
                          const SizedBox(height: 22),

                          if (state.statusFilter == null || state.statusFilter == SprintStatus.planned)
                            _buildPlannedSprintsSection(context, state, notifier, isDark),

                          if (state.statusFilter == null ||
                              state.statusFilter == SprintStatus.completed ||
                              state.statusFilter == SprintStatus.closed) ...[
                            const SizedBox(height: 22),
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
              icon: const Icon(Icons.tune_outlined, size: 15),
              label: const Text('Sprint Planning'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface2For(isDark),
                foregroundColor: AppColors.textPrimaryFor(isDark),
                side: BorderSide(color: AppColors.borderFor(isDark)),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
              ),
              onPressed: () {
                context.go(AppRoutes.projectSprintPlanningPath(widget.workspaceId, widget.projectId));
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Sprint'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentSolidFor(isDark),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
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
    final accentColor = AppColors.accentFor(isDark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSoftFor(isDark) : AppColors.surface2For(isDark),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: isSelected ? accentColor.withValues(alpha: 0.45) : AppColors.borderFor(isDark),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? accentColor : AppColors.textSecondaryFor(isDark),
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
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final borderColor = AppColors.borderFor(isDark);

    if (activeSprint == null) {
      if (state.statusFilter == SprintStatus.active) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Icon(Icons.timer_off_outlined, size: 36, color: AppColors.textMutedFor(isDark)),
              const SizedBox(height: 10),
              Text(
                'No Active Sprint',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryFor(isDark)),
              ),
              const SizedBox(height: 4),
              Text(
                'There is currently no active sprint. Start a planned sprint below to kick off your iteration.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryFor(isDark)),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentSoft.withValues(alpha: isDark ? 0.65 : 0.55),
            AppColors.surfaceFor(isDark),
          ],
          stops: const [0.0, 0.72],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.8))),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: Border.all(color: accentColor.withValues(alpha: 0.32)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 13, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'ACTIVE SPRINT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      activeSprint.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryFor(isDark),
                      ),
                    ),
                  ],
                ),
                Text(
                  activeSprint.dateRangeText,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(isDark)),
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
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(isDark)),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Issue Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondaryFor(isDark),
                                ),
                              ),
                              Text(
                                '${progress?.completedIssues ?? 0} / ${progress?.totalIssues ?? 0} (${issueProgress.toStringAsFixed(0)}%)',
                                style: AppTypography.mono(
                                  isDark,
                                  fontSize: 11.5,
                                  color: AppColors.textPrimaryFor(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (issueProgress / 100.0).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: AppColors.surface3For(isDark),
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Points Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondaryFor(isDark),
                                ),
                              ),
                              Text(
                                '${(progress?.completedStoryPoints ?? 0).toInt()} / ${(progress?.totalStoryPoints ?? 0).toInt()} pts (${pointsProgress.toStringAsFixed(0)}%)',
                                style: AppTypography.mono(
                                  isDark,
                                  fontSize: 11.5,
                                  color: AppColors.textPrimaryFor(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (pointsProgress / 100.0).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: AppColors.surface3For(isDark),
                              valueColor: AlwaysStoppedAnimation<Color>(successColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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
                          color: AppColors.surface2For(isDark),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          '$statusKey: $count',
                          style: AppTypography.mono(
                            isDark,
                            fontSize: 10.5,
                            color: AppColors.textSecondaryFor(isDark),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.view_kanban_outlined, size: 15),
                      label: const Text('View Board'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface2For(isDark),
                        foregroundColor: AppColors.textPrimaryFor(isDark),
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
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
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                      ),
                      onPressed: () => _openCompleteSprintDialog(context, activeSprint, progress, state, notifier),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 16),
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
    final borderColor = AppColors.borderFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 17, color: AppColors.accentFor(isDark)),
            const SizedBox(width: 8),
            Text(
              'Planned Sprints (${plannedSprints.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryFor(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (plannedSprints.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(isDark),
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Text(
                'No planned sprints yet. Click "New Sprint" to create one.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryFor(isDark)),
              ),
            ),
          )
        else
          ...plannedSprints.map((sprint) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.surface3For(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: Icon(Icons.track_changes_rounded, size: 17, color: AppColors.textSecondaryFor(isDark)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              sprint.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryFor(isDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface3For(isDark),
                                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                              ),
                              child: Text(
                                'PLANNED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondaryFor(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sprint.dateRangeText,
                          style: TextStyle(fontSize: 11.5, color: AppColors.textMutedFor(isDark)),
                        ),
                        if (sprint.goal != null && sprint.goal!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Goal: ${sprint.goal}',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(isDark)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          context.go(AppRoutes.projectSprintPlanningPath(widget.workspaceId, widget.projectId));
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surface2For(isDark),
                          foregroundColor: AppColors.textPrimaryFor(isDark),
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                        ),
                        child: const Text('Plan'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentSolidFor(isDark),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                        ),
                        onPressed: () => _openStartSprintDialog(context, sprint, state.hasActiveSprint, notifier),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 16),
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
    final successColor = AppColors.successFor(isDark);
    final greenSoft = AppColors.greenSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 17, color: successColor),
            const SizedBox(width: 8),
            Text(
              'Completed Sprints (${completedSprints.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryFor(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (completedSprints.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(isDark),
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Text(
                'No completed sprints yet.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryFor(isDark)),
              ),
            ),
          )
        else
          ...completedSprints.map((sprint) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: greenSoft,
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        ),
                        child: Icon(Icons.done_all_rounded, color: successColor, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                sprint.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryFor(isDark),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: greenSoft,
                                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                  border: Border.all(color: successColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'COMPLETED',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: successColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sprint.dateRangeText,
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMutedFor(isDark)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(Icons.check_circle_rounded, color: successColor, size: 18),
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

  void _openCreateSprintDialog(BuildContext context, SprintOverviewNotifier notifier) {
    final sprintRepo = ref.read(sprintRepositoryProvider);
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
          await sprintRepo.createSprint(
            widget.projectId,
            name: name,
            goal: goal,
            startDate: startDate,
            endDate: endDate,
            capacity: capacity,
          );
          await notifier.loadOverview();
          return true;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create sprint: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return false;
        }
      },
    );
  }
}
