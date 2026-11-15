import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

class WorkspaceListScreen extends ConsumerWidget {
  const WorkspaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                      onPressed: () {
                        AppAdaptiveDialog.show<void>(
                          context,
                          title: 'Create Workspace',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppTextFormField(
                                label: 'Workspace Name',
                                isRequired: true,
                                hintText: 'e.g. Engineering Team',
                              ),
                              const SizedBox(height: 16),
                              const AppTextFormField(
                                label: 'Description',
                                hintText: 'Workspace purpose and description',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AppOutlinedButton(
                                    label: 'Cancel',
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  const SizedBox(width: 12),
                                  AppPrimaryButton(
                                    label: 'Create',
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      AppFeedback.showSuccess(context, 'Workspace created!');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      icon: Icons.add,
                      label: 'New Workspace',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildWorkspaceCard(
                  context,
                  id: 'ws-team4',
                  name: 'Team 04 - Oversee',
                  role: 'owner',
                  description: 'Official Software Project Management Workspace for Oversee.',
                  projectCount: 2,
                ),
                const SizedBox(height: 12),
                _buildWorkspaceCard(
                  context,
                  id: 'ws-capstone',
                  name: 'Capstone Projects Hub',
                  role: 'member',
                  description: 'Shared engineering collaboration and evaluation workspace.',
                  projectCount: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceCard(
    BuildContext context, {
    required String id,
    required String name,
    required String role,
    required String description,
    required int projectCount,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      onTap: () {
        context.go(AppRoutes.projectOverviewPath(id, 'proj-oversee'));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: name,
                size: UserAvatarSize.md,
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
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RoleBadge.fromString(role, isSmall: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              AppIconButton(
                tooltip: 'Workspace Settings',
                icon: Icons.settings_outlined,
                onPressed: () {
                  context.go(AppRoutes.workspaceSettingsPath(id));
                },
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$projectCount projects active',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              AppPrimaryButton(
                height: 36,
                onPressed: () {
                  context.go(AppRoutes.projectOverviewPath(id, 'proj-oversee'));
                },
                icon: Icons.arrow_forward_rounded,
                label: 'Open Project',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
