import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/l10n/locale_provider.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/features/project/application/project_overview_provider.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/workspace_switcher_dropdown.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Top Bar / App Header for Oversee Shell aligned with Figma Topbar (node 1:323).
/// Responsive across Mobile (<600px), Tablet (600-1024px), and Desktop (>1024px).
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String workspaceId;
  final String? projectId;
  final String? projectName;
  final String? currentViewTitle;
  final VoidCallback? onMenuToggle;

  const AppHeader({
    super.key,
    required this.workspaceId,
    this.projectId,
    this.projectName,
    this.currentViewTitle,
    this.onMenuToggle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  void _openQuickCommand(BuildContext context) {
    showAnimatedDialog<void>(
      context: context,
      barrierColor: const Color(0x8808080C),
      builder: (dialogContext) {
        return _TopbarQuickCommandDialog(
          workspaceId: workspaceId,
          projectId: projectId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final bool isDark = theme.brightness == Brightness.dark;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isMobile = ResponsiveBreakpoints.isMobile(context);
    final bool isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final bool showFullSearch = screenWidth >= 1060;
    final bool showSecondaryIcons = screenWidth >= 520;

    final authState = ref.watch(authNotifierProvider);
    final activeSeedColor = ref.watch(seedColorProvider);
    final activeLocale = ref.watch(localeProvider);

    String? resolvedProjectName = (projectName != null && projectName!.trim().isNotEmpty)
        ? projectName!.trim()
        : null;
    if (resolvedProjectName == null && projectId != null && authState.isAuthenticated) {
      final List<ProjectModel> workspaceProjects =
          ref.watch(projectListNotifierProvider(workspaceId)).projects;
      final matched = workspaceProjects.where((p) => p.id == projectId).firstOrNull;
      if (matched != null && matched.name.trim().isNotEmpty) {
        resolvedProjectName = matched.name.trim();
      }
      if (resolvedProjectName == null) {
        final overviewProject = ref.watch(projectOverviewNotifierProvider(projectId!)).project;
        if (overviewProject != null && overviewProject.name.trim().isNotEmpty) {
          resolvedProjectName = overviewProject.name.trim();
        }
      }
    }
    final String displayProjectLabel = resolvedProjectName ?? (projectId ?? '');
    final String displayProjectInitial = displayProjectLabel.trim().isNotEmpty
        ? displayProjectLabel.trim()[0].toUpperCase()
        : 'P';
    final String? localizedViewTitle =
        currentViewTitle != null ? l10n.viewTitle(currentViewTitle!) : null;

    final String userEmail = authState.email ?? 'user@oversee.local';
    final String? fullName = authState.user?.fullName;
    final String userName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : userEmail.split('@').first.replaceAll('.', ' ');

    final Color bgColor = AppColors.bgFor(isDark);
    final Color surfaceColor = AppColors.surfaceFor(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color accentSolid = AppColors.accentSolidFor(isDark);
    final Color accentSoftColor = AppColors.accentSoftFor(isDark);
    final Color textPrimary = AppColors.textPrimaryFor(isDark);
    final Color textSecondary = AppColors.textSecondaryFor(isDark);
    final Color textMuted = AppColors.textMutedFor(isDark);
    final Color errorColor = AppColors.errorFor(isDark);

    return Container(
      height: 64.0,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : (isDesktop ? 24.0 : 18.0)),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Mobile menu drawer toggle
          if (isMobile) ...[
            IconButton(
              icon: Icon(Icons.menu_rounded, color: textPrimary, size: 20.0),
              onPressed: onMenuToggle ?? () => Scaffold.of(context).openDrawer(),
              tooltip: l10n.navigationMenu,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 6.0),
          ],

          // Left: Breadcrumbs Navigation (Figma .breadcrumb)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  WorkspaceSwitcherDropdown(activeWorkspaceId: workspaceId),
                  if (projectId != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 13.0,
                        color: textMuted,
                      ),
                    ),
                    InkWell(
                      onTap: () => context.go(AppRoutes.projectOverviewPath(workspaceId, projectId!)),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 21.0,
                              height: 21.0,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accentSoftColor,
                                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Text(
                                displayProjectInitial,
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7.0),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200.0),
                              child: Text(
                                displayProjectLabel,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12.0,
                                  fontWeight: localizedViewTitle == null ? FontWeight.w600 : FontWeight.w500,
                                  color: localizedViewTitle == null ? accentColor : textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (localizedViewTitle != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 13.0,
                        color: textMuted,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                      child: Text(
                        localizedViewTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                  if (isDesktop && projectId != null) ...[
                    const SizedBox(width: 10.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: AppColors.successFor(isDark),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5.0),
                          Text(
                            'production',
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 9.0,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 8.0),

          // Right Action Cluster (Figma node 1:340)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search / Command trigger
              if (showFullSearch)
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: InkWell(
                    onTap: () => _openQuickCommand(context),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    child: Container(
                      width: 224.0,
                      height: 30.0,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 14.0, color: textMuted),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Text(
                              l10n.searchOrCommand,
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                            decoration: BoxDecoration(
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
                      ),
                    ),
                  ),
                )
              else if (showSecondaryIcons)
                _TopbarIconButton(
                  tooltip: l10n.searchOrCommandTooltip,
                  icon: Icons.search_rounded,
                  iconColor: textSecondary,
                  onPressed: () => _openQuickCommand(context),
                ),

              // Quick Create Dropdown Button (Figma "+ Tạo mới" -> "+ Create")
              if (projectId != null) ...[
                _QuickCreateMenuButton(
                  projectId: projectId!,
                  compact: isMobile,
                  accentSolid: accentSolid,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                  surface2Color: AppColors.surface2For(isDark),
                ),
                const SizedBox(width: 6.0),
              ],

              // Seed Color & Appearance/Font/Language Settings Trigger
              Tooltip(
                message: l10n.seedColorAndThemeTooltip,
                child: InkWell(
                  onTap: () => SeedColorPickerDialog.show(context),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  child: Container(
                    width: 30.0,
                    height: 30.0,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.palette_outlined, size: 17.5, color: textSecondary),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: activeSeedColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: bgColor, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (showSecondaryIcons) ...[
                const SizedBox(width: 2.0),
                // Notifications Bell Popup (Figma 1:385)
                _NotificationsPopupButton(
                  isDark: isDark,
                  bgColor: bgColor,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  accentColor: accentColor,
                  accentSoftColor: accentSoftColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                ),

                if (!isMobile) ...[
                  const SizedBox(width: 2.0),
                  // Help / Shortcuts (Figma 1:390)
                  _TopbarIconButton(
                    tooltip: l10n.keyboardShortcutsTooltip,
                    icon: Icons.help_outline_rounded,
                    iconColor: textSecondary,
                    onPressed: () => KeyboardShortcutsDialog.show(context),
                  ),
                ],
              ],

              const SizedBox(width: 4.0),

              // Language Switcher (EN / VI)
              Tooltip(
                message: l10n.switchLanguageTooltip,
                child: InkWell(
                  key: const Key('topbar_language_toggle'),
                  onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  child: Container(
                    height: 28.0,
                    padding: const EdgeInsets.symmetric(horizontal: 7.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.translate_rounded, size: 13.5, color: accentColor),
                        const SizedBox(width: 4.0),
                        Text(
                          activeLocale.languageCode.toUpperCase(),
                          style: AppTypography.mono(
                            isDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 2.0),

              // Theme mode toggle (Figma 1:395)
              _TopbarIconButton(
                tooltip: l10n.toggleThemeTooltip,
                icon: ref.watch(themeModeProvider) == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                iconColor: textSecondary,
                onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              ),

              const SizedBox(width: 6.0),

              // User Profile Dropdown Menu (Figma 1:404)
              PopupMenuButton<String>(
                tooltip: l10n.userProfileTooltip,
                popUpAnimationStyle: kAppPopupAnimationStyle,
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: UserAvatar(
                    name: userName,
                    size: UserAvatarSize.xs,
                    showTooltip: false,
                  ),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          userEmail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textMuted,
                          ),
                        ),
                        const Divider(height: 16.0),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'seed_color',
                    child: Row(
                      children: [
                        const Icon(Icons.palette_outlined, size: 17.0),
                        const SizedBox(width: 10.0),
                        Expanded(child: Text(l10n.appearanceAndSettings)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'workspaces',
                    child: Row(
                      children: [
                        const Icon(Icons.hub_outlined, size: 17.0),
                        const SizedBox(width: 10.0),
                        Expanded(child: Text(l10n.allWorkspaces)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'workspace_settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings_outlined, size: 17.0),
                        const SizedBox(width: 10.0),
                        Expanded(child: Text(l10n.workspaceSettings)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 17.0, color: errorColor),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            l10n.logOut,
                            style: TextStyle(color: errorColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (String value) async {
                  switch (value) {
                    case 'seed_color':
                      await SeedColorPickerDialog.show(context);
                      break;
                    case 'workspaces':
                      context.go(AppRoutes.workspaces);
                      break;
                    case 'workspace_settings':
                      context.go(AppRoutes.workspaceSettingsPath(workspaceId));
                      break;
                    case 'logout':
                      final confirmed = await AppConfirmationDialog.show(
                        context,
                        title: l10n.logOut,
                        message: l10n.logOutConfirmMessage,
                        confirmText: l10n.logOut,
                        cancelText: l10n.cancel,
                        isDestructive: true,
                      );
                      if (confirmed == true) {
                        await ref.read(authNotifierProvider.notifier).logout();
                      }
                      break;
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopbarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _TopbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 17.5, color: iconColor),
      style: IconButton.styleFrom(
        minimumSize: const Size(30, 30),
        maximumSize: const Size(30, 30),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
      ),
      onPressed: onPressed,
    );
  }
}

class _NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String timeAgo;
  final IconData icon;
  final bool unread;

  const _NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.icon,
    this.unread = true,
  });

  _NotificationItem copyWith({bool? unread}) => _NotificationItem(
        id: id,
        title: title,
        subtitle: subtitle,
        timeAgo: timeAgo,
        icon: icon,
        unread: unread ?? this.unread,
      );
}

/// Notifications bell button that opens an anchored popup instead of navigating to a new route.
class _NotificationsPopupButton extends StatefulWidget {
  final bool isDark;
  final Color bgColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color accentColor;
  final Color accentSoftColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const _NotificationsPopupButton({
    required this.isDark,
    required this.bgColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.accentColor,
    required this.accentSoftColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  @override
  State<_NotificationsPopupButton> createState() => _NotificationsPopupButtonState();
}

class _NotificationsPopupButtonState extends State<_NotificationsPopupButton> {
  List<_NotificationItem> _notifications = const [
    _NotificationItem(
      id: 'n1',
      title: 'Sprint progress updated',
      subtitle: 'Completed issues are synced across Board and Backlog.',
      timeAgo: 'Just now',
      icon: Icons.bolt_rounded,
      unread: true,
    ),
    _NotificationItem(
      id: 'n2',
      title: 'Timeline & Calendar ready',
      subtitle: 'Drag issues to reschedule dates directly on the canvas.',
      timeAgo: '10m ago',
      icon: Icons.calendar_today_outlined,
      unread: true,
    ),
  ];

  int get _unreadCount => _notifications.where((n) => n.unread).length;

  void _markAllRead() {
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(unread: false)).toList();
    });
  }

  void _markOneRead(String id) {
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == id ? n.copyWith(unread: false) : n)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.notifications,
      popUpAnimationStyle: kAppPopupAnimationStyle,
      offset: const Offset(0, 40),
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
      color: widget.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        side: BorderSide(color: widget.borderColor),
      ),
      onSelected: (value) {
        if (value == '__mark_all__') {
          _markAllRead();
        } else {
          _markOneRead(value);
        }
      },
      itemBuilder: (ctx) {
        final entries = <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            enabled: false,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.textPrimary,
                  ),
                ),
                if (_unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: widget.accentSoftColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (_unreadCount > 0)
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop('__mark_all__');
                    },
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.accentColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
        ];

        if (_notifications.isEmpty) {
          entries.add(
            PopupMenuItem<String>(
              enabled: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    'You are all caught up!',
                    style: TextStyle(fontSize: 12, color: widget.textMuted),
                  ),
                ),
              ),
            ),
          );
        } else {
          for (final item in _notifications) {
            entries.add(
              PopupMenuItem<String>(
                value: item.id,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: item.unread
                            ? widget.accentSoftColor
                            : AppColors.surface2For(widget.isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                      child: Icon(
                        item.icon,
                        size: 14,
                        color: item.unread ? widget.accentColor : widget.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: item.unread ? FontWeight.w600 : FontWeight.w500,
                                    color: widget.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.timeAgo,
                                style: TextStyle(fontSize: 10, color: widget.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: TextStyle(fontSize: 11, color: widget.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (item.unread) ...[
                      const SizedBox(width: 8),
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
        }
        return entries;
      },
      child: SizedBox(
        width: 30,
        height: 30,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 17.5, color: widget.textSecondary),
            if (_unreadCount > 0)
              Positioned(
                right: 6,
                top: 5,
                child: Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.bgColor, width: 1.0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Figma "+ Tạo mới" / "+ Create" button with dropdown for Issue, Epic, Sprint, Document.
class _QuickCreateMenuButton extends StatelessWidget {
  final String projectId;
  final bool compact;
  final Color accentSolid;
  final Color surfaceColor;
  final Color surface2Color;
  final Color borderColor;
  final Color textSecondary;
  final Color textMuted;

  const _QuickCreateMenuButton({
    required this.projectId,
    required this.compact,
    required this.accentSolid,
    required this.surfaceColor,
    required this.surface2Color,
    required this.borderColor,
    required this.textSecondary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<QuickCreateEntityType>(
      tooltip: l10n.quickCreateTooltip,
      popUpAnimationStyle: kAppPopupAnimationStyle,
      offset: const Offset(0, 38),
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 224),
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        side: BorderSide(color: borderColor),
      ),
      onSelected: (type) {
        QuickCreateDialog.show(
          context,
          projectId: projectId,
          initialType: type,
        );
      },
      itemBuilder: (context) {
        return QuickCreateEntityType.values.map((entity) {
          return PopupMenuItem<QuickCreateEntityType>(
            value: entity,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 15, color: textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entity.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
                if (entity == QuickCreateEntityType.issue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: surface2Color,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      'C',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 30.0,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8.0 : 10.0),
        decoration: BoxDecoration(
          color: accentSolid,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 15.0, color: Colors.white),
            if (!compact) ...[
              const SizedBox(width: 5.0),
              Text(
                l10n.create,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4.0),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 13.0, color: Colors.white70),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lightweight command palette dialog opened from the Topbar search trigger.
class _TopbarQuickCommandDialog extends StatefulWidget {
  final String workspaceId;
  final String? projectId;

  const _TopbarQuickCommandDialog({
    required this.workspaceId,
    this.projectId,
  });

  @override
  State<_TopbarQuickCommandDialog> createState() => _TopbarQuickCommandDialogState();
}

class _TopbarQuickCommandDialogState extends State<_TopbarQuickCommandDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final actions = <_QuickCmdItem>[
      if (widget.projectId != null) ...[
        _QuickCmdItem(
          label: 'Create Issue',
          group: 'Quick Create',
          icon: Icons.add_box_outlined,
          onRun: (ctx) => QuickCreateDialog.show(
            ctx,
            projectId: widget.projectId!,
            initialType: QuickCreateEntityType.issue,
          ),
        ),
        _QuickCmdItem(
          label: 'Create Epic',
          group: 'Quick Create',
          icon: Icons.bolt_rounded,
          onRun: (ctx) => QuickCreateDialog.show(
            ctx,
            projectId: widget.projectId!,
            initialType: QuickCreateEntityType.epic,
          ),
        ),
        _QuickCmdItem(
          label: 'Create Sprint',
          group: 'Quick Create',
          icon: Icons.timer_outlined,
          onRun: (ctx) => QuickCreateDialog.show(
            ctx,
            projectId: widget.projectId!,
            initialType: QuickCreateEntityType.sprint,
          ),
        ),
        _QuickCmdItem(
          label: 'Create Document',
          group: 'Quick Create',
          icon: Icons.description_outlined,
          onRun: (ctx) => QuickCreateDialog.show(
            ctx,
            projectId: widget.projectId!,
            initialType: QuickCreateEntityType.document,
          ),
        ),
        _QuickCmdItem(
          label: 'Go to Overview',
          group: 'Navigation',
          icon: Icons.dashboard_outlined,
          onRun: (ctx) => ctx.go(AppRoutes.projectOverviewPath(widget.workspaceId, widget.projectId!)),
        ),
        _QuickCmdItem(
          label: 'Go to Board',
          group: 'Navigation',
          icon: Icons.view_kanban_outlined,
          onRun: (ctx) => ctx.go(AppRoutes.projectBoardPath(widget.workspaceId, widget.projectId!)),
        ),
        _QuickCmdItem(
          label: 'Go to Backlog',
          group: 'Navigation',
          icon: Icons.format_list_bulleted_outlined,
          onRun: (ctx) => ctx.go(AppRoutes.projectBacklogPath(widget.workspaceId, widget.projectId!)),
        ),
      ],
      _QuickCmdItem(
        label: 'Change App Seed Color',
        group: 'Preferences',
        icon: Icons.palette_outlined,
        onRun: (ctx) => SeedColorPickerDialog.show(ctx),
      ),
    ];

    final filtered = _query.trim().isEmpty
        ? actions
        : actions
            .where((a) => a.label.toLowerCase().contains(_query.trim().toLowerCase()))
            .toList();

    return Dialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        side: BorderSide(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: TextField(
                autofocus: true,
                onChanged: (val) => setState(() => _query = val),
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a command or jump to a view...',
                  hintStyle: TextStyle(fontSize: 12.5, color: textMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 17, color: textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            Divider(height: 1, color: borderColor),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No matching commands',
                        style: TextStyle(fontSize: 12.5, color: textMuted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final item = filtered[idx];
                        return ListTile(
                          dense: true,
                          leading: Icon(item.icon, size: 17, color: textSecondary),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                          trailing: Text(
                            item.group,
                            style: TextStyle(fontSize: 10.5, color: textMuted),
                          ),
                          onTap: () {
                            final parentNavigator = Navigator.of(context);
                            parentNavigator.pop();
                            item.onRun(parentNavigator.context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCmdItem {
  final String label;
  final String group;
  final IconData icon;
  final void Function(BuildContext) onRun;

  const _QuickCmdItem({
    required this.label,
    required this.group,
    required this.icon,
    required this.onRun,
  });
}
