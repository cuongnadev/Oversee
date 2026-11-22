import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/shared/layout/nav_item.dart';
import 'package:frontend/shared/layout/sidebar_provider.dart';
import 'package:frontend/shared/widgets/app_dialog.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Collapsible desktop and wide web navigation sidebar aligned 1:1 with Figma Sidebar
/// (`Layout.tsx` & `app.css` `.sidebar` tokens, active/hover/inactive states, collapsible groups).
class DesktopSidebar extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;

  const DesktopSidebar({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
  });

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  static const _workspaceKeys = {'overview', 'dashboard'};
  static const _planningKeys = {'board', 'backlog', 'sprints'};
  static const _configKeys = {'settings'};

  final Set<String> _closedGroups = <String>{};

  String _buildRoute(String keyName) {
    switch (keyName) {
      case 'overview':
        return AppRoutes.projectOverviewPath(widget.workspaceId, widget.projectId);
      case 'backlog':
        return AppRoutes.projectBacklogPath(widget.workspaceId, widget.projectId);
      case 'board':
        return AppRoutes.projectBoardPath(widget.workspaceId, widget.projectId);
      case 'sprints':
        return AppRoutes.projectSprintsPath(widget.workspaceId, widget.projectId);
      case 'dashboard':
        return AppRoutes.projectDashboardPath(widget.workspaceId, widget.projectId);
      case 'settings':
        return AppRoutes.projectSettingsPath(widget.workspaceId, widget.projectId);
      default:
        return AppRoutes.projectOverviewPath(widget.workspaceId, widget.projectId);
    }
  }

  void _toggleGroup(String title) {
    setState(() {
      if (_closedGroups.contains(title)) {
        _closedGroups.remove(title);
      } else {
        _closedGroups.add(title);
      }
    });
  }

  void _openQuickSearch(BuildContext context) {
    AppAdaptiveDialog.show<void>(
      context,
      title: 'Quick Navigation',
      maxWidth: 480.0,
      child: _SidebarQuickSearchContent(
        workspaceId: widget.workspaceId,
        projectId: widget.projectId,
        currentRoute: widget.currentRoute,
        buildRoute: _buildRoute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpanded = ref.watch(sidebarExpandedProvider);
    final authState = ref.watch(authNotifierProvider);
    final workspaceState = ref.watch(workspaceNotifierProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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

    final activeWorkspace = workspaceState.workspaces
            .where((w) => w.id == widget.workspaceId)
            .firstOrNull ??
        workspaceState.selectedWorkspace;
    final String workspaceLabel = activeWorkspace?.name ?? 'Engineering workspace';
    final String projectLabel = widget.projectId;
    final String projectInitial =
        projectLabel.trim().isNotEmpty ? projectLabel.trim()[0].toUpperCase() : 'P';

    final groups = <(String, List<NavItem>)>[
      (
        'WORKSPACE',
        NavItem.projectNavItems.where((i) => _workspaceKeys.contains(i.keyName)).toList(),
      ),
      (
        'PLANNING',
        NavItem.projectNavItems.where((i) => _planningKeys.contains(i.keyName)).toList(),
      ),
      (
        'CONFIGURATION',
        NavItem.projectNavItems.where((i) => _configKeys.contains(i.keyName)).toList(),
      ),
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
              // 1. Brand header (Figma .sidebar-brand, height: 60px)
              Container(
                height: 60.0,
                padding: EdgeInsets.symmetric(horizontal: isExpanded ? 18.0 : 0.0),
                child: isExpanded
                    ? Row(
                        children: [
                          Icon(Icons.layers_rounded, color: accentColor, size: 19.0),
                          const SizedBox(width: 9.0),
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                text: 'oversee',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontFamilyFallback: AppTypography.fontFallback,
                                  fontSize: 21.0,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.9,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: accentSoftColor,
                              borderRadius: BorderRadius.circular(AppColors.radiusSm),
                            ),
                            child: Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 8.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Icon(Icons.layers_rounded, color: accentColor, size: 19.0),
                      ),
              ),

              // 2. Project Selector Card (Figma .project-selector > .project-button)
              Padding(
                padding: EdgeInsets.fromLTRB(12.0, isExpanded ? 1.0 : 0.0, 12.0, 10.0),
                child: _SidebarProjectButton(
                  projectInitial: projectInitial,
                  projectLabel: projectLabel,
                  workspaceLabel: workspaceLabel,
                  workspaceId: widget.workspaceId,
                  isExpanded: isExpanded,
                  isDark: isDark,
                ),
              ),

              // 3. Sidebar Quick-Search Trigger (Figma .sidebar-search)
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 10.0),
                child: _SidebarSearchTrigger(
                  isExpanded: isExpanded,
                  isDark: isDark,
                  onTap: () => _openQuickSearch(context),
                ),
              ),

              // 4. Collapsible Grouped Navigation (Figma .sidebar-nav)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  children: [
                    for (final (title, items) in groups) ...[
                      if (isExpanded)
                        _SidebarGroupHeading(
                          title: title,
                          isClosed: _closedGroups.contains(title),
                          isDark: isDark,
                          onTap: () => _toggleGroup(title),
                        )
                      else
                        const SizedBox(height: 8.0),
                      if (!_closedGroups.contains(title) || !isExpanded)
                        for (final item in items) ...[
                          _SidebarNavItem(
                            item: item,
                            isSelected: widget.currentRoute == item.keyName,
                            isExpanded: isExpanded,
                            isDark: isDark,
                            onTap: () {
                              if (widget.currentRoute != item.keyName) {
                                context.go(_buildRoute(item.keyName));
                              }
                            },
                          ),
                          const SizedBox(height: 2.0),
                        ],
                      SizedBox(height: isExpanded ? 10.0 : 6.0),
                    ],
                  ],
                ),
              ),

              // 5. Bottom Utility Actions & User Footer (Figma .sidebar-bottom)
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
                    _SidebarUtilityItem(
                      icon: Icons.workspaces_outlined,
                      label: 'All Workspaces',
                      tooltip: 'All Workspaces',
                      isExpanded: isExpanded,
                      isDark: isDark,
                      onTap: () => context.go(AppRoutes.workspaces),
                    ),
                    const SizedBox(height: 2.0),
                    _SidebarUtilityItem(
                      icon: isExpanded
                          ? Icons.keyboard_double_arrow_left_rounded
                          : Icons.keyboard_double_arrow_right_rounded,
                      label: 'Collapse sidebar',
                      tooltip: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
                      shortcut: '[',
                      isExpanded: isExpanded,
                      isDark: isDark,
                      onTap: () {
                        ref.read(sidebarExpandedProvider.notifier).toggleSidebar();
                      },
                    ),
                    const SizedBox(height: 8.0),

                    // User Footer (Figma .sidebar-user)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isExpanded ? 5.0 : 0.0,
                        vertical: 12.0,
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
                                          fontSize: 9.5,
                                          color: textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Account Menu',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  icon: Icon(
                                    Icons.more_horiz_rounded,
                                    size: 16.0,
                                    color: textMuted,
                                  ),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'projects':
                                        context.go(AppRoutes.workspaceDetailPath(widget.workspaceId));
                                        break;
                                      case 'ws-settings':
                                        context.go(
                                          AppRoutes.workspaceSettingsPath(widget.workspaceId),
                                        );
                                        break;
                                      case 'logout':
                                        unawaited(ref.read(authNotifierProvider.notifier).logout());
                                        break;
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'projects',
                                      child: Text('Workspace Projects'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'ws-settings',
                                      child: Text('Workspace Settings'),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'logout',
                                      child: Text(
                                        'Log Out',
                                        style: TextStyle(color: AppColors.errorFor(isDark)),
                                      ),
                                    ),
                                  ],
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
}

