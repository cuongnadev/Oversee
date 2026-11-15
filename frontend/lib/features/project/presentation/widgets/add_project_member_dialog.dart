import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/project/application/project_settings_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Modal dialog for adding or inviting a workspace member into the project.
class AddProjectMemberDialog extends ConsumerStatefulWidget {
  final String projectId;
  final bool isOwner;

  const AddProjectMemberDialog({
    super.key,
    required this.projectId,
    required this.isOwner,
  });

  static Future<void> show(
    BuildContext context, {
    required String projectId,
    required bool isOwner,
  }) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Add Project Member',
      child: AddProjectMemberDialog(projectId: projectId, isOwner: isOwner),
    );
  }

  @override
  ConsumerState<AddProjectMemberDialog> createState() => _AddProjectMemberDialogState();
}

class _AddProjectMemberDialogState extends ConsumerState<AddProjectMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  RoleType _selectedRole = RoleType.member;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final notifier = ref.read(projectSettingsNotifierProvider(widget.projectId).notifier);
    final success = await notifier.addMember(email: email, role: _selectedRole);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Member "$email" added to project successfully!');
    } else {
      final error = ref.read(projectSettingsNotifierProvider(widget.projectId)).errorMessage ??
          'Failed to add member to project.';
      setState(() {
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableRoles = widget.isOwner
        ? [RoleType.owner, RoleType.admin, RoleType.member, RoleType.viewer]
        : [RoleType.admin, RoleType.member, RoleType.viewer];

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.infoLight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppColors.infoLight.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20, color: AppColors.infoLight),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'Members must already belong to the current workspace to be added to this project.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.errorLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 20, color: AppColors.errorLight),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.errorLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
          ],
          AppTextFormField(
            controller: _emailController,
            label: 'Member Email',
            hintText: 'user@example.com',
            prefixIcon: const Icon(Icons.mail_outline),
            keyboardType: TextInputType.emailAddress,
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16.0),
          Text(
            'Project Role',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8.0),
          DropdownButtonFormField<RoleType>(
            initialValue: _selectedRole,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            items: availableRoles.map((role) {
              return DropdownMenuItem<RoleType>(
                value: role,
                child: Row(
                  children: [
                    Text(
                      role.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${_roleDescription(role)})',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (role) {
              if (role != null) setState(() => _selectedRole = role);
            },
          ),
          const SizedBox(height: 24.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppOutlinedButton(
                label: 'Cancel',
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12.0),
              AppPrimaryButton(
                label: 'Add to Project',
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleDescription(RoleType role) {
    switch (role) {
      case RoleType.owner:
        return 'Full control';
      case RoleType.admin:
        return 'Manage members & settings';
      case RoleType.member:
        return 'Edit tasks & sprints';
      case RoleType.viewer:
        return 'Read-only access';
    }
  }
}
