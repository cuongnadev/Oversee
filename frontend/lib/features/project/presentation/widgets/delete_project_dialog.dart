import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/project/application/project_settings_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Destructive confirmation dialog requiring exact project name entry before deleting.
class DeleteProjectDialog extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;
  final String projectName;

  const DeleteProjectDialog({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.projectName,
  });

  static Future<void> show(
    BuildContext context, {
    required String workspaceId,
    required String projectId,
    required String projectName,
  }) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Delete Project',
      child: DeleteProjectDialog(
        workspaceId: workspaceId,
        projectId: projectId,
        projectName: projectName,
      ),
    );
  }

  @override
  ConsumerState<DeleteProjectDialog> createState() => _DeleteProjectDialogState();
}

class _DeleteProjectDialogState extends ConsumerState<DeleteProjectDialog> {
  final _inputController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  bool get _isMatch => _inputController.text.trim() == widget.projectName.trim();

  Future<void> _handleDelete() async {
    if (!_isMatch) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(projectSettingsNotifierProvider(widget.projectId).notifier);
    final success = await notifier.deleteProject();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Project "${widget.projectName}" was deleted.');
      context.go(AppRoutes.workspaceProjectsPath(widget.workspaceId));
    } else {
      final error = ref.read(projectSettingsNotifierProvider(widget.projectId)).errorMessage ??
          'Failed to delete project.';
      setState(() {
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: AppColors.errorLight.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: AppColors.errorLight.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 22, color: AppColors.errorLight),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  'This action will permanently archive and delete "${widget.projectName}". All project issues, sprints, and boards will become inaccessible.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.errorLight,
                        fontWeight: FontWeight.w500,
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
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.errorLight),
            ),
          ),
          const SizedBox(height: 16.0),
        ],
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'Please type '),
              TextSpan(
                text: widget.projectName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.errorLight),
              ),
              const TextSpan(text: ' to confirm:'),
            ],
          ),
        ),
        const SizedBox(height: 10.0),
        AppTextFormField(
          controller: _inputController,
          hintText: widget.projectName,
          onChanged: (_) => setState(() {}),
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
            AppDestructiveButton(
              label: 'Delete Project',
              isLoading: _isLoading,
              onPressed: _isMatch ? _handleDelete : null,
            ),
          ],
        ),
      ],
    );
  }
}
