import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/shared/layout/nav_item.dart';
import 'package:frontend/shared/layout/sidebar_icons.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Bottom Navigation Bar for Mobile (< 600px) aligned with Figma `.bottom-nav`.
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    const primaryItems = [
      NavItem(
        keyName: 'dashboard',
        label: 'Dashboard',
        icon: Icons.space_dashboard_outlined,
        selectedIcon: Icons.space_dashboard_rounded,
        figmaIcon: FigmaIconType.layoutDashboard,
      ),
      NavItem(
        keyName: 'board',
        label: 'Board',
        icon: Icons.view_kanban_outlined,
        selectedIcon: Icons.view_kanban_rounded,
        figmaIcon: FigmaIconType.folderKanban,
      ),
      NavItem(
        keyName: 'backlog',
        label: 'Backlog',
        icon: Icons.layers_outlined,
        selectedIcon: Icons.layers_rounded,
        figmaIcon: FigmaIconType.layers3,
      ),
      NavItem(
        keyName: 'sprints',
        label: 'Sprints',
        icon: Icons.timer_outlined,
        selectedIcon: Icons.timer_rounded,
        figmaIcon: FigmaIconType.timer,
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
              for (int i = 0; i < primaryItems.length; i++)
                Expanded(
                  child: _buildNavItem(
                    context,
                    item: primaryItems[i],
                    isSelected: currentIndex == i,
                    isDark: isDark,
                    onTap: () {
                      switch (primaryItems[i].keyName) {
                        case 'dashboard':
                          context.go(AppRoutes.projectDashboardPath(workspaceId, projectId));
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
              Expanded(
                child: _buildMoreItem(
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
            FigmaSidebarIcon(
              item.figmaIcon,
              size: 18.0,
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

  Widget _buildMoreItem({
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final Color selectedColor = AppColors.accentFor(isDark);
    final Color unselectedColor = AppColors.textMutedFor(isDark);
    final Color activeColor = isSelected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_rounded, size: 18.0, color: activeColor),
            const SizedBox(height: 3.0),
            Text(
              'More',
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: activeColor,
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

/// Navigation Drawer for Mobile (< 600px) aligned with Figma `.sidebar.drawer-open`.
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

  String _buildRoute(String keyName) =>
      NavItem.routeFor(keyName, workspaceId, projectId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color accentSoftColor = AppColors.accentSoftFor(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color borderSoftColor = AppColors.borderSoftFor(isDark);
    final Color textPrimary = AppColors.textPrimaryFor(isDark);
    final Color textSecondary = AppColors.textSecondaryFor(isDark);
    final Color textMuted = AppColors.textMutedFor(isDark);

    final String userEmail = authState.email ?? 'user@oversee.local';
    final String? fullName = authState.user?.fullName;
    final String userName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : userEmail.split('@').first.replaceAll('.', ' ');

    const groups = NavItem.navGroups;

    return Drawer(
      backgroundColor: AppColors.sidebarFor(isDark),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Brand Header (Figma .sidebar-brand: height 64px)
            Container(
              height: 64.0,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  FigmaSidebarIcon(
                    FigmaIconType.layers3,
                    size: 19.0,
                    color: accentColor,
                    strokeWidth: 1.75,
                  ),
                  const SizedBox(width: 9.0),
                  Flexible(
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        text: 'oversee',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontFamilyFallback: AppTypography.fontFallback,
                          fontSize: 21.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.9,
                          color: textPrimary,
                        ),
                        children: [
                          TextSpan(text: '.', style: TextStyle(color: accentColor)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: accentSoftColor,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 8.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18.0, color: textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close Menu',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),

            // Project Context Card
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 1.0, 12.0, 10.0),
              child: Container(
                padding: const EdgeInsets.all(9.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceFor(isDark),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 29.0,
                      height: 29.0,
                      decoration: BoxDecoration(
                        color: accentSoftColor,
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        projectId.trim().isNotEmpty ? projectId.trim()[0].toUpperCase() : 'P',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            projectId,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Workspace: $workspaceId',
                            style: TextStyle(fontSize: 9.5, color: textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Grouped Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                children: [
                  for (final (title, items) in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 4.0),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: textMuted,
                        ),
                      ),
                    ),
                    for (final item in items)
                      _buildDrawerItem(
                        context,
                        item: item,
                        isSelected: currentRoute == item.keyName,
                        isDark: isDark,
                      ),
                    const SizedBox(height: 8.0),
                  ],
                  Divider(height: 20.0, color: borderSoftColor),
                  for (final utilItem in NavItem.utilityRouteItems)
                    _buildDrawerItem(
                      context,
                      item: utilItem,
                      isSelected: currentRoute == utilItem.keyName,
                      isDark: isDark,
                    ),
                  Divider(height: 20.0, color: borderSoftColor),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    leading: FigmaSidebarIcon(FigmaIconType.folderKanban, size: 16.0, color: textMuted),
                    title: Text(
                      'All Projects',
                      style: TextStyle(fontSize: 12.0, color: textSecondary),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(AppRoutes.workspaceDetailPath(workspaceId));
                    },
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    leading: FigmaSidebarIcon(FigmaIconType.layers3, size: 16.0, color: textMuted),
                    title: Text(
                      'All Workspaces',
                      style: TextStyle(fontSize: 12.0, color: textSecondary),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(AppRoutes.workspaces);
                    },
                  ),
                ],
              ),
            ),

            // Bottom user info & logout
            Container(
              padding: const EdgeInsets.all(13.0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: borderColor, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    name: userName,
                    size: UserAvatarSize.sm,
                    showStatus: true,
                    isOnline: true,
                  ),
                  const SizedBox(width: 9.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userEmail,
                          style: TextStyle(fontSize: 9.5, color: textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.logout_rounded, color: AppColors.errorFor(isDark), size: 18.0),
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
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isSelected)
            Positioned(
              left: -10.0,
              top: 8.0,
              bottom: 8.0,
              child: Container(
                width: 2.0,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(99.0),
                ),
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            onTap: () {
              Navigator.of(context).pop();
              if (!isSelected) {
                context.go(_buildRoute(item.keyName));
              }
            },
            child: Container(
              height: 34.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
              child: Row(
                children: [
                  FigmaSidebarIcon(
                    item.figmaIcon,
                    color: isSelected ? accentColor : AppColors.textMutedFor(isDark),
                    size: 16.0,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? selectedText : unselectedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
