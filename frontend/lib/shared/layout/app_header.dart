import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/workspace/presentation/widgets/workspace_switcher_dropdown.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Top Bar / App Header for Oversee Shell aligned with Figma Topbar.
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String workspaceId;
  final String? projectId;
  final String? currentViewTitle;
  final VoidCallback? onMenuToggle;

  const AppHeader({
    super.key,
    required this.workspaceId,
    this.projectId,
    this.currentViewTitle,
    this.onMenuToggle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isMobile = ResponsiveBreakpoints.isMobile(context);
    final bool isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final authState = ref.watch(authNotifierProvider);

    final String userEmail = authState.email ?? 'user@oversee.local';
    final String? fullName = authState.user?.fullName;
    final String userName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : userEmail.split('@').first.replaceAll('.', ' ');

    final Color bgColor = AppColors.bgFor(isDark);
    final Color surfaceColor = AppColors.surfaceFor(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color accentSoftColor = AppColors.accentSoftFor(isDark);
    final Color textPrimary = AppColors.textPrimaryFor(isDark);
    final Color textSecondary = AppColors.textSecondaryFor(isDark);
    final Color textMuted = AppColors.textMutedFor(isDark);
    final Color errorColor = AppColors.errorFor(isDark);

    return Container(
      height: 60.0,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 20.0),
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
              tooltip: 'Navigation Menu',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 6.0),
          ],

          // Breadcrumbs Navigation (Figma .breadcrumb)
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
                        size: 14.0,
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
                              width: 20.0,
                              height: 20.0,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accentSoftColor,
                                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Text(
                                projectId!.isNotEmpty ? projectId![0].toUpperCase() : 'P',
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7.0),
                            Text(
                              projectId!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                                fontWeight: currentViewTitle == null ? FontWeight.w600 : FontWeight.w500,
                                color: currentViewTitle == null ? accentColor : textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (currentViewTitle != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 14.0,
                        color: textMuted,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                      child: Text(
                        currentViewTitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                  if (isDesktop && projectId != null) ...[
                    const SizedBox(width: 10.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.0,
                            height: 5.0,
                            decoration: BoxDecoration(
                              color: AppColors.successFor(isDark),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5.0),
                          Text(
                            'workspace',
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 9.5,
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

          const SizedBox(width: 10.0),

          // Theme mode toggle
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 18.0,
              color: textSecondary,
            ),
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: const EdgeInsets.all(6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),

          const SizedBox(width: 6.0),

          // User Profile Dropdown Menu
          PopupMenuButton<String>(
            tooltip: 'User Profile',
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: UserAvatar(
                name: userName,
                size: UserAvatarSize.sm,
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
              const PopupMenuItem<String>(
                value: 'workspaces',
                child: Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 17.0),
                    SizedBox(width: 10.0),
                    Expanded(child: Text('All Workspaces')),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'workspace_settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 17.0),
                    SizedBox(width: 10.0),
                    Expanded(child: Text('Workspace Settings')),
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
                        'Log Out',
                        style: TextStyle(color: errorColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (String value) async {
              switch (value) {
                case 'workspaces':
                  context.go(AppRoutes.workspaces);
                  break;
                case 'workspace_settings':
                  context.go(AppRoutes.workspaceSettingsPath(workspaceId));
                  break;
                case 'logout':
                  final confirmed = await AppConfirmationDialog.show(
                    context,
                    title: 'Log Out',
                    message: 'Are you sure you want to log out of Oversee?',
                    confirmText: 'Log Out',
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
    );
  }
}
