import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/application/backlog_state.dart';
import 'package:frontend/features/issue/presentation/widgets/backlog_item_card.dart';
import 'package:frontend/features/issue/presentation/widgets/quick_create_issue_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Product Backlog Screen supporting hierarchical listing, quick creation, and drag-and-drop reordering.
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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Toolbar Header
                    _buildHeaderToolbar(context, state, notifier),
                    const SizedBox(height: 14.0),
                    // Filter Chips Row
                    _buildFilterChipsRow(context, state, notifier),
                    const SizedBox(height: 14.0),
                    // Quick Create Issue Bar
                    QuickCreateIssueBar(projectId: widget.projectId),
                    const SizedBox(height: 16.0),
                    // Reorderable Backlog List View
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (state.isLoading) {
                            return const Center(child: AppLoadingIndicator(size: 36.0));
                          }

                          if (state.errorMessage != null && state.issues.isEmpty) {
                            return Center(
                              child: AppEmptyState(
                                icon: Icons.error_outline,
                                title: 'Failed to load backlog',
                                description: state.errorMessage,
                                action: AppPrimaryButton(
                                  label: 'Retry',
                                  icon: Icons.refresh,
                                  onPressed: () => notifier.loadBacklog(),
                                ),
                              ),
                            );
                          }

                          final issues = state.filteredIssues;
                          if (issues.isEmpty) {
                            return Center(
                              child: AppEmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: state.searchQuery.isNotEmpty || state.selectedType != null || state.selectedPriority != null
                                    ? 'No matching backlog issues'
                                    : 'Your Product Backlog is empty',
                                description: state.searchQuery.isNotEmpty
                                    ? 'Try adjusting your search terms or filters.'
                                    : 'Quickly create issues using the input bar above to start planning.',
                              ),
                            );
                          }

                          return ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: issues.length,
                            onReorder: (oldIndex, newIndex) {
                              notifier.reorderBacklog(oldIndex, newIndex);
                            },
                            proxyDecorator: (child, index, animation) {
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, _) {
                                  return Material(
                                    elevation: 6.0,
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: child,
                                  );
                                },
                              );
                            },
                            itemBuilder: (context, index) {
                              final issue = issues[index];
                              return BacklogItemCard(
                                key: ValueKey(issue.id),
                                projectId: widget.projectId,
                                projectKey: projectKey,
                                issue: issue,
                                index: index,
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

    return Wrap(
      spacing: 12.0,
      runSpacing: 10.0,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Product Backlog',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                '${state.filteredIssues.length} issues',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                '${state.totalStoryPoints.toStringAsFixed(state.totalStoryPoints.truncateToDouble() == state.totalStoryPoints ? 0 : 1)} SP',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search issues...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        notifier.setSearchQuery('');
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            onChanged: (val) {
              notifier.setSearchQuery(val);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChipsRow(BuildContext context, BacklogState state, BacklogNotifier notifier) {
    final bool hasActiveFilters = state.selectedType != null || state.selectedPriority != null || state.searchQuery.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Type filter dropdown
          PopupMenuButton<IssueType?>(
            tooltip: 'Filter by Type',
            initialValue: state.selectedType,
            onSelected: (t) => notifier.setTypeFilter(t),
            child: Chip(
              avatar: Icon(
                state.selectedType?.icon ?? Icons.category_outlined,
                size: 16,
                color: state.selectedType?.color,
              ),
              label: Text(
                state.selectedType != null ? state.selectedType!.label : 'Type: All',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            itemBuilder: (context) {
              return [
                const PopupMenuItem<IssueType?>(
                  value: null,
                  child: Text('All Types'),
                ),
                ...IssueType.values.map((t) {
                  return PopupMenuItem<IssueType?>(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 16, color: t.color),
                        const SizedBox(width: 8.0),
                        Text(t.label),
                      ],
                    ),
                  );
                }),
              ];
            },
          ),
          const SizedBox(width: 8.0),
          // Priority filter dropdown
          PopupMenuButton<IssuePriority?>(
            tooltip: 'Filter by Priority',
            initialValue: state.selectedPriority,
            onSelected: (p) => notifier.setPriorityFilter(p),
            child: Chip(
              avatar: Icon(
                state.selectedPriority?.icon ?? Icons.flag_outlined,
                size: 16,
                color: state.selectedPriority?.color,
              ),
              label: Text(
                state.selectedPriority != null ? state.selectedPriority!.label : 'Priority: All',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            itemBuilder: (context) {
              return [
                const PopupMenuItem<IssuePriority?>(
                  value: null,
                  child: Text('All Priorities'),
                ),
                ...IssuePriority.values.map((p) {
                  return PopupMenuItem<IssuePriority?>(
                    value: p,
                    child: Row(
                      children: [
                        Icon(p.icon, size: 16, color: p.color),
                        const SizedBox(width: 8.0),
                        Text(p.label),
                      ],
                    ),
                  );
                }),
              ];
            },
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 8.0),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                notifier.clearFilters();
                setState(() {});
              },
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Clear Filters', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
