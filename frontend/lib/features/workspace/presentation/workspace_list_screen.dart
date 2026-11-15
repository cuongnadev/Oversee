import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/create_workspace_dialog.dart';
import 'package:frontend/shared/widgets/widgets.dart';

class WorkspaceListScreen extends ConsumerWidget {
  const WorkspaceListScreen({super.key});

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'W';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.trim().substring(0, name.trim().length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final workspaceState = ref.watch(workspaceNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Workspaces'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Workspaces', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Select a workspace to manage projects, tasks and sprints',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AppPrimaryButton(
                      onPressed: () => CreateWorkspaceDialog.show(context),
                      icon: Icons.add,
                      label: 'New Workspace',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Error Banner
                if (workspaceState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20.0),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            workspaceState.errorMessage!,
                            style: const TextStyle(color: AppColors.error),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: AppEmptyState(
                      icon: Icons.hub_outlined,
                      title: 'No Workspaces Found',
                      description: 'You are not a member of any workspace yet. Create your first workspace to get started.',
                      action: AppPrimaryButton(
                        onPressed: () => CreateWorkspaceDialog.show(context),
                        icon: Icons.add,
                        label: 'Create Workspace',
                      ),
                    ),
                  ),
                ] else ...[
                  for (final ws in workspaceState.workspaces) ...[
                    _buildWorkspaceCard(context, ref, ws),
                    const SizedBox(height: 12),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      onTap: () async {
        await ref.read(workspaceNotifierProvider.notifier).selectWorkspace(ws.id);
        if (context.mounted) {
          context.go(AppRoutes.workspaceDetailPath(ws.id));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(ws.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.0,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ws.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RoleBadge(role: ws.userRole, isSmall: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ws.description != null && ws.description!.isNotEmpty
                          ? ws.description!
                          : '@${ws.slug}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppIconButton(
                tooltip: 'Workspace Settings',
                icon: Icons.settings_outlined,
                onPressed: () {
                  context.go(AppRoutes.workspaceSettingsPath(ws.id));
                },
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Slug: @${ws.slug}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
              AppPrimaryButton(
                height: 36,
                onPressed: () async {
                  await ref.read(workspaceNotifierProvider.notifier).selectWorkspace(ws.id);
                  if (context.mounted) {
                    context.go(AppRoutes.workspaceDetailPath(ws.id));
                  }
                },
                icon: Icons.arrow_forward_rounded,
                label: 'Open Workspace',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
