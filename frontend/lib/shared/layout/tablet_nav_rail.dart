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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = AppColors.sidebarFor(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color accentSoftColor = AppColors.accentSoftFor(isDark);

    final String projectInitial =
        projectId.trim().isNotEmpty ? projectId.trim()[0].toUpperCase() : 'P';

    return Container(
      width: 64.0,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // Top brand mark (Figma collapsed .sidebar-brand)
          SizedBox(
            height: 60.0,
            child: Center(
              child: Icon(Icons.layers_rounded, color: accentColor, size: 19.0),
            ),
          ),

          // Compact project monogram badge (Figma collapsed .project-button)
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 10.0),
            child: Tooltip(
              message: 'Switch Project ($projectId)',
              child: InkWell(
                onTap: () => context.go(AppRoutes.workspaceDetailPath(workspaceId)),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFor(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(color: borderColor),
                  ),
                  child: Container(
                    width: 29.0,
                    height: 29.0,
                    decoration: BoxDecoration(
                      color: accentSoftColor,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      projectInitial,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
              children: [
                for (final item in NavItem.projectNavItems) ...[
                  _TabletRailItem(
                    item: item,
                    isSelected: currentRoute == item.keyName,
                    isDark: isDark,
                    onTap: () {
                      if (currentRoute != item.keyName) {
                        context.go(_buildRoute(item.keyName));
                      }
                    },
                  ),
                  const SizedBox(height: 4.0),
                ],
              ],
            ),
          ),

          // Bottom back to workspaces
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSoftFor(isDark), width: 1.0),
              ),
            ),
            child: IconButton(
              tooltip: 'All Workspaces',
              icon: Icon(
                Icons.workspaces_outlined,
                size: 18.0,
                color: AppColors.textMutedFor(isDark),
              ),
              onPressed: () => context.go(AppRoutes.workspaces),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletRailItem extends StatefulWidget {
  final NavItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabletRailItem({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_TabletRailItem> createState() => _TabletRailItemState();
}

class _TabletRailItemState extends State<_TabletRailItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.accentFor(widget.isDark);
    final accentSoft = AppColors.accentSoftFor(widget.isDark);
    final textPrimary = AppColors.textPrimaryFor(widget.isDark);
    final textMuted = AppColors.textMutedFor(widget.isDark);

    final bgColor = widget.isSelected
        ? accentSoft
        : (_isHovered ? AppColors.hoverFor(widget.isDark) : Colors.transparent);
    final iconColor = widget.isSelected
        ? accentColor
        : (_isHovered ? textPrimary : textMuted);

    return Tooltip(
      message: widget.item.label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.isSelected)
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
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 38.0,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.isSelected ? widget.item.selectedIcon : widget.item.icon,
                  size: 17.5,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
