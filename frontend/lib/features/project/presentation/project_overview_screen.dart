import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/project/application/project_overview_provider.dart';
import 'package:frontend/features/project/application/project_settings_provider.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Project Overview Screen displaying key info, quick navigation, KPIs, and team members.
class ProjectOverviewScreen extends ConsumerWidget {
  final String workspaceId;
  final String projectId;

  const ProjectOverviewScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectOverviewNotifierProvider(projectId));
    final notifier = ref.read(projectOverviewNotifierProvider(projectId).notifier);

    return ProjectScreenScaffold(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: 'overview',
      title: state.project?.name ?? 'Project Overview',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: workspaceId,
            projectId: projectId,
            activeTab: 'overview',
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading) {
                  return const Center(child: AppLoadingIndicator(size: 36.0));
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

                return RefreshIndicator(
                  onRefresh: () => notifier.refresh(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (project.isArchived) ...[
                          _buildArchivedBanner(context, ref, project),
                          const SizedBox(height: 20.0),
                        ],
                        _buildHeaderCard(context, project, state.canEdit),
                        const SizedBox(height: 24.0),
                        _buildMetricGrid(context, project, state.members.length),
                        const SizedBox(height: 24.0),
                        _buildQuickActions(context),
                        const SizedBox(height: 24.0),
                        _buildTeamMembersCard(context, state.members, state.canEdit),
                      ],
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

  Widget _buildArchivedBanner(BuildContext context, WidgetRef ref, ProjectModel project) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.warningLight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: AppColors.warningLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.archive_outlined, color: AppColors.warningLight, size: 28),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This project is currently archived.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Archived projects are read-only and hidden from active workspace project lists.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AppOutlinedButton(
            label: 'Restore Project',
            icon: Icons.unarchive_outlined,
            onPressed: () async {
              final settingsNotifier = ref.read(projectSettingsNotifierProvider(projectId).notifier);
              final success = await settingsNotifier.restoreProject();
              if (success && context.mounted) {
                AppFeedback.showSuccess(context, 'Project restored successfully!');
                await ref.read(projectOverviewNotifierProvider(projectId).notifier).loadProject();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ProjectModel project, bool canEdit) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  project.key,
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            project.name,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        _buildStatusBadge(project.isArchived),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      project.description?.isNotEmpty == true
                          ? project.description!
                          : 'No project description provided.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 12.0),
                AppOutlinedButton(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  onPressed: () => context.go(AppRoutes.projectSettingsPath(workspaceId, projectId)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isArchived) {
    final color = isArchived ? AppColors.warningLight : AppColors.successLight;
    final text = isArchived ? 'ARCHIVED' : 'ACTIVE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetricGrid(BuildContext context, ProjectModel project, int memberCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2;

        final metrics = [
          _MetricData(
            label: 'Team Members',
            value: '$memberCount',
            icon: Icons.group_outlined,
            color: Colors.blue,
          ),
          _MetricData(
            label: 'Project Key',
            value: project.key,
            icon: Icons.vpn_key_outlined,
            color: Colors.deepPurple,
          ),
          _MetricData(
            label: 'Project Status',
            value: project.isArchived ? 'Archived' : 'Active',
            icon: project.isArchived ? Icons.archive_outlined : Icons.check_circle_outline,
            color: project.isArchived ? Colors.orange : Colors.green,
          ),
          _MetricData(
            label: 'Created Date',
            value: project.createdAt != null
                ? '${project.createdAt!.day}/${project.createdAt!.month}/${project.createdAt!.year}'
                : 'N/A',
            icon: Icons.calendar_today_outlined,
            color: Colors.teal,
          ),
        ];

        return Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          children: metrics.map((m) {
            return SizedBox(
              width: cardWidth,
              child: AppCard(
                padding: const EdgeInsets.all(18.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Icon(m.icon, color: m.color, size: 24),
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.label,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                                ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            m.value,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Navigation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12.0),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            final itemWidth = isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;

            final actions = [
              _QuickActionData(
                title: 'Kanban Board',
                subtitle: 'Visualize workflow and manage task stages.',
                icon: Icons.view_kanban_outlined,
                color: Colors.indigo,
                onTap: () => context.go(AppRoutes.projectBoardPath(workspaceId, projectId)),
              ),
              _QuickActionData(
                title: 'Product Backlog',
                subtitle: 'Organize user stories, backlog items, and sprints.',
                icon: Icons.format_list_bulleted_outlined,
                color: Colors.blue,
                onTap: () => context.go(AppRoutes.projectBacklogPath(workspaceId, projectId)),
              ),
              _QuickActionData(
                title: 'Sprint Planning',
                subtitle: 'Manage active sprint goals, velocity, and releases.',
                icon: Icons.timer_outlined,
                color: Colors.orange,
                onTap: () => context.go(AppRoutes.projectSprintsPath(workspaceId, projectId)),
              ),
            ];

            return Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              children: actions.map((act) {
                return SizedBox(
                  width: itemWidth,
                  child: AppCard(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: act.onTap,
                      borderRadius: BorderRadius.circular(8.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: act.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Icon(act.icon, color: act.color, size: 28),
                          ),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  act.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  act.subtitle,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTeamMembersCard(
    BuildContext context,
    List<ProjectMemberModel> members,
    bool canEdit,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Team Members',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      '${members.length}',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (canEdit)
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.projectSettingsPath(workspaceId, projectId)),
                  icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                  label: const Text('Manage Members'),
                ),
            ],
          ),
          const SizedBox(height: 16.0),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('No members found in this project.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, _) => const Divider(height: 16.0),
              itemBuilder: (context, index) {
                final member = members[index];
                final displayName = member.user?.fullName.isNotEmpty == true
                    ? member.user!.fullName
                    : (member.user?.email ?? 'Member');
                final email = member.user?.email ?? '';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                    child: Text(
                      _getInitials(displayName),
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                    ),
                  ),
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: email.isNotEmpty ? Text(email) : null,
                  trailing: _buildRoleBadge(member.role),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(RoleType role) {
    Color color;
    switch (role) {
      case RoleType.owner:
        color = Colors.amber.shade800;
        break;
      case RoleType.admin:
        color = Colors.indigo;
        break;
      case RoleType.member:
        color = Colors.blue;
        break;
      case RoleType.viewer:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _QuickActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
