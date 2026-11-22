import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';
import 'package:frontend/features/sprint/application/kanban_board_state.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_complete_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:frontend/features/sprint/presentation/widgets/complete_sprint_dialog.dart';
import 'package:frontend/features/sprint/presentation/widgets/kanban_column_widget.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Screen displaying the multi-column Kanban board aligned with Figma Board.
class KanbanBoardScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const KanbanBoardScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends ConsumerState<KanbanBoardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final queryParams = GoRouterState.of(context).uri.queryParameters;
        if (queryParams.isNotEmpty) {
          ref
              .read(kanbanBoardProvider(widget.projectId).notifier)
              .initFilterFromParams(queryParams);
        }
      } catch (_) {
        // Router state may not be ready in isolated widget test environments
      }
    });
  }

  void _updateUrlWithFilters(IssueFilterState filter) {
    try {
      final queryParams = filter.toQueryParams();
      final uri = Uri(
        path: AppRoutes.projectBoardPath(widget.workspaceId, widget.projectId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      context.go(uri.toString());
    } catch (_) {
      // In tests without full router integration
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final state = ref.watch(kanbanBoardProvider(widget.projectId));
    final notifier = ref.read(kanbanBoardProvider(widget.projectId).notifier);

    ref.listen(kanbanBoardProvider(widget.projectId), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    next.errorMessage!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.errorFor(isDark),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(kanbanBoardProvider(widget.projectId).notifier).clearErrorMessage();
      }
    });

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'board',
      title: 'Kanban Board',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'board',
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: state.isLoading
                  ? const KanbanBoardSkeleton()
                  : !state.hasActiveSprint
                      ? _buildNoActiveSprintEmptyState(context)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Reusable Filter & Sorting Toolbar (Figma .work-toolbar)
                            BoardFilterToolbar(
                              filter: state.filter,
                              members: state.members,
                              currentUserId: state.currentUserId,
                              onFilterChanged: (newFilter) {
                                notifier.setFilter(newFilter);
                                _updateUrlWithFilters(newFilter);
                              },
                            ),

                            // Board Heading Bar (Figma .board-heading)
                            _buildSprintHeader(context, state, notifier, isDark),

                            // Multi-column Kanban Board View
                            Expanded(
                              child: _buildColumnsView(context, state, notifier),
                            ),

                            // Subtle Board Hint Footer (Figma .board-hint)
                            if (!isMobile) _buildBoardHintFooter(isDark),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveSprintEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AppEmptyState(
          icon: Icons.timer_off_outlined,
          title: 'No Active Sprint',
          description:
              'There is currently no active sprint for this project. Start or plan a sprint to manage your tasks on this Kanban board.',
          action: AppPrimaryButton(
            label: 'Go to Sprint Planning',
            icon: Icons.timer_outlined,
            onPressed: () {
              context.go(AppRoutes.projectSprintsPath(widget.workspaceId, widget.projectId));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSprintHeader(
    BuildContext context,
    KanbanBoardState state,
    KanbanBoardNotifier notifier,
    bool isDark,
  ) {
    final sprint = state.activeSprint!;
    final totalIssues = state.totalIssues;
    final totalStoryPoints = state.totalStoryPoints;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final greenSoft = AppColors.greenSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final memberNames = state.members
        .map((m) => m.user?.fullName.isNotEmpty == true ? m.user!.fullName : (m.user?.email ?? m.userId))
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      color: AppColors.bgFor(isDark),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Left: Sprint Name, ACTIVE Badge, Date Range
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    sprint.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: accentSoft,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(color: accentColor.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sprint.daysRemaining != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.surface3For(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Text(
                        '${sprint.daysRemaining}d left',
                        style: AppTypography.mono(
                          isDark,
                          fontSize: 10.5,
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                sprint.dateRangeText,
                style: TextStyle(fontSize: 11.5, color: textMuted),
              ),
            ],
          ),

          // Right: Team avatars, Metrics badges, Complete Sprint, Refresh
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (memberNames.isNotEmpty) ...[
                UserAvatarGroup(
                  names: memberNames,
                  size: UserAvatarSize.xs,
                  maxVisible: 4,
                ),
                const SizedBox(width: 2),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface2For(isDark),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: AppColors.borderFor(isDark)),
                ),
                child: Text(
                  '$totalIssues issues',
                  style: AppTypography.mono(
                    isDark,
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: Text(
                  totalStoryPoints % 1 == 0
                      ? '${totalStoryPoints.toInt()} pts'
                      : '$totalStoryPoints pts',
                  style: AppTypography.mono(
                    isDark,
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.check_circle_outline_rounded, size: 15, color: successColor),
                label: Text(
                  'Complete Sprint',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: successColor),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenSoft,
                  foregroundColor: successColor,
                  elevation: 0,
                  side: BorderSide(color: successColor.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                ),
                onPressed: () => _openCompleteSprintDialog(context, sprint, state, notifier),
              ),
              AppIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh board',
                size: 32,
                backgroundColor: AppColors.surface2For(isDark),
                onPressed: () => notifier.refresh(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumnsView(
    BuildContext context,
    KanbanBoardState state,
    KanbanBoardNotifier notifier,
  ) {
    const columns = [
      IssueStatus.todo,
      IssueStatus.inProgress,
      IssueStatus.inReview,
      IssueStatus.done,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 30),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columns.map((status) {
                final statusIssues = state.issuesForStatus(status);
                final statusStoryPoints = state.storyPointsForStatus(status);

                return KanbanColumnWidget(
                  status: status,
                  issues: statusIssues,
                  totalStoryPoints: statusStoryPoints,
                  projectKey: state.projectKey,
                  onIssueDropped: (issue) {
                    notifier.updateIssueStatus(issue.id, status);
                  },
                  onCardUpdated: () {
                    notifier.refresh();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardHintFooter(bool isDark) {
    final textMuted = AppColors.textMutedFor(isDark);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppColors.bgFor(isDark),
        border: Border(top: BorderSide(color: AppColors.borderSoftFor(isDark))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Drag and drop issue cards across columns to update workflow status',
            style: TextStyle(fontSize: 10.5, color: textMuted),
          ),
          Text(
            'Click any card to inspect details',
            style: TextStyle(fontSize: 10.5, color: textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _openCompleteSprintDialog(
    BuildContext context,
    SprintModel sprint,
    KanbanBoardState state,
    KanbanBoardNotifier notifier,
  ) async {
    final sprintRepo = ref.read(sprintRepositoryProvider);
    List<SprintModel> plannedSprints = [];
    SprintProgressModel? progress;

    try {
      final results = await Future.wait([
        sprintRepo.listProjectSprints(widget.projectId, status: SprintStatus.planned),
        sprintRepo.getSprintProgress(sprint.id),
      ]);
      plannedSprints = results[0] as List<SprintModel>;
      progress = results[1] as SprintProgressModel;
    } catch (_) {
      final completed = state.issuesForStatus(IssueStatus.done).length;
      final total = state.totalIssues;
      progress = SprintProgressModel(
        sprintId: sprint.id,
        sprintName: sprint.name,
        status: sprint.status,
        totalIssues: total,
        completedIssues: completed,
        remainingIssues: total - completed,
        issueProgressPercentage: total > 0 ? (completed / total * 100) : 0,
        totalStoryPoints: state.totalStoryPoints,
        completedStoryPoints: state.storyPointsForStatus(IssueStatus.done),
        remainingStoryPoints: state.totalStoryPoints - state.storyPointsForStatus(IssueStatus.done),
        storyPointProgressPercentage: 0,
      );
    }

    if (!context.mounted) return;

    final result = await showDialog<SprintCompleteModel>(
      context: context,
      builder: (ctx) => CompleteSprintDialog(
        sprint: sprint,
        progress: progress,
        plannedSprints: plannedSprints,
        onComplete: ({targetSprintId}) async {
          return await sprintRepo.completeSprint(
            sprint.id,
            targetSprintId: targetSprintId,
          );
        },
      ),
    );

    if (result != null && context.mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sprint "${sprint.name}" completed successfully!'),
          backgroundColor: AppColors.successFor(isDark),
        ),
      );
      await notifier.refresh();
    }
  }
}