/// Figma `.project-button` selector card inside the sidebar.
class _SidebarProjectButton extends StatefulWidget {
  final String projectInitial;
  final String projectLabel;
  final String workspaceLabel;
  final String workspaceId;
  final bool isExpanded;
  final bool isDark;

  const _SidebarProjectButton({
    required this.projectInitial,
    required this.projectLabel,
    required this.workspaceLabel,
    required this.workspaceId,
    required this.isExpanded,
    required this.isDark,
  });

  @override
  State<_SidebarProjectButton> createState() => _SidebarProjectButtonState();
}

class _SidebarProjectButtonState extends State<_SidebarProjectButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.accentFor(widget.isDark);
    final accentSoft = AppColors.accentSoftFor(widget.isDark);
    final borderColor = AppColors.borderFor(widget.isDark);
    final textPrimary = AppColors.textPrimaryFor(widget.isDark);
    final textMuted = AppColors.textMutedFor(widget.isDark);

    final Widget iconSquare = Container(
      width: 29.0,
      height: 29.0,
      decoration: BoxDecoration(
        color: accentSoft,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.projectInitial,
        style: TextStyle(
          color: accentColor,
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final Widget buttonBody = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.all(widget.isExpanded ? 9.0 : 4.0),
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.hoverFor(widget.isDark)
              : AppColors.surfaceFor(widget.isDark),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: _isHovered ? textMuted : borderColor,
            width: 1.0,
          ),
        ),
        child: widget.isExpanded
            ? Row(
                children: [
                  iconSquare,
                  const SizedBox(width: 9.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.projectLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1.0),
                        Text(
                          widget.workspaceLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Icon(Icons.unfold_more_rounded, size: 14.0, color: textMuted),
                ],
              )
            : Center(child: iconSquare),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Switch project',
      offset: const Offset(0, 52),
      onSelected: (action) {
        switch (action) {
          case 'projects':
            context.go(AppRoutes.workspaceDetailPath(widget.workspaceId));
            break;
          case 'ws-settings':
            context.go(AppRoutes.workspaceSettingsPath(widget.workspaceId));
            break;
          case 'workspaces':
            context.go(AppRoutes.workspaces);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 30.0,
          child: Text('PROJECT WORKSPACE', style: AppTypography.eyebrow(widget.isDark)),
        ),
        const PopupMenuItem(
          value: 'projects',
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 15.0),
              SizedBox(width: 8.0),
              Text('Switch Project'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ws-settings',
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 15.0),
              SizedBox(width: 8.0),
              Text('Workspace Settings'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'workspaces',
          child: Row(
            children: [
              Icon(Icons.workspaces_outlined, size: 15.0),
              SizedBox(width: 8.0),
              Text('All Workspaces'),
            ],
          ),
        ),
      ],
      child: buttonBody,
    );
  }
}

