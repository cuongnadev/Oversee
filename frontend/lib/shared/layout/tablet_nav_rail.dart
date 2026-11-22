import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/layout/nav_item.dart';

/// Navigation rail for tablet screens (600px - 1024px) aligned with Figma collapsed sidebar.
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
    final Color bgColor = AppColors.sidebarFor(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color accentSoftColor = AppColors.accentSoftFor(isDark);

    return Container(
      width: 68.0,
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
                bottom: BorderSide(color: AppColors.borderSoftFor(isDark), width: 1.0),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(7.0),
              decoration: BoxDecoration(
                color: accentSoftColor,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: accentColor.withValues(alpha: 0.22)),
              ),
              child: Icon(Icons.layers_rounded, color: accentColor, size: 19.0),
            ),
          ),

          // Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
              children: [
                for (final item in NavItem.projectNavItems) ...[
                  _buildRailItem(
                    context,
                    item: item,
                    isSelected: currentRoute == item.keyName,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 5.0),
                ],
              ],
            ),
          ),

          // Bottom back to workspaces
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSoftFor(isDark), width: 1.0),
              ),
            ),
            child: IconButton(
              tooltip: 'All Workspaces',
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 19.0,
                color: AppColors.textMutedFor(isDark),
              ),
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
    final Color selectedBg = AppColors.accentSoftFor(isDark);
    final Color selectedColor = AppColors.accentFor(isDark);
    final Color unselectedColor = AppColors.textMutedFor(isDark);

    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            context.go(_buildRoute(item.keyName));
          }
        },
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        hoverColor: AppColors.hoverFor(isDark),
        child: Container(
          height: 46.0,
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                size: 18.5,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              const SizedBox(height: 3.0),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 9.5,
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
