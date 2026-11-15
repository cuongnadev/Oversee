import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/layout/nav_item.dart';

/// Navigation rail for tablet screens (600px - 1024px).
class TabletNavRail extends StatelessWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;

  const TabletNavRail({
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
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final Color borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      width: 72.0,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // Top logo
          Container(
            height: 60.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20.0),
            ),
          ),

          // Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              children: [
                for (final item in NavItem.projectNavItems) ...[
                  _buildRailItem(
                    context,
                    item: item,
                    isSelected: currentRoute == item.keyName,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6.0),
                ],
              ],
            ),
          ),

          // Bottom back to workspaces
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
            child: IconButton(
              tooltip: 'All Workspaces',
              icon: const Icon(Icons.arrow_back_rounded, size: 20.0),
              onPressed: () => context.go(AppRoutes.workspaces),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailItem(
    BuildContext context, {
    required NavItem item,
    required bool isSelected,
    required bool isDark,
  }) {
    final Color selectedBg = AppColors.primary.withValues(alpha: 0.12);
    const Color selectedColor = AppColors.primary;
    final Color unselectedColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            context.go(_buildRoute(item.keyName));
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          height: 48.0,
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                size: 20.0,
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
      ),
    );
  }
}
