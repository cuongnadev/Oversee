import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/layout/nav_item.dart';
import 'package:frontend/shared/layout/sidebar_provider.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';

/// Collapsible desktop and wide web navigation sidebar.
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final Color borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      clipBehavior: Clip.hardEdge,
      width: isExpanded ? 260.0 : 72.0,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: OverflowBox(
        minWidth: 72.0,
        maxWidth: 260.0,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: isExpanded ? 260.0 : 72.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sidebar Top Brand & Toggle
              Container(
                height: 60.0,
                padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16.0 : 8.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                  children: [
                    if (isExpanded) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20.0),
                          ),
                          const SizedBox(width: 10.0),
                          Text(
                            'Oversee',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 17.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                    AppIconButton(
                      tooltip: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
                      icon: isExpanded
                          ? Icons.keyboard_double_arrow_left_rounded
                          : Icons.keyboard_double_arrow_right_rounded,
                      size: 32.0,
                      onPressed: () {
                        ref.read(sidebarExpandedProvider.notifier).toggleSidebar();
                      },
                    ),
                  ],
                ),
              ),

              // Project navigation items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  children: [
                    for (final item in NavItem.projectNavItems) ...[
                      _buildNavItem(
                        context,
                        item: item,
                        isSelected: currentRoute == item.keyName,
                        isExpanded: isExpanded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 4.0),
                    ],
                  ],
                ),
              ),

              // Bottom workspace switch / collapse section
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1.0),
                  ),
                ),
                child: isExpanded
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: () => context.go(AppRoutes.workspaces),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18.0),
                        label: const Text(
                          'All Workspaces',
                          style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Center(
                        child: AppIconButton(
                          tooltip: 'All Workspaces',
                          icon: Icons.arrow_back_rounded,
                          size: 32.0,
                          onPressed: () => context.go(AppRoutes.workspaces),
                        ),
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
    final Color selectedBg = AppColors.primary.withValues(alpha: 0.12);
    const Color selectedColor = AppColors.primary;
    final Color unselectedColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final Widget buttonChild = InkWell(
      onTap: () {
        if (!isSelected) {
          context.go(_buildRoute(item.keyName));
        }
      },
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        height: 42.0,
        padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 12.0 : 0.0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: isExpanded
            ? Row(
                children: [
                  Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    size: 20.0,
                    color: isSelected ? selectedColor : unselectedColor,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? selectedColor : unselectedColor,
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
                  size: 20.0,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
              ),
      ),
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
