import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_panel.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/features/sprint/application/sprint_planning_provider.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_planning_model.dart';
import 'package:frontend/features/sprint/presentation/widgets/create_sprint_dialog.dart';
import 'package:frontend/features/sprint/presentation/widgets/start_sprint_dialog.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Sprint Planning screen aligned with Figma Planning & Backlog-to-Sprint layout.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final errorColor = AppColors.errorFor(isDark);

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'planning',
      title: 'Sprint Planning',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'sprints',
          ),
          Expanded(
            child: state.isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : Column(
                    children: [
                      // Top Planning Header Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bgFor(isDark),
                          border: Border(
                            bottom: BorderSide(color: AppColors.borderFor(isDark)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ITERATE & DELIVER',
                                    style: AppTypography.eyebrow(isDark).copyWith(fontSize: 9),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sprint Planning',
                                    style: TextStyle(
                                      color: AppColors.textPrimaryFor(isDark),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIconButton(
                                  icon: Icons.refresh_rounded,
                                  tooltip: 'Refresh planning data',
                                  size: 34,
                                  backgroundColor: AppColors.surface2For(isDark),
                                  onPressed: () => notifier.refresh(),
                                ),
                                const SizedBox(width: 8),
                                AppPrimaryButton(
                                  label: 'Create Sprint',
                                  icon: Icons.add_rounded,
                                  height: 34,
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoftFor(isDark),
                            border: Border(
                              bottom: BorderSide(color: errorColor.withValues(alpha: 0.3)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, size: 17, color: errorColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.errorMessage!,
                                  style: TextStyle(color: errorColor, fontSize: 12.5, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Balanced 2-Column (Desktop/Tablet) or Tabbed (Mobile) Planning Area
                      Expanded(
                        child: isMobile
                            ? DefaultTabController(
                                length: 2,
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceFor(isDark),
                                        border: Border(
                                          bottom: BorderSide(color: AppColors.borderFor(isDark)),
                                        ),
                                      ),
                                      child: TabBar(
                                        indicatorColor: accentColor,
                                        labelColor: AppColors.textPrimaryFor(isDark),
                                        unselectedLabelColor: AppColors.textSecondaryFor(isDark),
                                        tabs: [
                                          Tab(text: 'Backlog (${state.backlogIssues.length})'),
                                          Tab(text: 'Sprints (${state.sprints.length})'),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: TabBarView(
                                          children: [
                                            _buildBacklogColumn(state, notifier, isDark),
                                            _buildSprintsColumn(state, notifier, isDark),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Left Column: Product Backlog Pool
                                    Expanded(
                                      flex: 5,
                                      child: _buildBacklogColumn(state, notifier, isDark),
                                    ),
                                    const SizedBox(width: 18),

                                    // Right Column: Sprint Buckets
                                    Expanded(
                                      flex: 6,
                                      child: _buildSprintsColumn(state, notifier, isDark),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBacklogColumn(
    SprintPlanningState state,
    SprintPlanningNotifier notifier,
    bool isDark,
  ) {
    final issues = state.filteredBacklogIssues;
    final projectKey = state.project?.key ?? 'OVS';
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(isDark),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backlog Pool Header (Figma .backlog-group-header)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface2For(isDark),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: AppColors.textSecondaryFor(isDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Product Backlog',
                          style: TextStyle(
                            color: AppColors.textPrimaryFor(isDark),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                            '${issues.length}',
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 10.5,
                              color: AppColors.textSecondaryFor(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: accentSoft,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Text(
                        '${state.totalBacklogStoryPoints.toInt()} pts',
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
                const SizedBox(height: 10),
                // Search field
                SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => notifier.setSearchQuery(val),
                    style: TextStyle(color: AppColors.textPrimaryFor(isDark), fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Filter backlog issues...',
                      hintStyle: TextStyle(color: AppColors.textMutedFor(isDark), fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded, size: 15, color: AppColors.textMutedFor(isDark)),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: AppColors.bgFor(isDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        borderSide: BorderSide(color: accentColor, width: 1.4),
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
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No backlog issues found.',
                        style: TextStyle(
                          color: AppColors.textMutedFor(isDark),
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: issues.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return _buildBacklogIssueCard(issue, projectKey, state, notifier, isDark);
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
    bool isDark,
  ) {
    final accentColor = AppColors.accentFor(isDark);

    return LongPressDraggable<IssueModel>(
      data: issue,
      feedback: Material(
        elevation: 10,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: accentColor, width: 1.5),
          ),
          child: Row(
            children: [
              Text(
                issue.formattedKey(projectKey),
                style: AppTypography.mono(isDark, fontSize: 10.5, color: accentColor, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  issue.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(isDark),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildIssueTile(issue, projectKey, state, notifier, isDark),
      ),
      child: _buildIssueTile(issue, projectKey, state, notifier, isDark),
    );
  }

  Widget _buildIssueTile(
    IssueModel issue,
    String projectKey,
    SprintPlanningState state,
    SprintPlanningNotifier notifier,
    bool isDark,
  ) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final accentColor = AppColors.accentFor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.bgFor(isDark),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderSoftFor(isDark)),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, size: 15, color: AppColors.textMutedFor(isDark)),
          const SizedBox(width: 6),
          Icon(issue.type.icon, size: 14.5, color: issue.type.colorFor(brightness)),
          const SizedBox(width: 8),
          Text(
            issue.formattedKey(projectKey),
            style: AppTypography.mono(
              isDark,
              fontSize: 10.5,
              color: AppColors.textMutedFor(isDark),
              fontWeight: FontWeight.w600,
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
                style: TextStyle(
                  color: AppColors.textPrimaryFor(isDark),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(issue.priority.icon, size: 14, color: issue.priority.colorFor(brightness)),
          const SizedBox(width: 8),
          if (issue.estimate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface2For(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                border: Border.all(color: AppColors.borderFor(isDark)),
              ),
              child: Text(
                '${issue.estimate!.toInt()} pts',
                style: AppTypography.mono(
                  isDark,
                  fontSize: 10,
                  color: AppColors.textSecondaryFor(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (state.sprints.isNotEmpty) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Move to Sprint',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_forward_rounded, size: 16, color: accentColor),
              onSelected: (sprintId) => notifier.assignIssueToSprint(sprintId, issue),
              itemBuilder: (context) {
                return state.sprints.map((sprint) {
                  return PopupMenuItem(
                    value: sprint.id,
                    child: Text('Move to ${sprint.name}', style: const TextStyle(fontSize: 12.5)),
                  );
                }).toList();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSprintsColumn(
    SprintPlanningState state,
    SprintPlanningNotifier notifier,
    bool isDark,
  ) {
    if (state.sprints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(isDark),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(color: AppColors.borderFor(isDark)),
        ),
        child: AppEmptyState(
          icon: Icons.timeline_rounded,
          title: 'No Sprints Planned Yet',
          description: 'Create a sprint to start planning and allocating backlog issues.',
          action: AppPrimaryButton(
            label: 'Create First Sprint',
            icon: Icons.add_rounded,
            onPressed: () => _openCreateSprintDialog(notifier),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: state.sprints.length,
      separatorBuilder: (_, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final sprint = state.sprints[index];
        final summary = state.planningSummaries[sprint.id] ??
            SprintPlanningModel(sprint: sprint, capacity: sprint.capacity);
        return _buildSprintBucket(sprint, summary, state, notifier, isDark);
      },
    );
  }

  Widget _buildSprintBucket(
    SprintModel sprint,
    SprintPlanningModel summary,
    SprintPlanningState state,
    SprintPlanningNotifier notifier,
    bool isDark,
  ) {
    final projectKey = state.project?.key ?? 'OVS';
    final hasCapacity = summary.capacity != null && summary.capacity! > 0;
    final isOverCapacity = summary.isOverCapacity;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final warningColor = AppColors.warningFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final borderColor = AppColors.borderFor(isDark);

    return DragTarget<IssueModel>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        notifier.assignIssueToSprint(sprint.id, details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: isHovered ? accentSoft.withValues(alpha: 0.35) : AppColors.surfaceFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: isHovered
                  ? accentColor
                  : (isOverCapacity ? warningColor : borderColor),
              width: isHovered || isOverCapacity ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sprint Header Card (Figma .backlog-group-header / .sprint-card)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface2For(isDark),
                  border: Border(bottom: BorderSide(color: borderColor)),
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
                              _buildSprintStateIcon(sprint.status, isDark),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  sprint.name,
                                  style: TextStyle(
                                    color: AppColors.textPrimaryFor(isDark),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildSprintStatusBadge(sprint.status, isDark),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          sprint.dateRangeText,
                          style: TextStyle(
                            color: AppColors.textMutedFor(isDark),
                            fontSize: 11.5,
                          ),
                        ),
                        if (sprint.status == SprintStatus.planned) ...[
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded, size: 14),
                            label: const Text('Start'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentSolidFor(isDark),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                              ),
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
                          style: TextStyle(color: AppColors.textSecondaryFor(isDark), fontSize: 12),
                        ),
                        Row(
                          children: [
                            Text(
                              '${summary.totalEstimate.toInt()} / ${hasCapacity ? summary.capacity!.toInt() : '∞'} pts',
                              style: AppTypography.mono(
                                isDark,
                                fontSize: 11.5,
                                color: isOverCapacity ? warningColor : AppColors.textPrimaryFor(isDark),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (hasCapacity) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(${summary.capacityPercentageText})',
                                style: AppTypography.mono(
                                  isDark,
                                  fontSize: 11,
                                  color: isOverCapacity ? warningColor : AppColors.textMutedFor(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    // Capacity Progress Bar (Figma 4-5px rounded .progress)
                    if (hasCapacity) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: summary.capacityUsageRatio.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: AppColors.surface3For(isDark),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverCapacity ? warningColor : successColor,
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
                    color: AppColors.warningSoftFor(isDark),
                    border: Border(
                      bottom: BorderSide(color: warningColor.withValues(alpha: 0.35)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 17, color: warningColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary.warning ??
                              'Sprint estimate (${summary.totalEstimate.toInt()} pts) exceeds capacity (${summary.capacity!.toInt()} pts).',
                          style: TextStyle(
                            color: warningColor,
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
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  child: Center(
                    child: Text(
                      isHovered
                          ? 'Drop issue here to add to ${sprint.name}'
                          : 'Drag backlog issues here or use the → button',
                      style: TextStyle(
                        color: isHovered ? accentColor : AppColors.textMutedFor(isDark),
                        fontSize: 12.5,
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
                    return _buildSprintIssueCard(issue, sprint.id, projectKey, notifier, isDark);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSprintStateIcon(SprintStatus status, bool isDark) {
    final Color bg;
    final Color fg;
    switch (status) {
      case SprintStatus.active:
        bg = AppColors.accentSoftFor(isDark);
        fg = AppColors.accentFor(isDark);
        break;
      case SprintStatus.completed:
        bg = AppColors.greenSoftFor(isDark);
        fg = AppColors.successFor(isDark);
        break;
      case SprintStatus.planned:
      case SprintStatus.closed:
        bg = AppColors.surface3For(isDark);
        fg = AppColors.textSecondaryFor(isDark);
        break;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Icon(Icons.track_changes_rounded, size: 15, color: fg),
    );
  }

  Widget _buildSprintIssueCard(
    IssueModel issue,
    String sprintId,
    String projectKey,
    SprintPlanningNotifier notifier,
    bool isDark,
  ) {
    final brightness = isDark ? Brightness.dark : Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.bgFor(isDark),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderSoftFor(isDark)),
      ),
      child: Row(
        children: [
          Icon(issue.type.icon, size: 14.5, color: issue.type.colorFor(brightness)),
          const SizedBox(width: 8),
          Text(
            issue.formattedKey(projectKey),
            style: AppTypography.mono(
              isDark,
              fontSize: 10.5,
              color: AppColors.textMutedFor(isDark),
              fontWeight: FontWeight.w600,
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
                style: TextStyle(
                  color: AppColors.textPrimaryFor(isDark),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(issue.priority.icon, size: 14, color: issue.priority.colorFor(brightness)),
          const SizedBox(width: 8),
          if (issue.estimate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface2For(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                border: Border.all(color: AppColors.borderFor(isDark)),
              ),
              child: Text(
                '${issue.estimate!.toInt()} pts',
                style: AppTypography.mono(
                  isDark,
                  fontSize: 10,
                  color: AppColors.textSecondaryFor(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, size: 15, color: AppColors.textMutedFor(isDark)),
            tooltip: 'Remove to Backlog',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => notifier.removeIssueFromSprint(sprintId, issue),
          ),
        ],
      ),
    );
  }

  Widget _buildSprintStatusBadge(SprintStatus status, bool isDark) {
    final Color bg;
    final Color fg;
    final String text;

    switch (status) {
      case SprintStatus.active:
        bg = AppColors.accentSoftFor(isDark);
        fg = AppColors.accentFor(isDark);
        text = 'ACTIVE';
        break;
      case SprintStatus.planned:
        bg = AppColors.surface3For(isDark);
        fg = AppColors.textSecondaryFor(isDark);
        text = 'PLANNED';
        break;
      case SprintStatus.completed:
        bg = AppColors.greenSoftFor(isDark);
        fg = AppColors.successFor(isDark);
        text = 'COMPLETED';
        break;
      case SprintStatus.closed:
        bg = AppColors.surface3For(isDark);
        fg = AppColors.textMutedFor(isDark);
        text = 'CLOSED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}
