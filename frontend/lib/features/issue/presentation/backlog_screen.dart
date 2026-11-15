import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/application/backlog_state.dart';
import 'package:frontend/features/issue/domain/issue_filter_state.dart';
import 'package:frontend/features/issue/presentation/widgets/backlog_item_card.dart';
import 'package:frontend/features/issue/presentation/widgets/board_filter_toolbar.dart';
import 'package:frontend/features/issue/presentation/widgets/quick_create_issue_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Product Backlog Screen supporting hierarchical listing, quick creation, filtering, and drag-and-drop reordering.
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Backlog Header Metrics & Title
                    _buildHeaderToolbar(context, state, notifier),
                    const SizedBox(height: 10.0),

                    // Unified Filter & Sort Toolbar
                    BoardFilterToolbar(
                      filter: state.filter,
                      members: state.members,
                      currentUserId: state.currentUserId,
                      onFilterChanged: (newFilter) {
                        notifier.setFilter(newFilter);
                        _updateUrlWithFilters(newFilter);
                      },
                    ),
                    const SizedBox(height: 12.0),

                    // Quick Create Issue Bar
                    QuickCreateIssueBar(projectId: widget.projectId),
                    const SizedBox(height: 14.0),

                    // Reorderable Backlog List View
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
                              ),
                            );
                          }

                          return ReorderableListView.builder(
                            itemCount: issues.length,
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) {
                              notifier.reorderBacklog(oldIndex, newIndex);
                            },
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                elevation: 4.0,
                                shadowColor: Colors.black26,
                                borderRadius: BorderRadius.circular(8.0),
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final issue = issues[index];
                              return Padding(
                                key: ValueKey('backlog_item_${issue.id}'),
                                padding: const EdgeInsets.only(bottom: 8.0),
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

  Widget _buildHeaderToolbar(BuildContext context, BacklogState state, BacklogNotifier notifier) {
    final theme = Theme.of(context);
    final count = state.filteredIssues.length;
    final totalPoints = state.totalStoryPoints;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12.0,
      runSpacing: 8.0,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Backlog',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                '$count issues',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(30),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                totalPoints % 1 == 0 ? '${totalPoints.toInt()} SP' : '$totalPoints SP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh backlog',
              onPressed: () => notifier.refresh(),
            ),
          ],
        ),
      ],
    );
  }
}
