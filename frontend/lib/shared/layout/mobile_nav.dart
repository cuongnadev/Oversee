import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/shared/layout/nav_item.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Bottom Navigation Bar for Mobile (< 600px) aligned with Figma .bottom-nav.
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
      currentIndex = 4;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.sidebarFor(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.borderFor(isDark),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 58.0,
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
    final Color selectedColor = AppColors.accentFor(isDark);
    final Color unselectedColor = AppColors.textMutedFor(isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              size: 19.0,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(height: 3.0),
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

/// Navigation Drawer for Mobile (< 600px) aligned with Figma mobile drawer.
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
    final Color accentColor = AppColors.accentFor(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color textPrimary = AppColors.textPrimaryFor(isDark);
    final Color textMuted = AppColors.textMutedFor(isDark);

    return Drawer(
      backgroundColor: AppColors.sidebarFor(isDark),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.layers_rounded, color: accentColor, size: 22.0),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: 'oversee',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontFamilyFallback: AppTypography.fontFallback,
                              fontSize: 19.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.7,
                              color: textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: '.',
                                style: TextStyle(color: accentColor),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Workspace: $workspaceId',
                          style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
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
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                children: [
                  for (final item in NavItem.projectNavItems)
                    _buildDrawerItem(
                      context,
                      item: item,
                      isSelected: currentRoute == item.keyName,
                      isDark: isDark,
                    ),
                  Divider(height: 24.0, color: borderColor),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                    leading: Icon(Icons.hub_outlined, size: 18.0, color: textMuted),
                    title: Text('All Workspaces', style: TextStyle(fontSize: 13.0, color: textPrimary)),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(AppRoutes.workspaces);
                    },
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
                    leading: Icon(Icons.settings_outlined, size: 18.0, color: textMuted),
                    title: Text('Workspace Settings', style: TextStyle(fontSize: 13.0, color: textPrimary)),
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
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: borderColor, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    name: authState.email ?? 'User',
                    size: UserAvatarSize.sm,
                    showStatus: true,
                    isOnline: true,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      authState.email ?? 'user@oversee.local',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.logout_rounded, color: AppColors.errorFor(isDark), size: 19.0),
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
    final Color selectedBg = AppColors.accentSoftFor(isDark);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color selectedText = AppColors.textPrimaryFor(isDark);
    final Color unselectedColor = AppColors.textSecondaryFor(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        tileColor: isSelected ? selectedBg : Colors.transparent,
        leading: Icon(
          isSelected ? item.selectedIcon : item.icon,
          color: isSelected ? accentColor : AppColors.textMutedFor(isDark),
          size: 18.0,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? selectedText : unselectedColor,
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
