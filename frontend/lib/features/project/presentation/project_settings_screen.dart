import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/project/application/project_settings_provider.dart';
import 'package:frontend/features/project/application/project_settings_state.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/project/presentation/widgets/add_project_member_dialog.dart';
import 'package:frontend/features/project/presentation/widgets/delete_project_dialog.dart';
import 'package:frontend/features/project/presentation/widgets/project_navigation_tab_bar.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Project Management and Settings Screen.
/// Provides general property editing, RBAC member management, archive/restore, and project deletion.
class ProjectSettingsScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;

  const ProjectSettingsScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends ConsumerState<ProjectSettingsScreen> {
  final _generalFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _keyController;
  late final TextEditingController _descController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _keyController = TextEditingController();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _syncControllers(ProjectModel? project) {
    if (project != null && !_controllersInitialized) {
      _nameController.text = project.name;
      _keyController.text = project.key;
      _descController.text = project.description ?? '';
      _controllersInitialized = true;
    }
  }

  Future<void> _handleSaveGeneral() async {
    if (!_generalFormKey.currentState!.validate()) return;

    final notifier = ref.read(projectSettingsNotifierProvider(widget.projectId).notifier);
    final success = await notifier.updateProject(
      name: _nameController.text.trim(),
      key: _keyController.text.trim().toUpperCase(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    );

    if (mounted && success) {
      AppFeedback.showSuccess(context, 'Project settings updated successfully.');
    }
  }

  Future<void> _handleRemoveMember(ProjectMemberModel member, String currentUserId) async {
    final bool isSelf = member.userId == currentUserId;
    final String title = isSelf ? 'Leave Project' : 'Remove Member';
    final String memberName = member.user?.fullName.isNotEmpty == true
        ? member.user!.fullName
        : (member.user?.email ?? 'this member');
    final String message = isSelf
        ? 'Are you sure you want to leave this project? You will lose access to its tasks and sprints.'
        : 'Are you sure you want to remove "$memberName" from this project?';

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: title,
      message: message,
      confirmText: isSelf ? 'Leave' : 'Remove',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(projectSettingsNotifierProvider(widget.projectId).notifier);
      final success = await notifier.removeMember(member.userId);
      if (success && mounted) {
        if (isSelf) {
          AppFeedback.showSuccess(context, 'You have left the project.');
          context.go(AppRoutes.workspaceProjectsPath(widget.workspaceId));
        } else {
          AppFeedback.showSuccess(context, 'Member removed from project.');
        }
      }
    }
  }

  Future<void> _handleArchiveToggle(bool isArchived) async {
    final notifier = ref.read(projectSettingsNotifierProvider(widget.projectId).notifier);

    if (!isArchived) {
      final confirmed = await AppConfirmationDialog.show(
        context,
        title: 'Archive Project',
        message: 'Are you sure you want to archive this project? It will become read-only and hidden from active workspace project lists.',
        confirmText: 'Archive',
        isDestructive: true,
      );
      if (confirmed == true && mounted) {
        final success = await notifier.archiveProject();
        if (success && mounted) {
          AppFeedback.showSuccess(context, 'Project archived successfully.');
        }
      }
    } else {
      final success = await notifier.restoreProject();
      if (success && mounted) {
        AppFeedback.showSuccess(context, 'Project restored successfully.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectSettingsNotifierProvider(widget.projectId));
    final notifier = ref.read(projectSettingsNotifierProvider(widget.projectId).notifier);
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.user?.id ?? '';

    _syncControllers(state.project);

    return ProjectScreenScaffold(
      workspaceId: widget.workspaceId,
      projectId: widget.projectId,
      currentRoute: 'settings',
      title: 'Project Settings',
      body: Column(
        children: [
          ProjectNavigationTabBar(
            workspaceId: widget.workspaceId,
            projectId: widget.projectId,
            activeTab: 'settings',
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading) {
                  return const Center(child: AppLoadingIndicator(size: 36.0));
                }

                if (state.errorMessage != null && state.project == null) {
                  return Center(
                    child: AppEmptyState(
                      icon: Icons.error_outline,
                      title: 'Failed to load settings',
                      description: state.errorMessage,
                      action: AppPrimaryButton(
                        label: 'Retry',
                        icon: Icons.refresh,
                        onPressed: () => notifier.loadSettings(),
                      ),
                    ),
                  );
                }

                final project = state.project;
                if (project == null) {
                  return const Center(
                    child: AppEmptyState(
                      icon: Icons.folder_off_outlined,
                      title: 'Project not found',
                      description: 'The requested project could not be found.',
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!state.canEditSettings) ...[
                        _buildReadOnlyNotice(context),
                        const SizedBox(height: 20.0),
                      ],
                      if (state.errorMessage != null) ...[
                        _buildErrorBanner(context, state.errorMessage!),
                        const SizedBox(height: 20.0),
                      ],
                      _buildGeneralSection(context, state),
                      const SizedBox(height: 28.0),
                      _buildMembersSection(context, state, currentUserId),
                      const SizedBox(height: 28.0),
                      if (state.canEditSettings) ...[
                        _buildProjectStatusSection(context, state),
                        const SizedBox(height: 28.0),
                      ],
                      if (state.canDeleteProject) ...[
                        _buildDangerZoneSection(context, state),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppColors.infoLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.infoLight.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.infoLight, size: 22),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              'You have read-only access to this project. Only project Owners and Admins can update settings or manage members.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.errorLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.errorLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorLight, size: 20),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.errorLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSection(BuildContext context, ProjectSettingsState state) {
    return AppCard(
      child: Form(
        key: _generalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Configure project display name, key identifier, and description.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const Divider(height: 28.0),
            AppTextFormField(
              controller: _nameController,
              label: 'Project Name',
              hintText: 'e.g. Oversee Web App',
              prefixIcon: const Icon(Icons.folder_outlined),
              enabled: state.canEditSettings,
              validator: (String? val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Project name cannot be empty.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            AppTextFormField(
              controller: _keyController,
              label: 'Project Key',
              hintText: 'e.g. OVS',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              enabled: state.canEditSettings,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (String? val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Project key is required.';
                }
                final upper = val.trim().toUpperCase();
                if (!RegExp(r'^[A-Z0-9]{2,10}$').hasMatch(upper)) {
                  return 'Key must be 2 to 10 uppercase alphanumeric characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            AppTextFormField(
              controller: _descController,
              label: 'Description',
              hintText: 'Describe project objectives, scope, or guidelines...',
              prefixIcon: const Icon(Icons.description_outlined),
              enabled: state.canEditSettings,
              maxLines: 3,
            ),
            if (state.canEditSettings) ...[
              const SizedBox(height: 24.0),
              Align(
                alignment: Alignment.centerRight,
                child: AppPrimaryButton(
                  label: 'Save Changes',
                  icon: Icons.save_outlined,
                  isLoading: state.isSaving,
                  onPressed: _handleSaveGeneral,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(
    BuildContext context,
    ProjectSettingsState state,
    String currentUserId,
  ) {
    return AppCard(
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
                    Row(
                      children: [
                        Text(
                          'Project Members',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            '${state.members.length}',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Manage user access and RBAC permissions within this project.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              if (state.canManageMembers)
                AppPrimaryButton(
                  label: 'Add Member',
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: () => AddProjectMemberDialog.show(
                    context,
                    projectId: widget.projectId,
                    isOwner: state.isOwner,
                  ),
                ),
            ],
          ),
          const Divider(height: 28.0),
          if (state.members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: Text('No members found in this project.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.members.length,
              separatorBuilder: (_, _) => const Divider(height: 16.0),
              itemBuilder: (context, index) {
                final member = state.members[index];
                final isSelf = member.userId == currentUserId;
                final displayName = member.user?.fullName.isNotEmpty == true
                    ? member.user!.fullName
                    : (member.user?.email ?? 'Member');
                final email = member.user?.email ?? '';

                final bool canChangeThisRole = state.canManageMembers &&
                    (state.isOwner || member.role != RoleType.owner);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                    child: Text(
                      _getInitials(displayName),
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: const Text('YOU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: email.isNotEmpty ? Text(email) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canChangeThisRole)
                        DropdownButton<RoleType>(
                          value: member.role,
                          underline: const SizedBox(),
                          items: _buildRoleDropdownItems(state.isOwner),
                          onChanged: (newRole) async {
                            if (newRole != null && newRole != member.role) {
                              final notifier = ref.read(projectSettingsNotifierProvider(widget.projectId).notifier);
                              final success = await notifier.updateMemberRole(member.userId, newRole);
                              if (success && context.mounted) {
                                AppFeedback.showSuccess(context, 'Updated $displayName to ${newRole.name.toUpperCase()}');
                              }
                            }
                          },
                        )
                      else
                        _buildRoleBadge(member.role),
                      const SizedBox(width: 8.0),
                      if (isSelf || state.canManageMembers)
                        IconButton(
                          icon: Icon(
                            isSelf ? Icons.exit_to_app_outlined : Icons.delete_outline,
                            color: AppColors.errorLight,
                            size: 20,
                          ),
                          tooltip: isSelf ? 'Leave Project' : 'Remove Member',
                          onPressed: () => _handleRemoveMember(member, currentUserId),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<RoleType>> _buildRoleDropdownItems(bool isOwner) {
    final roles = isOwner
        ? [RoleType.owner, RoleType.admin, RoleType.member, RoleType.viewer]
        : [RoleType.admin, RoleType.member, RoleType.viewer];

    return roles.map((r) {
      return DropdownMenuItem<RoleType>(
        value: r,
        child: Text(
          r.name.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }).toList();
  }

  Widget _buildProjectStatusSection(BuildContext context, ProjectSettingsState state) {
    final project = state.project!;
    final isArchived = project.isArchived;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Status & Lifecycle',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6.0),
          Text(
            'Archive or restore this project. Archived projects become read-only.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const Divider(height: 28.0),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArchived ? 'Project is currently archived' : 'Archive this project',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      isArchived
                          ? 'Restoring will reactivate issue tracking, sprints, and boards.'
                          : 'Archiving makes the project read-only and removes it from active project lists.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              if (isArchived)
                AppPrimaryButton(
                  label: 'Restore Project',
                  icon: Icons.unarchive_outlined,
                  isLoading: state.isSaving,
                  onPressed: () => _handleArchiveToggle(isArchived),
                )
              else
                AppOutlinedButton(
                  label: 'Archive Project',
                  icon: Icons.archive_outlined,
                  isLoading: state.isSaving,
                  onPressed: () => _handleArchiveToggle(isArchived),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection(BuildContext context, ProjectSettingsState state) {
    final project = state.project!;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.errorLight.withValues(alpha: 0.5), width: 1.2),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.errorLight, size: 22),
              const SizedBox(width: 8.0),
              Text(
                'Danger Zone',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.errorLight,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            'Destructive actions for this project. Only project Owners can permanently delete.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const Divider(height: 28.0),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delete this project',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Once deleted, all tasks, sprints, and settings cannot be recovered.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              AppDestructiveButton(
                label: 'Delete Project',
                icon: Icons.delete_forever_outlined,
                onPressed: () => DeleteProjectDialog.show(
                  context,
                  workspaceId: widget.workspaceId,
                  projectId: widget.projectId,
                  projectName: project.name,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(RoleType role) {
    Color color;
    switch (role) {
      case RoleType.owner:
        color = Colors.amber.shade800;
        break;
      case RoleType.admin:
        color = Colors.indigo;
        break;
      case RoleType.member:
        color = Colors.blue;
        break;
      case RoleType.viewer:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}
