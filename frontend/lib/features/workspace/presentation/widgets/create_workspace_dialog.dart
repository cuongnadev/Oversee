import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Modal dialog for creating a new workspace organization with slug generator.
class CreateWorkspaceDialog extends ConsumerStatefulWidget {
  const CreateWorkspaceDialog({super.key});

  static Future<void> show(BuildContext context) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Create Workspace',
      child: const CreateWorkspaceDialog(),
    );
  }

  @override
  ConsumerState<CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends ConsumerState<CreateWorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descController = TextEditingController();

  bool _isSlugManuallyEdited = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (!_isSlugManuallyEdited) {
      final generatedSlug = value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');
      _slugController.text = generatedSlug;
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final slug = _slugController.text.trim().toLowerCase();
    final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();

    final created = await ref.read(workspaceNotifierProvider.notifier).createWorkspace(
          name: name,
          slug: slug,
          description: desc,
        );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (created != null) {
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Workspace "${created.name}" created successfully!');
      // Navigate to workspace projects or settings
      context.go(AppRoutes.workspaceDetailPath(created.id));
    } else {
      final error = ref.read(workspaceNotifierProvider).errorMessage ?? 'Failed to create workspace.';
      setState(() {
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            controller: _nameController,
            label: 'Workspace Name',
            hintText: 'e.g. Engineering Team, Mobile Division',
            isRequired: true,
            prefixIcon: const Icon(Icons.corporate_fare_rounded, size: 18.0),
            onChanged: _onNameChanged,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a workspace name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16.0),
          AppTextFormField(
            controller: _slugController,
            label: 'Workspace Slug',
            hintText: 'e.g. engineering-team',
            helperText: 'URL identifier: lowercase letters, numbers, hyphens',
            isRequired: true,
            prefixIcon: const Icon(Icons.link_rounded, size: 18.0),
            onChanged: (val) {
              _isSlugManuallyEdited = true;
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a workspace slug';
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
            hintText: 'Optional description of projects and purpose',
            maxLines: 3,
            prefixIcon: const Icon(Icons.description_outlined, size: 18.0),
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
                label: 'Create Workspace',
                isLoading: _isLoading,
                onPressed: _handleCreate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
