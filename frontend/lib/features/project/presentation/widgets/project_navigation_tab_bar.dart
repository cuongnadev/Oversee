import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Navigation Tab Bar for switching quickly between Project sections.
class ProjectNavigationTabBar extends StatelessWidget {
  final String workspaceId;
  final String projectId;
  final String activeTab; // 'overview', 'backlog', 'board', 'sprints', 'dashboard', 'settings'

  const ProjectNavigationTabBar({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final tabs = [
      _TabItem(
        id: 'overview',
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        path: AppRoutes.projectOverviewPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'board',
        label: 'Kanban Board',
        icon: Icons.view_kanban_outlined,
        activeIcon: Icons.view_kanban,
        path: AppRoutes.projectBoardPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'backlog',
        label: 'Backlog',
        icon: Icons.format_list_bulleted_outlined,
        activeIcon: Icons.format_list_bulleted,
        path: AppRoutes.projectBacklogPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'sprints',
        label: 'Sprint Planning',
        icon: Icons.timer_outlined,
        activeIcon: Icons.timer,
        path: AppRoutes.projectSprintsPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        path: AppRoutes.projectDashboardPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        path: AppRoutes.projectSettingsPath(workspaceId, projectId),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: tabs.map((tab) {
            final isActive = tab.id == activeTab;
            final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
            final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.65);

            return InkWell(
              onTap: () {
                if (!isActive) {
                  context.go(tab.path);
                }
              },
              borderRadius: BorderRadius.circular(6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? primaryColor : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? tab.activeIcon : tab.icon,
                      size: 18,
                      color: isActive ? primaryColor : inactiveColor,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      tab.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isActive ? primaryColor : inactiveColor,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _TabItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
