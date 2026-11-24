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

/// Screen displaying the multi-column Kanban board aligned with Figma Board Page (node 6:2).
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
  BoardSavedView _activeSavedView = BoardSavedView.all;
  final ScrollController _horizontalController = ScrollController();

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

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
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

  void _handleSavedViewChanged(
    BoardSavedView view,
    KanbanBoardState state,
    KanbanBoardNotifier notifier,
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

  Future<void> _openQuickCreateIssue(
    KanbanBoardNotifier notifier, {
    IssueStatus? initialStatus,
    String? initialSprintId,
  }) async {
    final created = await QuickCreateDialog.show(
      context,
      projectId: widget.projectId,
      initialType: QuickCreateEntityType.issue,
      initialStatus: initialStatus,
      initialSprintId: initialSprintId,
    );
    if (created == true && mounted) {
      await notifier.refresh();
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

    return AppKeyboardShortcuts(
      onRefresh: () => notifier.refresh(),
      onNewIssue: () => _openQuickCreateIssue(notifier),
      child: ProjectScreenScaffold(
        workspaceId: widget.workspaceId,
        projectId: widget.projectId,
        currentRoute: 'board',
        title: 'Board',
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
                              // WorkToolbar (Figma node 6:381: Saved Views + Filter/Search Row)
                              BoardFilterToolbar(
                                filter: state.filter,
                                members: state.members,
                                currentUserId: state.currentUserId,
                                totalCount: state.totalIssues,
                                activeSavedView: _activeSavedView,
                                workspaceId: widget.workspaceId,
                                projectId: widget.projectId,
                                activeView: 'board',
                                onSavedViewChanged: (view) =>
                                    _handleSavedViewChanged(view, state, notifier),
                                onFilterChanged: (newFilter) {
                                  if (newFilter.selectedAssigneeId != 'me' &&
                                      _activeSavedView == BoardSavedView.mine) {
                                    setState(() => _activeSavedView = BoardSavedView.all);
                                  }
                                  notifier.setFilter(newFilter);
                                  _updateUrlWithFilters(newFilter);
                                },
                              ),

                              // Board Heading Bar (Figma node 6:516)
                              _buildSprintHeader(context, state, notifier, isDark),

                              // Smooth Multi-column Kanban Board View (Figma node 6:565)
                              Expanded(
                                child: _buildColumnsView(context, state, notifier),
                              ),

                              // Figma Board Footer Hint Bar (node 6:1650)
                              if (!isMobile) _buildBoardHintFooter(isDark),
                            ],
                          ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      color: AppColors.bgFor(isDark),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Left (Figma 6:517): Board + Sprint Name + ACTIVE badge + Subtitle
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
                    'Board',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                      color: textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: accentSoft,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: Text(
                      sprint.name,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentSoft,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(color: accentColor.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4.5),
                        Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sprint.daysRemaining != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface3For(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Text(
                        '${sprint.daysRemaining}d left',
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
              const SizedBox(height: 4),
              Text(
                'From plan to done. Moving forward together · ${sprint.dateRangeText}',
                style: TextStyle(fontSize: 11.5, color: textMuted),
              ),
            ],
          ),

          // Right (Figma 6:528): Member avatars + count, issues/pts pills, Complete Sprint, Refresh
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
                Text(
                  '${state.members.length} ${state.members.length == 1 ? 'member' : 'members'}',
                  style: TextStyle(fontSize: 11, color: textSecondary),
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
                    fontSize: 10.5,
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
                    fontSize: 10.5,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.check_circle_outline_rounded, size: 14.5, color: successColor),
                label: Text(
                  'Complete Sprint',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: successColor),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenSoft,
                  foregroundColor: successColor,
                  elevation: 0,
                  side: BorderSide(color: successColor.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                ),
                onPressed: () => _openCompleteSprintDialog(context, sprint, state, notifier),
              ),
              AppIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh board',
                size: 30,
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
    final columns = _activeSavedView == BoardSavedView.open
        ? const [
            IssueStatus.todo,
            IssueStatus.inProgress,
            IssueStatus.inReview,
          ]
        : const [
            IssueStatus.todo,
            IssueStatus.inProgress,
            IssueStatus.inReview,
            IssueStatus.done,
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 36;
        final computedWidth =
            ((availableWidth - (columns.length * 12)) / columns.length).clamp(288.0, 360.0);

        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: false,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: availableWidth > 0 ? availableWidth : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: columns.map((status) {
                  final statusIssues = state.issuesForStatus(status);
                  final statusStoryPoints = state.storyPointsForStatus(status);

                  return KanbanColumnWidget(
                    key: ValueKey('col-${status.value}'),
                    status: status,
                    issues: statusIssues,
                    totalStoryPoints: statusStoryPoints,
                    projectKey: state.projectKey,
                    width: computedWidth,
                    onIssueDropped: (issue) {
                      notifier.updateIssueStatus(issue.id, status);
                    },
                    onAddIssue: () => _openQuickCreateIssue(
                      notifier,
                      initialStatus: status,
                      initialSprintId: state.activeSprint?.id,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardHintFooter(bool isDark) {
    final textMuted = AppColors.textMutedFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final surface2 = AppColors.surface2For(isDark);

    Widget kbd(String keyLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          keyLabel,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: textMuted),
        ),
      );
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.bgFor(isDark),
        border: Border(top: BorderSide(color: AppColors.borderSoftFor(isDark))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Drag issues across columns to update status',
              style: TextStyle(fontSize: 10, color: textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              kbd('C'),
              const SizedBox(width: 5),
              Text('create issue', style: TextStyle(fontSize: 10, color: textMuted)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Text('·', style: TextStyle(fontSize: 10, color: textMuted)),
              ),
              kbd('⌘ K'),
              const SizedBox(width: 5),
              Text('quick search', style: TextStyle(fontSize: 10, color: textMuted)),
            ],
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

    final result = await showAnimatedDialog<SprintCompleteModel>(
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
