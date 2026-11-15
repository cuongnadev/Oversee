import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/shared/layout/nav_item.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Bottom Navigation Bar for Mobile (< 600px).
class MobileBottomNav extends StatelessWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;
  final VoidCallback onOpenMore;

  const MobileBottomNav({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
    required this.onOpenMore,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final primaryItems = [
      const NavItem(
        keyName: 'overview',
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
      const NavItem(
        keyName: 'board',
        label: 'Board',
        icon: Icons.view_kanban_outlined,
        selectedIcon: Icons.view_kanban_rounded,
      ),
      const NavItem(
        keyName: 'backlog',
        label: 'Backlog',
        icon: Icons.format_list_bulleted_rounded,
        selectedIcon: Icons.format_list_bulleted_rounded,
      ),
      const NavItem(
        keyName: 'sprints',
        label: 'Sprints',
        icon: Icons.timer_outlined,
        selectedIcon: Icons.timer_rounded,
      ),
    ];

    int currentIndex = primaryItems.indexWhere((item) => item.keyName == currentRoute);
    if (currentIndex == -1) {
      // If current route is dashboard or settings, 'More' is active
      currentIndex = 4;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56.0,
          child: Row(
            children: [
              for (int i = 0; i < primaryItems.length; i++) ...[
                Expanded(
                  child: _buildNavItem(
                    context,
                    item: primaryItems[i],
                    isSelected: currentIndex == i,
                    isDark: isDark,
                    onTap: () {
                      switch (primaryItems[i].keyName) {
                        case 'overview':
                          context.go(AppRoutes.projectOverviewPath(workspaceId, projectId));
                          break;
                        case 'board':
                          context.go(AppRoutes.projectBoardPath(workspaceId, projectId));
                          break;
                        case 'backlog':
                          context.go(AppRoutes.projectBacklogPath(workspaceId, projectId));
                          break;
                        case 'sprints':
                          context.go(AppRoutes.projectSprintsPath(workspaceId, projectId));
                          break;
                      }
                    },
                  ),
                ),
              ],
              Expanded(
                child: _buildNavItem(
                  context,
                  item: const NavItem(
                    keyName: 'more',
                    label: 'More',
                    icon: Icons.more_horiz_rounded,
                    selectedIcon: Icons.more_horiz_rounded,
                  ),
                  isSelected: currentIndex == 4,
                  isDark: isDark,
                  onTap: onOpenMore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required NavItem item,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    const Color selectedColor = AppColors.primary;
    final Color unselectedColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              size: 20.0,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(height: 2.0),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigation Drawer for Mobile (< 600px).
class MobileAppDrawer extends ConsumerWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;

  const MobileAppDrawer({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
  });

  String _buildRoute(String keyName) {
    switch (keyName) {
      case 'overview':
        return AppRoutes.projectOverviewPath(workspaceId, projectId);
      case 'backlog':
        return AppRoutes.projectBacklogPath(workspaceId, projectId);
      case 'board':
        return AppRoutes.projectBoardPath(workspaceId, projectId);
      case 'sprints':
        return AppRoutes.projectSprintsPath(workspaceId, projectId);
      case 'dashboard':
        return AppRoutes.projectDashboardPath(workspaceId, projectId);
      case 'settings':
        return AppRoutes.projectSettingsPath(workspaceId, projectId);
      default:
        return AppRoutes.projectOverviewPath(workspaceId, projectId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(Icons.hub_rounded, color: Colors.white, size: 22.0),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Oversee',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Workspace: $workspaceId',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                children: [
                  for (final item in NavItem.projectNavItems) ...[
                    _buildDrawerItem(
                      context,
                      item: item,
                      isSelected: currentRoute == item.keyName,
                      isDark: isDark,
                    ),
                  ],
                  const Divider(height: 24.0),
                  ListTile(
                    leading: const Icon(Icons.hub_outlined, size: 20.0),
                    title: const Text('All Workspaces', style: TextStyle(fontSize: 14.0)),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(AppRoutes.workspaces);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, size: 20.0),
                    title: const Text('Workspace Settings', style: TextStyle(fontSize: 14.0)),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(AppRoutes.workspaceSettingsPath(workspaceId));
                    },
                  ),
                ],
              ),
            ),

            // Bottom user info & logout
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    name: authState.email ?? 'User',
                    size: UserAvatarSize.sm,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      authState.email ?? 'user@oversee.local',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20.0),
                    tooltip: 'Log Out',
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(ref.read(authNotifierProvider.notifier).logout());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required NavItem item,
    required bool isSelected,
    required bool isDark,
  }) {
    final Color selectedBg = AppColors.primary.withValues(alpha: 0.12);
    const Color selectedColor = AppColors.primary;
    final Color unselectedColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        tileColor: isSelected ? selectedBg : Colors.transparent,
        leading: Icon(
          isSelected ? item.selectedIcon : item.icon,
          color: isSelected ? selectedColor : unselectedColor,
          size: 20.0,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? selectedColor : unselectedColor,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          if (!isSelected) {
            context.go(_buildRoute(item.keyName));
          }
        },
      ),
    );
  }
}
