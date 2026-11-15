import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_panel.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/features/sprint/application/sprint_planning_provider.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_planning_model.dart';
import 'package:frontend/features/sprint/presentation/widgets/create_sprint_dialog.dart';
import 'package:frontend/features/sprint/presentation/widgets/start_sprint_dialog.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Sprint Planning screen supporting:
/// - 2-column visual layout (Backlog on left, Sprints on right)
/// - Drag & Drop issue assignment and quick move buttons
/// - Capacity calculation and prominent over-capacity warning banners
/// - Create sprint dialog
class SprintPlanningScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const SprintPlanningScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<SprintPlanningScreen> createState() => _SprintPlanningScreenState();
}

class _SprintPlanningScreenState extends ConsumerState<SprintPlanningScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateSprintDialog(SprintPlanningNotifier notifier) {
    CreateSprintDialog.show(
      context,
      onSubmit: ({
        required String name,
        String? goal,
        DateTime? startDate,
        DateTime? endDate,
        double? capacity,
      }) async {
        final created = await notifier.createSprint(
          name: name,
          goal: goal,
          startDate: startDate,
          endDate: endDate,
          capacity: capacity,
        );
        if (created != null && mounted) {
          AppFeedback.showSuccess(context, 'Sprint "${created.name}" created successfully.');
          return true;
        }
        return false;
      },
    );
  }

  void _openStartSprintDialog(
    BuildContext context,
    SprintModel sprint,
    SprintPlanningState state,
    SprintPlanningNotifier notifier,
  ) {
    final hasActiveSprint = state.sprints.any((s) => s.status == SprintStatus.active);
    final sprintRepo = ref.read(sprintRepositoryProvider);

    showDialog<bool>(
      context: context,
      builder: (ctx) => StartSprintDialog(
        sprint: sprint,
        hasOtherActiveSprint: hasActiveSprint,
        onStart: ({startDate, endDate}) async {
          try {
            await sprintRepo.startSprint(
              sprint.id,
              startDate: startDate,
              endDate: endDate,
            );
            await notifier.refresh();
            if (context.mounted) {
              AppFeedback.showSuccess(context, 'Sprint "${sprint.name}" started successfully.');
            }
            return true;
          } catch (e) {
            if (context.mounted) {
              AppFeedback.showError(context, 'Failed to start sprint: ${e.toString().replaceAll('Exception: ', '')}');
            }
            return false;
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sprintPlanningProvider(widget.projectId));
    final notifier = ref.read(sprintPlanningProvider(widget.projectId).notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'sprints',
      title: 'Sprint Planning',
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // Top Planning Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceDark,
                    border: Border(bottom: BorderSide(color: AppColors.borderDark)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryLight),
                          SizedBox(width: 8),
                          Text(
                            'Sprint Planning',
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondaryDark),
                            tooltip: 'Refresh planning data',
                            onPressed: () => notifier.refresh(),
                          ),
                          const SizedBox(width: 8),
                          AppPrimaryButton(
                            label: 'Create Sprint',
                            icon: Icons.add_rounded,
                            onPressed: () => _openCreateSprintDialog(notifier),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Error message banner
                if (state.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppColors.error.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main two-column or mobile tabbed planning interface
                Expanded(
                  child: isMobile
                      ? DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              TabBar(
                                indicatorColor: AppColors.primary,
                                labelColor: AppColors.primary,
                                unselectedLabelColor: AppColors.textSecondaryDark,
                                tabs: [
                                  Tab(text: 'Backlog (${state.backlogIssues.length})'),
                                  Tab(text: 'Sprints (${state.sprints.length})'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildBacklogColumn(state, notifier),
                                    _buildSprintsColumn(state, notifier),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Product Backlog
                              Expanded(
                                flex: 5,
                                child: _buildBacklogColumn(state, notifier),
                              ),
                              const SizedBox(width: 16),

                              // Right Column: Sprints Bucket
                              Expanded(
                                flex: 6,
                                child: _buildSprintsColumn(state, notifier),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBacklogColumn(SprintPlanningState state, SprintPlanningNotifier notifier) {
    final issues = state.filteredBacklogIssues;
    final projectKey = state.project?.key ?? 'OVS';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backlog Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondaryDark),
                        const SizedBox(width: 8),
                        const Text(
                          'Product Backlog',
                          style: TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${issues.length}',
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${state.totalBacklogStoryPoints.toInt()} pts',
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search field
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => notifier.setSearchQuery(val),
                    style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Filter backlog issues...',
                      hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondaryDark),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: AppColors.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Backlog List
          Expanded(
            child: issues.isEmpty
                ? const Center(
                    child: Text(
                      'No backlog issues found.',
                      style: TextStyle(color: AppColors.textMutedDark, fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: issues.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return _buildBacklogIssueCard(issue, projectKey, state, notifier);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBacklogIssueCard(
    IssueModel issue,
    String projectKey,
    SprintPlanningState state,
    SprintPlanningNotifier notifier,
  ) {
    return LongPressDraggable<IssueModel>(
      data: issue,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Text(
            issue.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildIssueTile(issue, projectKey, state, notifier),
      ),
      child: _buildIssueTile(issue, projectKey, state, notifier),
    );
  }

  Widget _buildIssueTile(
    IssueModel issue,
    String projectKey,
    SprintPlanningState state,
    SprintPlanningNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Icon(issue.type.icon, size: 16, color: issue.type.color),
          const SizedBox(width: 8),
          Text(
            issue.formattedKey(projectKey),
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => IssueDetailPanel.show(
                context,
                projectId: widget.projectId,
                projectKey: projectKey,
                issue: issue,
              ),
              child: Text(
                issue.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(issue.priority.icon, size: 14, color: issue.priority.color),
          const SizedBox(width: 8),
          if (issue.estimate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Text(
                '${issue.estimate!.toInt()} pts',
                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
              ),
            ),
          const SizedBox(width: 6),

          // Quick move to first available sprint button
          if (state.sprints.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Move to Sprint',
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primaryLight),
              color: AppColors.cardDark,
              onSelected: (sprintId) => notifier.assignIssueToSprint(sprintId, issue),
              itemBuilder: (context) {
                return state.sprints.map((sprint) {
                  return PopupMenuItem(
                    value: sprint.id,
                    child: Text('Move to ${sprint.name}', style: const TextStyle(fontSize: 13)),
                  );
                }).toList();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSprintsColumn(SprintPlanningState state, SprintPlanningNotifier notifier) {
    if (state.sprints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timeline_rounded, size: 48, color: AppColors.textMutedDark),
              const SizedBox(height: 12),
              const Text(
                'No Sprints Planned Yet',
                style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a sprint to start planning and allocating backlog issues.',
                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: 'Create First Sprint',
                icon: Icons.add_rounded,
                onPressed: () => _openCreateSprintDialog(notifier),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: state.sprints.length,
      separatorBuilder: (_, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final sprint = state.sprints[index];
        final summary = state.planningSummaries[sprint.id] ??
            SprintPlanningModel(sprint: sprint, capacity: sprint.capacity);
        return _buildSprintBucket(sprint, summary, state, notifier);
      },
    );
  }

  Widget _buildSprintBucket(
    SprintModel sprint,
    SprintPlanningModel summary,
    SprintPlanningState state,
    SprintPlanningNotifier notifier,
  ) {
    final projectKey = state.project?.key ?? 'OVS';
    final hasCapacity = summary.capacity != null && summary.capacity! > 0;
    final isOverCapacity = summary.isOverCapacity;

    return DragTarget<IssueModel>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        notifier.assignIssueToSprint(sprint.id, details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHovered
                  ? AppColors.primary
                  : (isOverCapacity ? AppColors.warning : AppColors.borderDark),
              width: isHovered || isOverCapacity ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sprint Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sprint.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimaryDark,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildSprintStatusBadge(sprint.status),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          sprint.dateRangeText,
                          style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                        ),
                        if (sprint.status == SprintStatus.planned) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded, size: 14),
                            label: const Text('Start'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _openStartSprintDialog(context, sprint, state, notifier),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Metrics row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${summary.totalIssues} issue${summary.totalIssues == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                        ),
                        Row(
                          children: [
                            Text(
                              '${summary.totalEstimate.toInt()} / ${hasCapacity ? summary.capacity!.toInt() : '∞'} pts',
                              style: TextStyle(
                                color: isOverCapacity ? AppColors.warning : AppColors.textPrimaryDark,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasCapacity) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${summary.capacityPercentageText})',
                                style: TextStyle(
                                  color: isOverCapacity ? AppColors.warning : AppColors.textMutedDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    // Capacity Progress Bar
                    if (hasCapacity) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: summary.capacityUsageRatio.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceDark,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverCapacity ? AppColors.warning : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Capacity Warning Banner
              if (isOverCapacity)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    border: const Border(
                      bottom: BorderSide(color: AppColors.warning),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary.warning ??
                              'Sprint estimate (${summary.totalEstimate.toInt()} pts) exceeds capacity (${summary.capacity!.toInt()} pts).',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Issues List in this Sprint
              if (summary.issues.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      isHovered
                          ? 'Drop issue here to add to ${sprint.name}'
                          : 'Drag backlog issues here or use the → button',
                      style: TextStyle(
                        color: isHovered ? AppColors.primary : AppColors.textMutedDark,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(10),
                  itemCount: summary.issues.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final issue = summary.issues[idx];
                    return _buildSprintIssueCard(issue, sprint.id, projectKey, notifier);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSprintIssueCard(
    IssueModel issue,
    String sprintId,
    String projectKey,
    SprintPlanningNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Icon(issue.type.icon, size: 16, color: issue.type.color),
          const SizedBox(width: 8),
          Text(
            issue.formattedKey(projectKey),
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => IssueDetailPanel.show(
                context,
                projectId: widget.projectId,
                projectKey: projectKey,
                issue: issue,
              ),
              child: Text(
                issue.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(issue.priority.icon, size: 14, color: issue.priority.color),
          const SizedBox(width: 8),
          if (issue.estimate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Text(
                '${issue.estimate!.toInt()} pts',
                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
              ),
            ),
          const SizedBox(width: 6),

          // Remove issue from sprint button (returns to backlog)
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textMutedDark),
            tooltip: 'Remove to Backlog',
            onPressed: () => notifier.removeIssueFromSprint(sprintId, issue),
          ),
        ],
      ),
    );
  }

  Widget _buildSprintStatusBadge(SprintStatus status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case SprintStatus.active:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        text = 'ACTIVE';
        break;
      case SprintStatus.planned:
        bg = AppColors.primary.withValues(alpha: 0.15);
        fg = AppColors.primaryLight;
        text = 'PLANNED';
        break;
      case SprintStatus.completed:
        bg = AppColors.borderDark;
        fg = AppColors.textSecondaryDark;
        text = 'COMPLETED';
        break;
      case SprintStatus.closed:
        bg = AppColors.borderDark;
        fg = AppColors.textMutedDark;
        text = 'CLOSED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
