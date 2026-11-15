import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';
import 'package:frontend/features/sprint/application/kanban_board_state.dart';
import 'package:frontend/features/sprint/presentation/widgets/kanban_column_widget.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Screen displaying the multi-column Kanban board for the active sprint.
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
    final state = ref.watch(kanbanBoardProvider(widget.projectId));
    final notifier = ref.read(kanbanBoardProvider(widget.projectId).notifier);

    // Listen to error messages and present a floating SnackBar
    ref.listen(kanbanBoardProvider(widget.projectId), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    next.errorMessage!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
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
          // Project Sub-Navigation Tab Bar
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'board',
          ),

          // Main Board Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !state.hasActiveSprint
                      ? _buildNoActiveSprintEmptyState(context)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sprint Header Bar
                            _buildSprintHeader(context, state, notifier, isDark),

                            // Reusable Filter & Sorting Toolbar
                            BoardFilterToolbar(
                              filter: state.filter,
                              members: state.members,
                              currentUserId: state.currentUserId,
                              onFilterChanged: (newFilter) {
                                notifier.setFilter(newFilter);
                                _updateUrlWithFilters(newFilter);
                              },
                            ),

                            // Multi-column Kanban Board View
                            Expanded(
                              child: _buildColumnsView(context, state, notifier),
                            ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Left: Sprint Name & Status Badge & Duration
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sprint.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.success.withAlpha(80),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Date text
              Text(
                sprint.dateRangeText,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              if (sprint.daysRemaining != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${sprint.daysRemaining}d left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Right: Metrics badges, Refresh
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Issues Count Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalIssues issues',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Total Story Points Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  totalStoryPoints % 1 == 0
                      ? '${totalStoryPoints.toInt()} pts'
                      : '$totalStoryPoints pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.secondaryLight : AppColors.secondaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh board',
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
    // 4 standard Kanban workflow columns
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 28),
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
}
