import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';

class ProjectScreenScaffold extends StatelessWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;
  final String title;
  final Widget body;

  const ProjectScreenScaffold({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Workspaces',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(AppRoutes.workspaces);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Workspace: $workspaceId',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary),
                ),
                const Text(' / ', style: TextStyle(fontSize: 12)),
                Text(
                  'Project: $projectId',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildNavTab(
                  context,
                  label: 'Overview',
                  icon: Icons.dashboard_outlined,
                  route: AppRoutes.projectOverviewPath(workspaceId, projectId),
                  isSelected: currentRoute == 'overview',
                ),
                _buildNavTab(
                  context,
                  label: 'Backlog',
                  icon: Icons.format_list_bulleted_rounded,
                  route: AppRoutes.projectBacklogPath(workspaceId, projectId),
                  isSelected: currentRoute == 'backlog',
                ),
                _buildNavTab(
                  context,
                  label: 'Kanban Board',
                  icon: Icons.view_kanban_outlined,
                  route: AppRoutes.projectBoardPath(workspaceId, projectId),
                  isSelected: currentRoute == 'board',
                ),
                _buildNavTab(
                  context,
                  label: 'Sprints',
                  icon: Icons.timer_outlined,
                  route: AppRoutes.projectSprintsPath(workspaceId, projectId),
                  isSelected: currentRoute == 'sprints',
                ),
                _buildNavTab(
                  context,
                  label: 'Dashboard',
                  icon: Icons.bar_chart_rounded,
                  route: AppRoutes.projectDashboardPath(workspaceId, projectId),
                  isSelected: currentRoute == 'dashboard',
                ),
                _buildNavTab(
                  context,
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  route: AppRoutes.projectSettingsPath(workspaceId, projectId),
                  isSelected: currentRoute == 'settings',
                ),
              ],
            ),
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildNavTab(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String route,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: isSelected ? AppColors.primary : Colors.grey,
          backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () {
          if (!isSelected) {
            context.go(route);
          }
        },
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
