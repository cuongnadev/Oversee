import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/project/presentation/widgets/create_project_dialog.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/shared/layout/nav_item.dart';
import 'package:frontend/shared/layout/sidebar_icons.dart';
import 'package:frontend/shared/layout/sidebar_provider.dart';
import 'package:frontend/shared/widgets/app_dialog.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Collapsible desktop and wide web navigation sidebar matching
/// `frontend/lib/references/figma-source/src/components/Layout.tsx` & `src/styles/app.css`
/// pixel-for-pixel (240px/64px width, 64px brand bar, project selector dropdown,
/// quick search trigger, collapsible nav groups, Lucide 1.6px stroke icons,
/// exact active/hover/inactive states, bottom utility actions, and user footer).
class DesktopSidebar extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;
  final String? projectName;

  const DesktopSidebar({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
    this.projectName,
  });

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  static const _workspaceKeys = {'overview', 'dashboard'};
  static const _planningKeys = {'board', 'backlog', 'sprints', 'planning'};
  static const _configKeys = {'team', 'settings'};

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
      case 'planning':
        return AppRoutes.projectSprintPlanningPath(widget.workspaceId, widget.projectId);
      case 'dashboard':
        return AppRoutes.projectDashboardPath(widget.workspaceId, widget.projectId);
      case 'team':
        return AppRoutes.workspaceSettingsPath(widget.workspaceId);
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

  void _openProjectSwitcher(
    BuildContext context, {
    required String projectLabel,
    required String workspaceLabel,
  }) {
    AppAdaptiveDialog.show<void>(
      context,
      title: 'Your Projects',
      maxWidth: 420.0,
      child: _SidebarProjectPickerModal(
        workspaceId: widget.workspaceId,
        projectId: widget.projectId,
        projectLabel: projectLabel,
        workspaceLabel: workspaceLabel,
        onCreateProject: () {
          Navigator.of(context).pop();
          CreateProjectDialog.show(context, workspaceId: widget.workspaceId);
        },
      ),
    );
  }

  void _openCommandPalette(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x9908080C),
      builder: (dialogContext) {
        return _SidebarCommandPaletteDialog(
          workspaceId: widget.workspaceId,
          projectId: widget.projectId,
          buildRoute: _buildRoute,
          onToggleTheme: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          onCreateProject: () => CreateProjectDialog.show(context, workspaceId: widget.workspaceId),
        );
      },
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
    final String userRoleLabel = activeWorkspace?.userRole.label ?? userEmail;

    final String projectLabel =
        (widget.projectName != null && widget.projectName!.trim().isNotEmpty)
            ? widget.projectName!.trim()
            : widget.projectId;
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
      curve: Curves.ease,
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
              // 1. Brand header (Figma .sidebar-brand: height 64px, padding 0 20px, gap 9px)
              Container(
                height: 64.0,
                padding: EdgeInsets.symmetric(horizontal: isExpanded ? 20.0 : 22.0),
                child: isExpanded
                    ? Row(
                        children: [
                          FigmaSidebarIcon(
                            FigmaIconType.layers3,
                            size: 19.0,
                            color: accentColor,
                            strokeWidth: 1.75,
                          ),
                          const SizedBox(width: 9.0),
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                text: 'oversee',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontFamilyFallback: AppTypography.fontFallback,
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.w600,
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
                                height: 1.5,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: FigmaSidebarIcon(
                          FigmaIconType.layers3,
                          size: 19.0,
                          color: accentColor,
                          strokeWidth: 1.75,
                        ),
                      ),
              ),

              // 2. Project selector (Figma .project-selector: padding 1px 12px 10px)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12.0,
                  isExpanded ? 1.0 : 0.0,
                  12.0,
                  isExpanded ? 10.0 : 8.0,
                ),
                child: _SidebarProjectButton(
                  projectInitial: projectInitial,
                  projectLabel: projectLabel,
                  workspaceLabel: workspaceLabel,
                  isExpanded: isExpanded,
                  isDark: isDark,
                  onTap: () => _openProjectSwitcher(
                    context,
                    projectLabel: projectLabel,
                    workspaceLabel: workspaceLabel,
                  ),
                ),
              ),

              // 3. Quick search trigger (Figma .sidebar-search: margin 0 12px 10px)
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 10.0),
                child: _SidebarSearchTrigger(
                  isExpanded: isExpanded,
                  isDark: isDark,
                  onTap: () => _openCommandPalette(context),
                ),
              ),

              // 4. Collapsible grouped navigation (Figma .sidebar-nav: padding 0 10px)
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
                        ),
                      if (!_closedGroups.contains(title) || !isExpanded)
                        for (final item in items)
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
                      SizedBox(height: isExpanded ? 12.0 : 14.0),
                    ],
                  ],
                ),
              ),

              // 5. Bottom utility section & user footer (Figma .sidebar-bottom)
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
                      icon: FigmaIconType.bookOpen,
                      label: 'All Projects',
                      tooltip: 'All Projects',
                      isExpanded: isExpanded,
                      isDark: isDark,
                      onTap: () => context.go(AppRoutes.workspaceDetailPath(widget.workspaceId)),
                    ),
                    _SidebarUtilityItem(
                      icon: FigmaIconType.terminal,
                      label: 'All Workspaces',
                      tooltip: 'All Workspaces',
                      badgeText: 'WS',
                      isExpanded: isExpanded,
                      isDark: isDark,
                      onTap: () => context.go(AppRoutes.workspaces),
                    ),
                    _SidebarUtilityItem(
                      icon: isExpanded
                          ? FigmaIconType.panelLeftClose
                          : FigmaIconType.panelLeftOpen,
                      label: 'Collapse sidebar',
                      tooltip: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
                      shortcut: '[',
                      isExpanded: isExpanded,
                      isDark: isDark,
                      onTap: () {
                        ref.read(sidebarExpandedProvider.notifier).toggleSidebar();
                      },
                    ),

                    // User footer (Figma .sidebar-user: margin-top 8px, padding 13px 5px)
                    Container(
                      margin: const EdgeInsets.only(top: 8.0),
                      padding: EdgeInsets.symmetric(
                        horizontal: isExpanded ? 5.0 : 0.0,
                        vertical: 13.0,
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
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        userRoleLabel,
                                        style: TextStyle(
                                          fontSize: 9.0,
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
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  icon: FigmaSidebarIcon(
                                    FigmaIconType.moreHorizontal,
                                    size: 16.0,
                                    color: textMuted,
                                  ),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'projects':
                                        context.go(
                                          AppRoutes.workspaceDetailPath(widget.workspaceId),
                                        );
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
                                    PopupMenuItem<String>(
                                      enabled: false,
                                      height: 30.0,
                                      child: Text(
                                        userEmail,
                                        style: TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.6,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
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

/// Figma `.project-button` selector card.
class _SidebarProjectButton extends StatefulWidget {
  final String projectInitial;
  final String projectLabel;
  final String workspaceLabel;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarProjectButton({
    required this.projectInitial,
    required this.projectLabel,
    required this.workspaceLabel,
    required this.isExpanded,
    required this.isDark,
    required this.onTap,
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
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
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

    final Widget body = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
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
                              fontSize: 11.0,
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
                              fontSize: 9.0,
                              color: textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    FigmaSidebarIcon(
                      FigmaIconType.chevronsUpDown,
                      size: 13.0,
                      color: textMuted,
                    ),
                  ],
                )
              : Center(child: iconSquare),
        ),
      ),
    );

    return Tooltip(
      message: 'Select project',
      child: body,
    );
  }
}

/// Figma `.sidebar-search` button with `⌘ K` `<kbd>` pill.
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

    final Widget trigger = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 30.0,
          padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 9.0 : 0.0),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.hoverFor(widget.isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: widget.isExpanded
              ? Row(
                  children: [
                    FigmaSidebarIcon(
                      FigmaIconType.search,
                      size: 15.0,
                      color: _isHovered ? textPrimary : textMuted,
                    ),
                    const SizedBox(width: 7.0),
                    Expanded(
                      child: Text(
                        'Search anything',
                        style: TextStyle(
                          fontSize: 11.0,
                          color: _isHovered ? textPrimary : textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
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
                  child: FigmaSidebarIcon(
                    FigmaIconType.search,
                    size: 15.0,
                    color: _isHovered ? textPrimary : textMuted,
                  ),
                ),
        ),
      ),
    );

    return Tooltip(
      message: 'Search · Ctrl K',
      child: trigger,
    );
  }
}

