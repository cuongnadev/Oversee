import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/workspace/application/workspace_settings_provider.dart';
import 'package:frontend/features/workspace/domain/workspace_member_model.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';
import 'package:frontend/features/workspace/presentation/widgets/add_workspace_member_dialog.dart';
import 'package:frontend/features/workspace/presentation/widgets/delete_workspace_dialog.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Workspace Management and Settings Screen.
/// Provides general property editing, RBAC member management, and workspace deletion.
class WorkspaceSettingsScreen extends ConsumerStatefulWidget {
  final String workspaceId;

  const WorkspaceSettingsScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<WorkspaceSettingsScreen> createState() => _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends ConsumerState<WorkspaceSettingsScreen> {
  final _generalFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _descController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _slugController = TextEditingController();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _syncControllers(WorkspaceModel? workspace) {
    if (workspace != null && !_controllersInitialized) {
      _nameController.text = workspace.name;
      _slugController.text = workspace.slug;
      _descController.text = workspace.description ?? '';
      _controllersInitialized = true;
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'W';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.trim().substring(0, name.trim().length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _handleSaveGeneral() async {
    if (!_generalFormKey.currentState!.validate()) return;

    final notifier = ref.read(workspaceSettingsNotifierProvider(widget.workspaceId).notifier);
    final success = await notifier.updateWorkspace(
      name: _nameController.text.trim(),
      slug: _slugController.text.trim().toLowerCase(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    );

    if (mounted && success) {
      AppFeedback.showSuccess(context, 'Workspace updated successfully.');
    }
  }

  Future<void> _handleRemoveMember(WorkspaceMemberModel member, String currentUserId) async {
    final bool isSelf = member.userId == currentUserId;
    final String title = isSelf ? 'Leave Workspace' : 'Remove Member';
    final String memberName = member.user?.fullName ?? member.user?.email ?? 'this member';
    final String message = isSelf
        ? 'Are you sure you want to leave this workspace? You will lose access to its projects and sprints.'
        : 'Are you sure you want to remove "$memberName" from this workspace?';

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: title,
      message: message,
      confirmText: isSelf ? 'Leave' : 'Remove',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(workspaceSettingsNotifierProvider(widget.workspaceId).notifier);
      final success = await notifier.removeMember(member.userId);
      if (mounted && success) {
        AppFeedback.showSuccess(context, isSelf ? 'You have left the workspace.' : 'Member removed.');
        if (isSelf) {
          context.go(AppRoutes.workspaces);
        }
      }
    }
  }

  Future<void> _handleUpdateRole(WorkspaceMemberModel member, RoleType newRole) async {
    if (member.role == newRole) return;

    final notifier = ref.read(workspaceSettingsNotifierProvider(widget.workspaceId).notifier);
    final success = await notifier.updateMemberRole(member.userId, newRole);
    if (mounted && success) {
      AppFeedback.showSuccess(context, 'Role updated to ${newRole.label}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.user?.id ?? '';

    final state = ref.watch(workspaceSettingsNotifierProvider(widget.workspaceId));
    final workspace = state.workspace;
    _syncControllers(workspace);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Workspaces',
          onPressed: () => context.go(AppRoutes.workspaces),
        ),
        title: Row(
          children: [
            const Text('Workspace Settings'),
            if (workspace != null) ...[
              const SizedBox(width: 12),
              RoleBadge(role: state.currentUserRole, isSmall: true),
            ],
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: AppLoadingIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header card with monogram
                      if (workspace != null) ...[
                        Row(
                          children: [
                            Container(
                              width: 52.0,
                              height: 52.0,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _getInitials(workspace.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workspace.name,
                                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '@${workspace.slug} • Created: ${workspace.createdAt?.toLocal().toString().split(' ').first ?? 'N/A'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24.0),
                      ],

                      // Error message banner
                      if (state.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20.0),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: Text(
                                  state.errorMessage!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 13.0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Section 1: General Information
                      AppCard(
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _generalFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.tune_rounded, size: 20.0, color: AppColors.primary),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'General Information',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                'Update workspace organization name, URL slug identifier, and overview description.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const Divider(height: 24.0),

                              AppTextFormField(
                                controller: _nameController,
                                label: 'Workspace Name',
                                isRequired: true,
                                enabled: state.canEditWorkspace,
                                hintText: 'e.g. Engineering Team',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter workspace name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),

                              AppTextFormField(
                                controller: _slugController,
                                label: 'Workspace Slug',
                                isRequired: true,
                                enabled: state.canEditWorkspace,
                                hintText: 'e.g. engineering-team',
                                helperText: 'Lowercase letters, numbers, and hyphens',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter workspace slug';
                                  }
                                  final slugRegExp = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
                                  if (!slugRegExp.hasMatch(value.trim().toLowerCase())) {
                                    return 'Slug must contain only lowercase letters, numbers, and single hyphens';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16.0),

                              AppTextFormField(
                                controller: _descController,
                                label: 'Description',
                                enabled: state.canEditWorkspace,
                                hintText: 'Workspace purpose and description',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 20.0),

                              if (state.canEditWorkspace) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: AppPrimaryButton(
                                    label: 'Save Changes',
                                    isLoading: state.isSaving,
                                    onPressed: _handleSaveGeneral,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      // Section 2: Members & RBAC Management
                      AppCard(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_outlined, size: 20.0, color: AppColors.primary),
                                    const SizedBox(width: 8.0),
                                    Text(
                                      'Workspace Members (${state.members.length})',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                if (state.canManageMembers) ...[
                                  AppPrimaryButton(
                                    height: 36.0,
                                    icon: Icons.person_add_alt_1_rounded,
                                    label: 'Add Member',
                                    onPressed: () {
                                      AddWorkspaceMemberDialog.show(
                                        context,
                                        workspaceId: widget.workspaceId,
                                        isOwner: state.isOwner,
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'Manage workspace access, permissions, and roles across your organization.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const Divider(height: 24.0),

                            // Members List
                            if (state.members.isEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: Text('No members found in this workspace.')),
                              ),
                            ] else ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.members.length,
                                separatorBuilder: (context, index) => const Divider(height: 16.0),
                                itemBuilder: (context, index) {
                                  final member = state.members[index];
                                  final isCurrentUser = member.userId == currentUserId;
                                  final bool canEditThisMember = state.canManageMembers &&
                                      (state.isOwner || member.role != RoleType.owner);

                                  return Row(
                                    children: [
                                      UserAvatar(
                                        name: member.user?.fullName ?? member.user?.email ?? 'U',
                                        imageUrl: member.user?.avatarUrl,
                                        size: UserAvatarSize.md,
                                      ),
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    member.user?.fullName ?? 'Unnamed User',
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isCurrentUser) ...[
                                                  const SizedBox(width: 6.0),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4.0),
                                                    ),
                                                    child: const Text(
                                                      'You',
                                                      style: TextStyle(
                                                        fontSize: 10.0,
                                                        color: AppColors.primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              member.user?.email ?? member.userId,
                                              style: TextStyle(
                                                fontSize: 12.0,
                                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),

                                      // Role selector or badge
                                      if (canEditThisMember && !isCurrentUser) ...[
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton<RoleType>(
                                            value: member.role,
                                            items: [
                                              if (state.isOwner) RoleType.owner,
                                              RoleType.admin,
                                              RoleType.member,
                                              RoleType.viewer,
                                            ].map((r) {
                                              return DropdownMenuItem<RoleType>(
                                                value: r,
                                                child: RoleBadge(role: r, isSmall: true),
                                              );
                                            }).toList(),
                                            onChanged: (newRole) {
                                              if (newRole != null) {
                                                _handleUpdateRole(member, newRole);
                                              }
                                            },
                                          ),
                                        ),
                                      ] else ...[
                                        RoleBadge(role: member.role, isSmall: true),
                                      ],

                                      const SizedBox(width: 8.0),

                                      // Remove / Leave action
                                      if (isCurrentUser || state.canManageMembers) ...[
                                        IconButton(
                                          tooltip: isCurrentUser ? 'Leave Workspace' : 'Remove Member',
                                          icon: Icon(
                                            isCurrentUser ? Icons.logout_rounded : Icons.delete_outline_rounded,
                                            size: 18.0,
                                            color: AppColors.error,
                                          ),
                                          onPressed: () => _handleRemoveMember(member, currentUserId),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      // Section 3: Danger Zone (Owner Only)
                      if (state.isOwner && workspace != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 20.0, color: AppColors.error),
                                  SizedBox(width: 8.0),
                                  Text(
                                    'Danger Zone',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16.0,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6.0),
                              Text(
                                'Once you delete a workspace, all projects, issues, and member associations will be soft deleted and cannot be recovered.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const Divider(height: 24.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Delete this workspace',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.0),
                                        ),
                                        Text(
                                          'Permanently delete "${workspace.name}" and all data',
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16.0),
                                  AppDestructiveButton(
                                    label: 'Delete Workspace',
                                    isLoading: state.isDeleting,
                                    onPressed: () {
                                      DeleteWorkspaceDialog.show(
                                        context,
                                        workspaceId: widget.workspaceId,
                                        workspaceName: workspace.name,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24.0),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
