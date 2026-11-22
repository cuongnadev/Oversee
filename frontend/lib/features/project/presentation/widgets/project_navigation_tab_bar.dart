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
    final borderColor = AppColors.borderFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final activeTextColor = AppColors.textPrimaryFor(isDark);
    final inactiveColor = AppColors.textSecondaryFor(isDark);

    final tabs = [
      _TabItem(
        id: 'overview',
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        path: AppRoutes.projectOverviewPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'board',
        label: 'Kanban Board',
        icon: Icons.view_kanban_outlined,
        activeIcon: Icons.view_kanban_rounded,
        path: AppRoutes.projectBoardPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'backlog',
        label: 'Backlog',
        icon: Icons.format_list_bulleted_outlined,
        activeIcon: Icons.format_list_bulleted_rounded,
        path: AppRoutes.projectBacklogPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'sprints',
        label: 'Sprint Planning',
        icon: Icons.timer_outlined,
        activeIcon: Icons.timer_rounded,
        path: AppRoutes.projectSprintsPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart_rounded,
        path: AppRoutes.projectDashboardPath(workspaceId, projectId),
      ),
      _TabItem(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        path: AppRoutes.projectSettingsPath(workspaceId, projectId),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgFor(isDark),
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

            return InkWell(
              onTap: () {
                if (!isActive) {
                  context.go(tab.path);
                }
              },
              hoverColor: AppColors.hoverFor(isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? accentColor : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? tab.activeIcon : tab.icon,
                      size: 16,
                      color: isActive ? accentColor : inactiveColor,
                    ),
                    const SizedBox(width: 7.0),
                    Text(
                      tab.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 12.5,
                        color: isActive ? activeTextColor : inactiveColor,
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
