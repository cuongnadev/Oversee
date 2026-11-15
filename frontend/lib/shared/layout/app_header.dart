import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/workspace/presentation/widgets/workspace_switcher_dropdown.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Top Bar / App Header for Oversee Shell.
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
    final authState = ref.watch(authNotifierProvider);

    final String userEmail = authState.email ?? 'user@oversee.local';
    final String userName = userEmail.split('@').first.replaceAll('.', ' ');

    return Container(
      height: 60.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Mobile menu drawer toggle
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onMenuToggle ?? () => Scaffold.of(context).openDrawer(),
              tooltip: 'Navigation Menu',
            ),
            const SizedBox(width: 8.0),
          ],

          // Breadcrumbs Navigation
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  WorkspaceSwitcherDropdown(activeWorkspaceId: workspaceId),
                  if (projectId != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        '/',
                        style: TextStyle(
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => context.go(AppRoutes.projectOverviewPath(workspaceId, projectId!)),
                      borderRadius: BorderRadius.circular(4.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                        child: Text(
                          projectId!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: currentViewTitle == null ? AppColors.primary : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (currentViewTitle != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        '/',
                        style: TextStyle(
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                      child: Text(
                        currentViewTitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 12.0),

          // Theme mode toggle
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20.0,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),

          const SizedBox(width: 4.0),

          // User Profile Dropdown Menu
          PopupMenuButton<String>(
            tooltip: 'User Profile',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
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
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      userEmail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                    Icon(Icons.hub_outlined, size: 18.0),
                    SizedBox(width: 10.0),
                    Expanded(child: Text('All Workspaces')),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'workspace_settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18.0),
                    SizedBox(width: 10.0),
                    Expanded(child: Text('Workspace Settings')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18.0, color: AppColors.error),
                    SizedBox(width: 10.0),
                    Expanded(child: Text('Log Out', style: TextStyle(color: AppColors.error))),
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
