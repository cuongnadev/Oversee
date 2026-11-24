import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';
import 'package:frontend/features/dashboard/presentation/widgets/burndown_chart_widget.dart';
import 'package:frontend/features/dashboard/presentation/widgets/status_distribution_widget.dart';
import 'package:frontend/features/project/application/project_overview_provider.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';
import 'package:frontend/features/project/application/project_settings_provider.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/widgets/overview_kpi_grid.dart';
import 'package:frontend/features/project/presentation/widgets/overview_sprint_hero.dart';
import 'package:frontend/features/project/presentation/widgets/overview_velocity_and_activity.dart';
import 'package:frontend/features/project/presentation/widgets/overview_work_sections_row.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Project Overview Screen aligned with Figma "Oversee - Overview Page" (node 1:2).
class ProjectOverviewScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const ProjectOverviewScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends ConsumerState<ProjectOverviewScreen> {
  bool _showWorkSections = true;
  bool _showAnalytics = true;
  bool _showVelocityAndActivity = true;

  String _greetingForNow(BuildContext context) {
    return context.l10n.greetingForHour(DateTime.now().hour);
  }

  String _firstName(String? fullName, String? email) {
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim().split(RegExp(r'\s+')).last;
    }
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'there';
  }

  void _openCustomizeMenu(BuildContext context) {
    final l10n = context.l10n;
    AppAdaptiveDialog.show<void>(
      context,
      title: l10n.customizeOverview,
      maxWidth: 460,
      child: StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final dialogL10n = ctx.l10n;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogL10n.visibleSections,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryFor(isDark),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(dialogL10n.workFocusSectionsToggle, style: const TextStyle(fontSize: 13)),
                value: _showWorkSections,
                onChanged: (v) {
                  setState(() => _showWorkSections = v);
                  setDialogState(() {});
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(dialogL10n.sprintBurndownAndDonut, style: const TextStyle(fontSize: 13)),
                value: _showAnalytics,
                onChanged: (v) {
                  setState(() => _showAnalytics = v);
                  setDialogState(() {});
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(dialogL10n.velocityAndRecentActivity, style: const TextStyle(fontSize: 13)),
                value: _showVelocityAndActivity,
                onChanged: (v) {
                  setState(() => _showVelocityAndActivity = v);
                  setDialogState(() {});
                },
              ),
              const Divider(height: 22),
              Text(
                dialogL10n.appSeedColor,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryFor(isDark),
                ),
              ),
              const SizedBox(height: 10),
              const SeedColorSelector(showCustomHexInput: false),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: AppOutlinedButton(
                  label: dialogL10n.done,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectOverviewNotifierProvider(widget.projectId));
    final notifier = ref.read(projectOverviewNotifierProvider(widget.projectId).notifier);
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'overview',
      title: 'Overview',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'overview',
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading) {
                  return const DashboardSkeleton();
                }

                if (state.errorMessage != null && state.project == null) {
                  return Center(
                    child: AppEmptyState(
                      icon: Icons.error_outline,
                      title: 'Failed to load project',
                      description: state.errorMessage,
                      action: AppPrimaryButton(
                        label: 'Retry',
                        icon: Icons.refresh,
                        onPressed: () => notifier.loadProject(),
                      ),
                    ),
                  );
                }

                final project = state.project;
                if (project == null) {
                  return const Center(
                    child: AppEmptyState(
                      icon: Icons.folder_off_outlined,
                      title: 'Project not found',
                      description: 'The requested project could not be found or has been removed.',
                    ),
                  );
                }

                final dashboardAdapter = DashboardState(
                  project: project,
                  sprints: state.sprints,
                  selectedSprint: state.activeSprint,
                  progress: state.sprintProgress,
                  issues: state.sprintIssues,
                  members: state.members,
                );

                return RefreshIndicator(
                  onRefresh: () => notifier.refresh(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (project.isArchived) ...[
                              _buildArchivedBanner(context, project, isDark),
                              const SizedBox(height: 18.0),
                            ],

                            // 1. Figma PageHeading (eyebrow, greeting, project pill, date & customize)
                            _buildPageHeading(
                              context,
                              project: project,
                              canEdit: state.canEdit,
                              userName: _firstName(authState.user?.fullName, authState.email),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 14.0),

                            // 2. Sub-meta status strip (node 1:445)
                            _buildStatusMetaStrip(state, isDark),
                            const SizedBox(height: 16.0),

                            // 3. Active Sprint Hero Banner (node 1:454)
                            OverviewSprintHero(
                              state: state,
                              workspaceId: widget.workspaceId,
                              projectId: widget.projectId,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 20.0),

                            // 4. 4-Column KPI Grid (node 1:518)
                            OverviewKpiGrid(state: state, isDark: isDark),
                            const SizedBox(height: 20.0),

                            // 4b. 3-Column Work Focus Row (My Ongoing Jobs | Upcoming Jobs | Participant Workloads)
                            if (_showWorkSections) ...[
                              OverviewWorkSectionsRow(
                                state: state,
                                workspaceId: widget.workspaceId,
                                projectId: widget.projectId,
                                currentUserId: authState.user?.id,
                                isDark: isDark,
                                onIssueUpdated: () => notifier.refresh(),
                              ),
                              const SizedBox(height: 20.0),
                            ],

                            // 5. Burndown + Status Donut Row (4:2 ratio on desktop)
                            if (_showAnalytics) ...[
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 900;
                                  final burndownWidget = state.sprintProgress != null
                                      ? BurndownChartWidget(
                                          progress: state.sprintProgress!,
                                          isDark: isDark,
                                        )
                                      : _buildEmptyBurndownPlaceholder(isDark);
                                  final statusWidget = StatusDistributionWidget(
                                    state: dashboardAdapter,
                                    isDark: isDark,
                                  );

                                  if (isWide) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 4, child: burndownWidget),
                                        const SizedBox(width: 18),
                                        Expanded(flex: 2, child: statusWidget),
                                      ],
                                    );
                                  }
                                  return Column(
                                    children: [
                                      burndownWidget,
                                      const SizedBox(height: 16),
                                      statusWidget,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20.0),
                            ],

                            // 6. Velocity + Recent Activity Row (1:1 ratio on desktop)
                            if (_showVelocityAndActivity) ...[
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 900;
                                  final velocityCard = OverviewVelocityCard(state: state, isDark: isDark);
                                  final activityCard = OverviewRecentActivityCard(
                                    state: state,
                                    workspaceId: widget.workspaceId,
                                    projectId: widget.projectId,
                                    isDark: isDark,
                                  );

                                  if (isWide) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: velocityCard),
                                        const SizedBox(width: 18),
                                        Expanded(child: activityCard),
                                      ],
                                    );
                                  }
                                  return Column(
                                    children: [
                                      velocityCard,
                                      const SizedBox(height: 16),
                                      activityCard,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20.0),
                            ],

                            // 7. Team Members & Quick Navigation
                            _buildTeamMembersCard(context, state.members, state.canEdit, isDark),
                            const SizedBox(height: 20.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeading(
    BuildContext context, {
    required ProjectModel project,
    required bool canEdit,
    required String userName,
    required bool isDark,
  }) {
    final l10n = context.l10n;
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final surface2 = AppColors.surface2For(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final todayLabel = DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.workspaceOverviewEyebrow,
              style: AppTypography.eyebrow(isDark).copyWith(fontSize: 9.5, letterSpacing: 1.5),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_greetingForNow(context)}, $userName',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    height: 1.2,
                    color: textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: accentColor.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    project.key,
                    style: AppTypography.mono(
                      isDark,
                      fontSize: 10.5,
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildStatusBadge(context, project.isArchived, isDark),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              project.description?.isNotEmpty == true
                  ? '${project.name} · ${project.description}'
                  : '${project.name} · ${l10n.overviewSubtitleFallback}',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: surface2,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 13.5, color: textMuted),
                  const SizedBox(width: 6),
                  Text(
                    todayLabel,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textPrimary),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _openCustomizeMenu(context),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 13.5, color: textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      l10n.customize,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: textMuted),
                  ],
                ),
              ),
            ),
            if (canEdit)
              InkWell(
                onTap: () => context.go(AppRoutes.projectSettingsPath(widget.workspaceId, widget.projectId)),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: surface2,
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_outlined, size: 14, color: textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        l10n.settings,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusMetaStrip(ProjectOverviewState state, bool isDark) {
    final l10n = context.l10n;
    final blockers = state.blockerIssuesCount;
    final statusColor = blockers == 0 ? AppColors.successFor(isDark) : AppColors.warningFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              blockers == 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
              size: 13.5,
              color: statusColor,
            ),
            const SizedBox(width: 5),
            Text(
              l10n.blockersSummary(blockers),
              style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          l10n.syncedFromLiveData,
          style: TextStyle(fontSize: 10.5, color: textMuted),
        ),
      ],
    );
  }

  Widget _buildEmptyBurndownPlaceholder(bool isDark) {
    return Container(
      width: double.infinity,
      height: 310,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(isDark),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.borderFor(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sprint Burndown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryFor(isDark),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Story points remaining over sprint duration',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMutedFor(isDark)),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart_rounded, size: 30, color: AppColors.textMutedFor(isDark)),
                  const SizedBox(height: 8),
                  Text(
                    'Start an active sprint to track daily burndown progress.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(isDark)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedBanner(BuildContext context, ProjectModel project, bool isDark) {
    final warningColor = AppColors.warningFor(isDark);
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppColors.warningSoftFor(isDark),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: warningColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.archive_outlined, color: warningColor, size: 24),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This project is currently archived.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppColors.textPrimaryFor(isDark),
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  'Archived projects are read-only and hidden from active workspace project lists.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          AppOutlinedButton(
            label: 'Restore Project',
            icon: Icons.unarchive_outlined,
            onPressed: () async {
              final settingsNotifier =
                  ref.read(projectSettingsNotifierProvider(widget.projectId).notifier);
              final success = await settingsNotifier.restoreProject();
              if (success && context.mounted) {
                AppFeedback.showSuccess(context, 'Project restored successfully!');
                await ref.read(projectOverviewNotifierProvider(widget.projectId).notifier).loadProject();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isArchived, bool isDark) {
    final l10n = context.l10n;
    final color = isArchived ? AppColors.warningFor(isDark) : AppColors.successFor(isDark);
    final softBg = isArchived ? AppColors.warningSoftFor(isDark) : AppColors.greenSoftFor(isDark);
    final text = isArchived ? l10n.archivedBadge : l10n.activeBadge;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildTeamMembersCard(
    BuildContext context,
    List<ProjectMemberModel> members,
    bool canEdit,
    bool isDark,
  ) {
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return AppCard(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.teamMembers,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: accentSoft,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: Text(
                      '${members.length}',
                      style: AppTypography.mono(
                        isDark,
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (canEdit)
                TextButton.icon(
                  onPressed: () =>
                      context.go(AppRoutes.projectSettingsPath(widget.workspaceId, widget.projectId)),
                  icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                  label: Text(context.l10n.manageMembers, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12.0),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No members found in this project.',
                style: TextStyle(fontSize: 12.5, color: textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, _) => Divider(height: 14.0, color: AppColors.borderSoftFor(isDark)),
              itemBuilder: (context, index) {
                final member = members[index];
                final displayName = member.user?.fullName.isNotEmpty == true
                    ? member.user!.fullName
                    : (member.user?.email ?? 'Member');
                final email = member.user?.email ?? '';

                return Row(
                  children: [
                    UserAvatar(
                      name: displayName,
                      size: UserAvatarSize.sm,
                      showTooltip: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(fontSize: 11.5, color: textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    RoleBadge(role: member.role),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