/// Figma `.nav-group-heading` collapsible section button (`9px`, `1.2px` tracking, rotating chevron).
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
    final textPrimary = AppColors.textPrimaryFor(widget.isDark);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
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
                  color: _isHovered ? textPrimary : textMuted,
                ),
              ),
              AnimatedRotation(
                turns: widget.isClosed ? -0.25 : 0.0,
                duration: const Duration(milliseconds: 160),
                child: FigmaSidebarIcon(
                  FigmaIconType.chevronDown,
                  size: 11.0,
                  color: _isHovered ? textPrimary : textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma `.nav-item` matching exact active/hover/inactive CSS tokens & 2px left accent bar.
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

    final Color bgColor =
        widget.isSelected ? accentSoft : (_isHovered ? hoverBg : Colors.transparent);
    final Color iconColor =
        widget.isSelected ? accentColor : (_isHovered ? textPrimary : textMuted);
    final Color labelColor =
        widget.isSelected ? textPrimary : (_isHovered ? textPrimary : textSecondary);

    final Widget navRow = Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Figma `.nav-item.active::before`
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
                duration: const Duration(milliseconds: 160),
                height: widget.isExpanded ? 32.0 : 35.0,
                padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 10.0 : 0.0),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: widget.isExpanded
                    ? Row(
                        children: [
                          FigmaSidebarIcon(
                            widget.item.figmaIcon,
                            size: 16.0,
                            color: iconColor,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              widget.item.label,
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                                color: labelColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.item.shortcut != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
                              child: Text(
                                widget.item.shortcut!,
                                style: TextStyle(
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isSelected
                                      ? accentColor.withValues(alpha: 0.85)
                                      : textMuted,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: FigmaSidebarIcon(
                          widget.item.figmaIcon,
                          size: 16.0,
                          color: iconColor,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.isExpanded) {
      final tip = widget.item.shortcut != null
          ? '${widget.item.label} · ${widget.item.shortcut}'
          : widget.item.label;
      return Tooltip(message: tip, child: navRow);
    }

    return navRow;
  }
}

/// Figma `.sidebar-bottom .nav-item` compact action row (`min-height: 28px`, `font-size: 10px`).
class _SidebarUtilityItem extends StatefulWidget {
  final FigmaIconType icon;
  final String label;
  final String tooltip;
  final String? shortcut;
  final String? badgeText;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarUtilityItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.shortcut,
    this.badgeText,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: widget.isExpanded ? 28.0 : 35.0,
              padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 10.0 : 0.0),
              decoration: BoxDecoration(
                color: _isHovered ? AppColors.hoverFor(widget.isDark) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
              child: widget.isExpanded
                  ? Row(
                      children: [
                        FigmaSidebarIcon(
                          widget.icon,
                          size: 15.0,
                          color: _isHovered ? textPrimary : textMuted,
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: _isHovered ? textPrimary : textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: AppColors.surface3For(widget.isDark),
                              borderRadius: BorderRadius.circular(AppColors.radiusSm),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                          )
                        else if (widget.shortcut != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
                            child: Text(
                              widget.shortcut!,
                              style: TextStyle(
                                fontSize: 8.0,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: FigmaSidebarIcon(
                        widget.icon,
                        size: 15.0,
                        color: _isHovered ? textPrimary : textMuted,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma `.project-selector` searchable dropdown modal (`Layout.tsx:157-193`).
class _SidebarProjectPickerModal extends StatefulWidget {
  final String workspaceId;
  final String projectId;
  final String projectLabel;
  final String workspaceLabel;
  final VoidCallback onCreateProject;

  const _SidebarProjectPickerModal({
    required this.workspaceId,
    required this.projectId,
    required this.projectLabel,
    required this.workspaceLabel,
    required this.onCreateProject,
  });

  @override
  State<_SidebarProjectPickerModal> createState() => _SidebarProjectPickerModalState();
}

class _SidebarProjectPickerModalState extends State<_SidebarProjectPickerModal> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final initial = widget.projectLabel.trim().isNotEmpty
        ? widget.projectLabel.trim()[0].toUpperCase()
        : 'P';

    final showCurrent =
        _search.trim().isEmpty || widget.projectLabel.toLowerCase().contains(_search.toLowerCase());

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('CURRENT WORKSPACE · ${widget.workspaceLabel.toUpperCase()}',
            style: AppTypography.eyebrow(isDark)),
        const SizedBox(height: 10.0),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          style: TextStyle(fontSize: 12.0, color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Search projects…',
            isDense: true,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10.0),
              child: FigmaSidebarIcon(FigmaIconType.search, size: 14.0, color: textMuted),
            ),
          ),
        ),
        const SizedBox(height: 10.0),
        if (showCurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  width: 21.0,
                  height: 21.0,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFor(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w600, color: accentColor),
                  ),
                ),
                const SizedBox(width: 9.0),
                Expanded(
                  child: Text(
                    widget.projectLabel,
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFor(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: accentColor),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Divider(height: 1.0, color: borderColor),
        ),
        _PickerActionTile(
          icon: FigmaIconType.folderKanban,
          label: 'All Workspace Projects',
          isDark: isDark,
          onTap: () {
            Navigator.of(context).pop();
            context.go(AppRoutes.workspaceDetailPath(widget.workspaceId));
          },
        ),
        _PickerActionTile(
          icon: FigmaIconType.plus,
          label: 'Create New Project',
          isDark: isDark,
          accentHighlight: true,
          onTap: widget.onCreateProject,
        ),
        _PickerActionTile(
          icon: FigmaIconType.layers3,
          label: 'Switch Workspace',
          isDark: isDark,
          textColor: textSecondary,
          onTap: () {
            Navigator.of(context).pop();
            context.go(AppRoutes.workspaces);
          },
        ),
      ],
    );
  }
}

class _PickerActionTile extends StatelessWidget {
  final FigmaIconType icon;
  final String label;
  final bool isDark;
  final bool accentHighlight;
  final Color? textColor;
  final VoidCallback onTap;

  const _PickerActionTile({
    required this.icon,
    required this.label,
    required this.isDark,
    this.accentHighlight = false,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentHighlight
        ? AppColors.accentFor(isDark)
        : (textColor ?? AppColors.textPrimaryFor(isDark));

    return InkWell(
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      hoverColor: AppColors.hoverFor(isDark),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
        child: Row(
          children: [
            FigmaSidebarIcon(icon, size: 15.0, color: color),
            const SizedBox(width: 9.0),
            Text(
              label,
              style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma `.command-modal` quick command palette launched from `.sidebar-search`.
class _SidebarCommandPaletteDialog extends StatefulWidget {
  final String workspaceId;
  final String projectId;
  final String Function(String keyName) buildRoute;
  final VoidCallback onToggleTheme;
  final VoidCallback onCreateProject;

  const _SidebarCommandPaletteDialog({
    required this.workspaceId,
    required this.projectId,
    required this.buildRoute,
    required this.onToggleTheme,
    required this.onCreateProject,
  });

  @override
  State<_SidebarCommandPaletteDialog> createState() => _SidebarCommandPaletteDialogState();
}

class _SidebarCommandPaletteDialogState extends State<_SidebarCommandPaletteDialog> {
  String _query = '';
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final allItems = <(String, String, FigmaIconType, String?, VoidCallback)>[
      (
        'Quick Actions',
        'Create New Project',
        FigmaIconType.plus,
        null,
        () {
          Navigator.of(context).pop();
          widget.onCreateProject();
        },
      ),
      (
        'Quick Actions',
        'Toggle Light / Dark Theme',
        FigmaIconType.settings2,
        null,
        () {
          Navigator.of(context).pop();
          widget.onToggleTheme();
        },
      ),
      for (final item in NavItem.projectNavItems)
        (
          'Pages',
          'Open ${item.label}',
          item.figmaIcon,
          item.shortcut,
          () {
            Navigator.of(context).pop();
            context.go(widget.buildRoute(item.keyName));
          },
        ),
      (
        'Workspaces',
        'All Workspace Projects',
        FigmaIconType.folderKanban,
        null,
        () {
          Navigator.of(context).pop();
          context.go(AppRoutes.workspaceDetailPath(widget.workspaceId));
        },
      ),
      (
        'Workspaces',
        'All Workspaces',
        FigmaIconType.layers3,
        null,
        () {
          Navigator.of(context).pop();
          context.go(AppRoutes.workspaces);
        },
      ),
    ];

    final filtered = allItems
        .where((e) => e.$2.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList();

    return Dialog(
      backgroundColor: AppColors.surfaceFor(isDark),
      elevation: 0,
      alignment: const Alignment(0, -0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        side: BorderSide(color: borderColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580.0, maxHeight: 480.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .command-input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  FigmaSidebarIcon(FigmaIconType.search, size: 18.0, color: accentColor),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setState(() {
                        _query = val;
                        _activeIndex = 0;
                      }),
                      onSubmitted: (_) {
                        if (filtered.isNotEmpty) {
                          filtered[_activeIndex.clamp(0, filtered.length - 1)].$5();
                        }
                      },
                      style: TextStyle(fontSize: 13.5, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search pages, workspaces, or commands…',
                        hintStyle: TextStyle(fontSize: 13.5, color: textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // .command-results
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Center(
                        child: Text(
                          'No matching commands or pages.',
                          style: TextStyle(fontSize: 12.0, color: textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        final showSection = i == 0 || filtered[i - 1].$1 != item.$1;
                        final isActive = i == _activeIndex;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showSection)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 4.0),
                                child: Text(
                                  item.$1.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                            MouseRegion(
                              onEnter: (_) => setState(() => _activeIndex = i),
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: item.$5,
                                child: Container(
                                  height: 36.0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                  decoration: BoxDecoration(
                                    color: isActive ? accentSoft : Colors.transparent,
                                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                  ),
                                  child: Row(
                                    children: [
                                      FigmaSidebarIcon(
                                        item.$3,
                                        size: 15.0,
                                        color: isActive ? accentColor : textMuted,
                                      ),
                                      const SizedBox(width: 10.0),
                                      Expanded(
                                        child: Text(
                                          item.$2,
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w500,
                                            color: isActive ? textPrimary : textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.$4 != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5.0,
                                            vertical: 1.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface2For(isDark),
                                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                            border: Border.all(color: borderColor),
                                          ),
                                          child: Text(
                                            item.$4!,
                                            style: TextStyle(fontSize: 9.0, color: textMuted),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // .command-footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  _KbdHint(keys: 'Enter', label: 'select', isDark: isDark),
                  const SizedBox(width: 14.0),
                  _KbdHint(keys: 'Esc', label: 'close', isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KbdHint extends StatelessWidget {
  final String keys;
  final String label;
  final bool isDark;

  const _KbdHint({
    required this.keys,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = AppColors.textMutedFor(isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
          decoration: BoxDecoration(
            color: AppColors.surface2For(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            border: Border.all(color: AppColors.borderFor(isDark)),
          ),
          child: Text(keys, style: TextStyle(fontSize: 9.5, color: textMuted)),
        ),
        const SizedBox(width: 5.0),
        Text(label, style: TextStyle(fontSize: 10.0, color: AppColors.textSecondaryFor(isDark))),
      ],
    );
  }
}
