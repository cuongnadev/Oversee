import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';
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
  final _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(kanbanBoardProvider(widget.projectId));
    final notifier = ref.read(kanbanBoardProvider(widget.projectId).notifier);

    // Listen to error messages and present a SnackBar
    ref.listen(kanbanBoardProvider(widget.projectId), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
                            // Sprint Header & Toolbar
                            _buildHeaderToolbar(context, state, notifier, isDark),

                            // Optional Filter Chips Row
                            if (_showFilters)
                              _buildFilterChipsRow(context, state, notifier, isDark),

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
          actionText: 'Go to Sprint Planning',
          onActionPressed: () {
            context.go(AppRoutes.projectSprintsPath(widget.workspaceId, widget.projectId));
          },
        ),
      ),
    );
  }

  Widget _buildHeaderToolbar(
    BuildContext context,
    dynamic state,
    dynamic notifier,
    bool isDark,
  ) {
    final sprint = state.activeSprint;
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

          // Right: Metrics badges, Search Bar, Filters Toggle, Refresh
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
              const SizedBox(width: 10),

              // Search Bar
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => notifier.setSearchQuery(val),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search board...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                notifier.setSearchQuery('');
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      filled: true,
                      fillColor: isDark ? AppColors.cardDark : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Filter Toggle Button
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 20,
                  color: state.hasActiveFilters
                      ? AppColors.primary
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                tooltip: 'Filter issues',
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),

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

  Widget _buildFilterChipsRow(
    BuildContext context,
    dynamic state,
    dynamic notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Filter: ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),

            // Issue Types
            ...[IssueType.story, IssueType.task, IssueType.bug].map((type) {
              final isSelected = state.selectedTypes.contains(type);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(type.label, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(type.icon, size: 13, color: type.color),
                  selected: isSelected,
                  onSelected: (_) => notifier.toggleTypeFilter(type),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              );
            }),

            const SizedBox(width: 8),
            Container(width: 1, height: 18, color: Colors.grey.shade300),
            const SizedBox(width: 8),

            // Priority Types
            ...[IssuePriority.urgent, IssuePriority.high, IssuePriority.medium, IssuePriority.low].map((p) {
              final isSelected = state.selectedPriorities.contains(p);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(p.label, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(p.icon, size: 13, color: p.color),
                  selected: isSelected,
                  onSelected: (_) => notifier.togglePriorityFilter(p),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              );
            }),

            if (state.hasActiveFilters) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  notifier.clearFilters();
                  setState(() {});
                },
                icon: const Icon(Icons.clear_all, size: 14),
                label: const Text('Clear all', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColumnsView(
    BuildContext context,
    dynamic state,
    dynamic notifier,
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
