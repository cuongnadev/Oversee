import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/workspace/application/workspace_settings_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Modal dialog for adding or inviting a new member to the workspace.
class AddWorkspaceMemberDialog extends ConsumerStatefulWidget {
  final String workspaceId;
  final bool isOwner;

  const AddWorkspaceMemberDialog({
    super.key,
    required this.workspaceId,
    required this.isOwner,
  });

  static Future<void> show(BuildContext context, {required String workspaceId, required bool isOwner}) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Add Workspace Member',
      child: AddWorkspaceMemberDialog(workspaceId: workspaceId, isOwner: isOwner),
    );
  }

  @override
  ConsumerState<AddWorkspaceMemberDialog> createState() => _AddWorkspaceMemberDialogState();
}

class _AddWorkspaceMemberDialogState extends ConsumerState<AddWorkspaceMemberDialog> {
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
    final notifier = ref.read(workspaceSettingsNotifierProvider(widget.workspaceId).notifier);
    final success = await notifier.addMember(email: email, role: _selectedRole);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Member "$email" added successfully!');
    } else {
      final error = ref.read(workspaceSettingsNotifierProvider(widget.workspaceId)).errorMessage ??
          'Failed to add member.';
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
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 18.0, color: AppColors.error),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13.0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
          ],

          AppTextFormField(
            controller: _emailController,
            label: 'User Email Address',
            hintText: 'e.g. member@company.com',
            isRequired: true,
            prefixIcon: const Icon(Icons.email_outlined, size: 18.0),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter user email address';
              }
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16.0),

          // Role selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Role',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.0),
              ),
              const SizedBox(height: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RoleType>(
                    value: _selectedRole,
                    isExpanded: true,
                    items: availableRoles.map((role) {
                      return DropdownMenuItem<RoleType>(
                        value: role,
                        child: Row(
                          children: [
                            RoleBadge(role: role, isSmall: true),
                            const SizedBox(width: 12.0),
                            Text(
                              _roleDescription(role),
                              style: const TextStyle(fontSize: 12.0),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (role) {
                      if (role != null) {
                        setState(() {
                          _selectedRole = role;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
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
                label: 'Add Member',
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
        return 'Full workspace ownership and billing';
      case RoleType.admin:
        return 'Can manage projects, settings and members';
      case RoleType.member:
        return 'Can create issues, tasks and sprints';
      case RoleType.viewer:
        return 'Read-only access across projects';
    }
  }
}
