import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/application/backlog_state.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/presentation/widgets/backlog_item_card.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';
import 'package:frontend/features/issue/presentation/widgets/quick_create_issue_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Product Backlog Screen aligned with Figma Backlog view.
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(backlogNotifierProvider(widget.projectId));
    final notifier = ref.read(backlogNotifierProvider(widget.projectId).notifier);
    final projectKey = state.project?.key ?? 'PROJ';

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

          // Unified Filter & Sort Toolbar (Figma .work-toolbar edge-to-edge)
          BoardFilterToolbar(
            filter: state.filter,
            members: state.members,
            currentUserId: state.currentUserId,
            onFilterChanged: (newFilter) {
              notifier.setFilter(newFilter);
              _updateUrlWithFilters(newFilter);
            },
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22.0, 18.0, 22.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Page Heading & Metrics (Figma .page-heading)
                    _buildHeaderToolbar(context, state, notifier, isDark),
                    const SizedBox(height: 14.0),

                    // Quick Create Issue Bar
                    QuickCreateIssueBar(projectId: widget.projectId),
                    const SizedBox(height: 14.0),

                    // Reorderable Backlog List Panel
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (state.isLoading) {
                            return const BacklogSkeleton();
                          }

                          if (state.errorMessage != null && state.issues.isEmpty) {
                            return AppErrorView(
                              error: state.errorMessage,
                              onRetry: () => notifier.loadBacklog(),
                            );
                          }

                          final issues = state.filteredIssues;
                          if (issues.isEmpty) {
                            return Center(
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
                            );
                          }

                          return ReorderableListView.builder(
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
                                child: BacklogItemCard(
                                  index: index,
                                  issue: issue,
                                  projectKey: projectKey,
                                  projectId: widget.projectId,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderToolbar(
    BuildContext context,
    BacklogState state,
    BacklogNotifier notifier,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final count = state.filteredIssues.length;
    final totalPoints = state.totalStoryPoints;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12.0,
      runSpacing: 8.0,
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
                    fontSize: 22.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    color: AppColors.textPrimaryFor(isDark),
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
                    '$count issues',
                    style: AppTypography.mono(
                      isDark,
                      fontSize: 10.5,
                      color: AppColors.textSecondaryFor(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Text(
                    totalPoints % 1 == 0 ? '${totalPoints.toInt()} SP' : '$totalPoints SP',
                    style: AppTypography.mono(
                      isDark,
                      fontSize: 10.5,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3.0),
            Text(
              'Plan, prioritize, and organize work for upcoming sprints.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryFor(isDark),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh backlog',
              size: 32.0,
              backgroundColor: AppColors.surface2For(isDark),
              onPressed: () => notifier.refresh(),
            ),
          ],
        ),
      ],
    );
  }
}
