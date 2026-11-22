import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/create_workspace_dialog.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Workspace directory and creation entry screen aligned with Figma design system.
class WorkspaceListScreen extends ConsumerWidget {
  const WorkspaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final workspaceState = ref.watch(workspaceNotifierProvider);
    final authState = ref.watch(authNotifierProvider);

    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final errorColor = AppColors.errorFor(isDark);
    final dangerSoft = AppColors.dangerSoftFor(isDark);

    final userDisplayName = (authState.user?.fullName.isNotEmpty ?? false)
        ? authState.user!.fullName
        : (authState.email?.split('@').first ?? 'User');

    return Scaffold(
      backgroundColor: AppColors.bgFor(isDark),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          height: 60.0,
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          decoration: BoxDecoration(
            color: AppColors.bgFor(isDark),
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1.0),
            ),
          ),
          child: Row(
            children: [
              // Figma .sidebar-brand mark
              Icon(Icons.layers_rounded, color: accentColor, size: 20.0),
              const SizedBox(width: 8.0),
              RichText(
                text: TextSpan(
                  text: 'oversee',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: AppTypography.fontFallback,
                    fontSize: 19.0,
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
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: accentSoft,
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
              const SizedBox(width: 10.0),
              Icon(Icons.chevron_right_rounded, size: 15.0, color: textMuted),
              const SizedBox(width: 6.0),
              Text(
                'Workspaces',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Toggle Theme',
                icon: Icon(
                  ref.watch(themeModeProvider) == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 18.0,
                  color: textSecondary,
                ),
                onPressed: () {
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
              ),
              const SizedBox(width: 4.0),
              UserAvatar(
                name: userDisplayName,
                size: UserAvatarSize.xs,
                showStatus: true,
                isOnline: true,
              ),
              const SizedBox(width: 4.0),
              IconButton(
                tooltip: 'Logout',
                icon: Icon(Icons.logout_rounded, size: 18.0, color: textSecondary),
                onPressed: () {
                  ref.read(authNotifierProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 30.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Figma .page-heading
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16.0,
                  runSpacing: 12.0,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WORKSPACES', style: AppTypography.eyebrow(isDark)),
                        const SizedBox(height: 6.0),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Your Workspaces',
                              style: TextStyle(
                                fontSize: 25.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.8,
                                color: textPrimary,
                              ),
                            ),
                            if (!workspaceState.isLoading) ...[
                              const SizedBox(width: 10.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: AppColors.surface3For(isDark),
                                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                ),
                                child: Text(
                                  '${workspaceState.workspaces.length}',
                                  style: AppTypography.mono(
                                    isDark,
                                    fontSize: 11.0,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5.0),
                        Text(
                          'Select a workspace to manage projects, tasks and sprints',
                          style: TextStyle(fontSize: 12.5, color: textSecondary),
                        ),
                      ],
                    ),
                    AppPrimaryButton(
                      onPressed: () => CreateWorkspaceDialog.show(context),
                      icon: Icons.add_rounded,
                      label: 'New Workspace',
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),

                // Error Banner
                if (workspaceState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14.0),
                    margin: const EdgeInsets.only(bottom: 18.0),
                    decoration: BoxDecoration(
                      color: dangerSoft,
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                      border: Border.all(color: errorColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: errorColor, size: 19.0),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            workspaceState.errorMessage!,
                            style: TextStyle(color: errorColor, fontSize: 12.5),
                          ),
                        ),
                        AppOutlinedButton(
                          label: 'Retry',
                          onPressed: () => ref.read(workspaceNotifierProvider.notifier).loadWorkspaces(),
                        ),
                      ],
                    ),
                  ),
                ],

                // Content
                if (workspaceState.isLoading) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60.0),
                    child: Center(child: AppLoadingIndicator()),
                  ),
                ] else if (workspaceState.workspaces.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFor(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                      border: Border.all(color: borderColor),
                    ),
                    child: AppEmptyState(
                      icon: Icons.layers_outlined,
                      title: 'No Workspaces Found',
                      description:
                          'You are not a member of any workspace yet. Create your first workspace to organize projects and sprints.',
                      action: AppPrimaryButton(
                        onPressed: () => CreateWorkspaceDialog.show(context),
                        icon: Icons.add_rounded,
                        label: 'Create Workspace',
                      ),
                    ),
                  ),
                ] else ...[
                  for (final ws in workspaceState.workspaces) ...[
                    _buildWorkspaceCard(context, ref, ws),
                    const SizedBox(height: 12.0),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceCard(BuildContext context, WidgetRef ref, WorkspaceModel ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    Future<void> openWorkspace() async {
      await ref.read(workspaceNotifierProvider.notifier).selectWorkspace(ws.id);
      if (context.mounted) {
        context.go(AppRoutes.workspaceDetailPath(ws.id));
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(18.0),
      onTap: openWorkspace,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Figma .project-icon square monogram
              Container(
                width: 42.0,
                height: 42.0,
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: accentColor.withValues(alpha: 0.22)),
                ),
                alignment: Alignment.center,
                child: Text(
                  CreateWorkspaceDialog.computeInitials(ws.name),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ws.name,
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        RoleBadge(role: ws.userRole, isSmall: true),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      ws.description != null && ws.description!.isNotEmpty
                          ? ws.description!
                          : 'Engineering workspace · @${ws.slug}',
                      style: TextStyle(fontSize: 12.0, color: textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              AppIconButton(
                tooltip: 'Workspace Settings',
                icon: Icons.tune_rounded,
                size: 32.0,
                color: textMuted,
                onPressed: () {
                  context.go(AppRoutes.workspaceSettingsPath(ws.id));
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(height: 1.0, color: borderSoft),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: AppColors.surface2For(isDark),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: AppColors.borderFor(isDark)),
                ),
                child: Text(
                  '@${ws.slug}',
                  style: AppTypography.mono(isDark, fontSize: 11.0, color: textMuted),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open Workspace',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 5.0),
                  Icon(Icons.arrow_forward_rounded, size: 14.0, color: accentColor),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