/// Figma `.sidebar-search` button with `⌘ K` shortcut badge.
class _SidebarSearchTrigger extends StatefulWidget {
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarSearchTrigger({
    required this.isExpanded,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SidebarSearchTrigger> createState() => _SidebarSearchTriggerState();
}

class _SidebarSearchTriggerState extends State<_SidebarSearchTrigger> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textMuted = AppColors.textMutedFor(widget.isDark);
    final textPrimary = AppColors.textPrimaryFor(widget.isDark);
    final borderColor = AppColors.borderFor(widget.isDark);

    final Widget content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 30.0,
          padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 9.0 : 0.0),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.hoverFor(widget.isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: widget.isExpanded
              ? Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 15.0,
                      color: _isHovered ? textPrimary : textMuted,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        'Quick search...',
                        style: TextStyle(
                          fontSize: 11.0,
                          color: _isHovered ? textPrimary : textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.surface2For(widget.isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        '⌘ K',
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    Icons.search_rounded,
                    size: 15.5,
                    color: _isHovered ? textPrimary : textMuted,
                  ),
                ),
        ),
      ),
    );

    if (!widget.isExpanded) {
      return Tooltip(message: 'Quick search (⌘ K)', child: content);
    }
    return content;
  }
}

/// Figma `.nav-group-heading` collapsible section header with rotating chevron.
class _SidebarGroupHeading extends StatefulWidget {
  final String title;
  final bool isClosed;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarGroupHeading({
    required this.title,
    required this.isClosed,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SidebarGroupHeading> createState() => _SidebarGroupHeadingState();
}

class _SidebarGroupHeadingState extends State<_SidebarGroupHeading> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textMuted = AppColors.textMutedFor(widget.isDark);
    final textSecondary = AppColors.textSecondaryFor(widget.isDark);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 25.0,
          margin: const EdgeInsets.only(bottom: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.hoverFor(widget.isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: _isHovered ? textSecondary : textMuted,
                ),
              ),
              AnimatedRotation(
                turns: widget.isClosed ? -0.25 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 13.0,
                  color: _isHovered ? textSecondary : textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma `.nav-item` with exact active left-bar, hover surface, icon, and shortcut hint.
class _SidebarNavItem extends StatefulWidget {
  final NavItem item;
  final bool isSelected;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.accentFor(widget.isDark);
    final accentSoft = AppColors.accentSoftFor(widget.isDark);
    final hoverBg = AppColors.hoverFor(widget.isDark);
    final textPrimary = AppColors.textPrimaryFor(widget.isDark);
    final textSecondary = AppColors.textSecondaryFor(widget.isDark);
    final textMuted = AppColors.textMutedFor(widget.isDark);

    final Color bgColor = widget.isSelected
        ? accentSoft
        : (_isHovered ? hoverBg : Colors.transparent);
    final Color iconColor = widget.isSelected
        ? accentColor
        : (_isHovered ? textPrimary : textMuted);
    final Color labelColor = widget.isSelected
        ? textPrimary
        : (_isHovered ? textPrimary : textSecondary);

    final Widget rowContent = Stack(
      clipBehavior: Clip.none,
      children: [
        // Figma .nav-item.active::before (2px left accent pill at left: -10px)
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
              height: widget.isExpanded ? 32.0 : 35.0,
              padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 10.0 : 0.0),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
              child: widget.isExpanded
                  ? Row(
                      children: [
                        Icon(
                          widget.isSelected ? widget.item.selectedIcon : widget.item.icon,
                          size: 16.0,
                          color: iconColor,
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            widget.item.label,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: labelColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.item.shortcut != null)
                          Text(
                            widget.item.shortcut!,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w500,
                              color: widget.isSelected
                                  ? accentColor.withValues(alpha: 0.8)
                                  : (_isHovered ? textSecondary : textMuted),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        widget.isSelected ? widget.item.selectedIcon : widget.item.icon,
                        size: 16.5,
                        color: iconColor,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );

    if (!widget.isExpanded) {
      final tip = widget.item.shortcut != null
          ? '${widget.item.label} · ${widget.item.shortcut}'
          : widget.item.label;
      return Tooltip(message: tip, child: rowContent);
    }

    return rowContent;
  }
}

/// Figma `.sidebar-bottom .nav-item` compact utility action row.
class _SidebarUtilityItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final String? shortcut;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarUtilityItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.shortcut,
    required this.isExpanded,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SidebarUtilityItem> createState() => _SidebarUtilityItemState();
}

class _SidebarUtilityItemState extends State<_SidebarUtilityItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryFor(widget.isDark);
    final textSecondary = AppColors.textSecondaryFor(widget.isDark);
    final textMuted = AppColors.textMutedFor(widget.isDark);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 28.0,
            padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 10.0 : 0.0),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.hoverFor(widget.isDark) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
            child: widget.isExpanded
                ? Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: 15.0,
                        color: _isHovered ? textPrimary : textMuted,
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                            color: _isHovered ? textPrimary : textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.shortcut != null)
                        Text(
                          widget.shortcut!,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                            color: _isHovered ? textSecondary : textMuted,
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Icon(
                      widget.icon,
                      size: 16.0,
                      color: _isHovered ? textPrimary : textMuted,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight command palette dialog launched from `.sidebar-search`.
class _SidebarQuickSearchContent extends StatefulWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;
  final String Function(String keyName) buildRoute;

  const _SidebarQuickSearchContent({
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
    required this.buildRoute,
  });

  @override
  State<_SidebarQuickSearchContent> createState() => _SidebarQuickSearchContentState();
}

class _SidebarQuickSearchContentState extends State<_SidebarQuickSearchContent> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final destinations = <(String, IconData, String, String?)>[
      for (final item in NavItem.projectNavItems)
        (item.label, item.icon, widget.buildRoute(item.keyName), item.shortcut),
      (
        'Workspace Projects',
        Icons.folder_outlined,
        AppRoutes.workspaceDetailPath(widget.workspaceId),
        null,
      ),
      (
        'All Workspaces',
        Icons.workspaces_outlined,
        AppRoutes.workspaces,
        null,
      ),
    ].where((entry) => entry.$1.toLowerCase().contains(_query.trim().toLowerCase())).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          onChanged: (val) => setState(() => _query = val),
          style: TextStyle(fontSize: 13.0, color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Jump to page...',
            prefixIcon: Icon(Icons.search_rounded, size: 17.0, color: accentColor),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12.0),
        if (destinations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: Text(
                'No matching pages.',
                style: TextStyle(fontSize: 12.0, color: textMuted),
              ),
            ),
          )
        else
          for (final (label, icon, path, shortcut) in destinations)
            InkWell(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              hoverColor: accentSoft,
              onTap: () {
                Navigator.of(context).pop();
                context.go(path);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
                child: Row(
                  children: [
                    Icon(icon, size: 16.0, color: textMuted),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (shortcut != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.surface2For(isDark),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          shortcut,
                          style: TextStyle(fontSize: 9.0, color: textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
