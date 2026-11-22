import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/workspace/application/workspace_settings_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Destructive confirmation dialog requiring exact workspace name entry before deleting.
class DeleteWorkspaceDialog extends ConsumerStatefulWidget {
  final String workspaceId;
  final String workspaceName;

  const DeleteWorkspaceDialog({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
  });

  static Future<void> show(BuildContext context, {required String workspaceId, required String workspaceName}) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Delete Workspace',
      child: DeleteWorkspaceDialog(workspaceId: workspaceId, workspaceName: workspaceName),
    );
  }

  @override
  ConsumerState<DeleteWorkspaceDialog> createState() => _DeleteWorkspaceDialogState();
}

class _DeleteWorkspaceDialogState extends ConsumerState<DeleteWorkspaceDialog> {
  final _inputController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  bool get _isMatch => _inputController.text.trim() == widget.workspaceName.trim();

  Future<void> _handleDelete() async {
    if (!_isMatch) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final notifier = ref.read(workspaceSettingsNotifierProvider(widget.workspaceId).notifier);
    final success = await notifier.deleteWorkspace();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Workspace "${widget.workspaceName}" has been deleted.');
      context.go(AppRoutes.workspaces);
    } else {
      final error = ref.read(workspaceSettingsNotifierProvider(widget.workspaceId)).errorMessage ??
          'Failed to delete workspace.';
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

        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: AppColors.errorLight.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22.0),
              SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  'This action cannot be undone. All projects, sprints, and issues associated with this workspace will be archived or deleted.',
                  style: TextStyle(color: AppColors.error, fontSize: 13.0, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'Please type '),
              TextSpan(
                text: widget.workspaceName,
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const TextSpan(text: ' to confirm deletion:'),
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        AppTextFormField(
          controller: _inputController,
          hintText: widget.workspaceName,
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
              label: 'Delete Workspace',
              isLoading: _isLoading,
              onPressed: _isMatch ? _handleDelete : null,
            ),
          ],
        ),
      ],
    );
  }
}
