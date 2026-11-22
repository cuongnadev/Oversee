import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/shared/layout/nav_item.dart';
import 'package:frontend/shared/layout/sidebar_provider.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Collapsible desktop and wide web navigation sidebar aligned with Figma Sidebar.
class DesktopSidebar extends ConsumerWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;

  const DesktopSidebar({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
  });

  static const _workspaceKeys = {'overview', 'dashboard'};
  static const _planningKeys = {'board', 'backlog', 'sprints'};
  static const _configKeys = {'settings'};

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
    final bool isExpanded = ref.watch(sidebarExpandedProvider);
    final authState = ref.watch(authNotifierProvider);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color bgColor = AppColors.sidebarFor(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color borderSoftColor = AppColors.borderSoftFor(isDark);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color accentSoftColor = AppColors.accentSoftFor(isDark);
    final Color textPrimary = AppColors.textPrimaryFor(isDark);
    final Color textMuted = AppColors.textMutedFor(isDark);

    final String userEmail = authState.email ?? 'user@oversee.local';
    final String? fullName = authState.user?.fullName;
    final String userName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : userEmail.split('@').first.replaceAll('.', ' ');

    final groups = <(String, List<NavItem>)>[
      ('WORKSPACE', NavItem.projectNavItems.where((i) => _workspaceKeys.contains(i.keyName)).toList()),
      ('PLANNING', NavItem.projectNavItems.where((i) => _planningKeys.contains(i.keyName)).toList()),
      ('CONFIGURATION', NavItem.projectNavItems.where((i) => _configKeys.contains(i.keyName)).toList()),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      clipBehavior: Clip.hardEdge,
      width: isExpanded ? 240.0 : 64.0,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: OverflowBox(
        minWidth: 64.0,
        maxWidth: 240.0,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: isExpanded ? 240.0 : 64.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand header (Figma .sidebar-brand)
              Container(
                height: 60.0,
                padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16.0 : 8.0),
                child: Row(
                  mainAxisAlignment: isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                  children: [
                    if (isExpanded)
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.layers_rounded, color: accentColor, size: 20.0),
                            const SizedBox(width: 8.0),
                            Flexible(
                              child: RichText(
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  text: 'oversee',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontFamilyFallback: AppTypography.fontFallback,
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
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
                            ),
                            const SizedBox(width: 8.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: accentSoftColor,
                                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                              ),
                              child: Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    AppIconButton(
                      tooltip: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
                      icon: isExpanded
                          ? Icons.keyboard_double_arrow_left_rounded
                          : Icons.keyboard_double_arrow_right_rounded,
                      size: 30.0,
                      color: textMuted,
                      onPressed: () {
                        ref.read(sidebarExpandedProvider.notifier).toggleSidebar();
                      },
                    ),
                  ],
                ),
              ),

              // Grouped navigation items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                  children: [
                    for (final (title, items) in groups) ...[
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 5.0),
                          child: Text(
                            title,
                            style: AppTypography.eyebrow(isDark).copyWith(fontSize: 9.5),
                          ),
                        )
                      else
                        const SizedBox(height: 8.0),
                      for (final item in items) ...[
                        _buildNavItem(
                          context,
                          item: item,
                          isSelected: currentRoute == item.keyName,
                          isExpanded: isExpanded,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 2.0),
                      ],
                    ],
                  ],
                ),
              ),

              // Bottom workspace switch & user section (Figma .sidebar-bottom)
              Container(
                padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 0.0),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: borderSoftColor, width: 1.0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isExpanded)
                      InkWell(
                        onTap: () => context.go(AppRoutes.workspaces),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back_rounded, size: 15.0, color: textMuted),
                              const SizedBox(width: 9.0),
                              Expanded(
                                child: Text(
                                  'All Workspaces',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondaryFor(isDark),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Center(
                        child: AppIconButton(
                          tooltip: 'All Workspaces',
                          icon: Icons.arrow_back_rounded,
                          size: 32.0,
                          color: textMuted,
                          onPressed: () => context.go(AppRoutes.workspaces),
                        ),
                      ),
                    const SizedBox(height: 6.0),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isExpanded ? 6.0 : 0.0,
                        vertical: 11.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: borderColor, width: 1.0),
                        ),
                      ),
                      child: isExpanded
                          ? Row(
                              children: [
                                UserAvatar(
                                  name: userName,
                                  size: UserAvatarSize.sm,
                                  showStatus: true,
                                  isOnline: true,
                                  showTooltip: false,
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
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        userEmail,
                                        style: TextStyle(
                                          fontSize: 10.0,
                                          color: textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: UserAvatar(
                                name: userName,
                                size: UserAvatarSize.sm,
                                showStatus: true,
                                isOnline: true,
                              ),
                            ),
                    ),
                  ],
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
    required bool isExpanded,
    required bool isDark,
  }) {
    final Color selectedBg = AppColors.accentSoftFor(isDark);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color selectedText = AppColors.textPrimaryFor(isDark);
    final Color unselectedIcon = AppColors.textMutedFor(isDark);
    final Color unselectedText = AppColors.textSecondaryFor(isDark);

    final Widget buttonChild = Stack(
      clipBehavior: Clip.none,
      children: [
        if (isSelected)
          Positioned(
            left: -10.0,
            top: 7.0,
            bottom: 7.0,
            child: Container(
              width: 2.5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(99.0),
              ),
            ),
          ),
        InkWell(
          onTap: () {
            if (!isSelected) {
              context.go(_buildRoute(item.keyName));
            }
          },
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          hoverColor: AppColors.hoverFor(isDark),
          child: Container(
            height: 34.0,
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 10.0 : 0.0,
            ),
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
            child: isExpanded
                ? Row(
                    children: [
                      Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        size: 16.5,
                        color: isSelected ? accentColor : unselectedIcon,
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? selectedText : unselectedText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      size: 18.0,
                      color: isSelected ? accentColor : unselectedIcon,
                    ),
                  ),
          ),
        ),
      ],
    );

    if (!isExpanded) {
      return Tooltip(
        message: item.label,
        child: buttonChild,
      );
    }

    return buttonChild;
  }
}
