import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Modal dialog for viewing and editing issue details.
class IssueDetailDialog extends ConsumerStatefulWidget {
  final String projectId;
  final String projectKey;
  final IssueModel issue;

  const IssueDetailDialog({
    super.key,
    required this.projectId,
    required this.projectKey,
    required this.issue,
  });

  static Future<void> show(
    BuildContext context, {
    required String projectId,
    required String projectKey,
    required IssueModel issue,
  }) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: '${issue.formattedKey(projectKey)} - Issue Details',
      child: IssueDetailDialog(
        projectId: projectId,
        projectKey: projectKey,
        issue: issue,
      ),
    );
  }

  @override
  ConsumerState<IssueDetailDialog> createState() => _IssueDetailDialogState();
}

class _IssueDetailDialogState extends ConsumerState<IssueDetailDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _estimateController;
  late IssuePriority _selectedPriority;
  late IssueType _selectedType;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.issue.title);
    _descController = TextEditingController(text: widget.issue.description ?? '');
    _estimateController = TextEditingController(
      text: widget.issue.estimate != null ? widget.issue.estimate.toString() : '',
    );
    _selectedPriority = widget.issue.priority;
    _selectedType = widget.issue.type;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _estimateController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(issueRepositoryProvider);
      final double? estimate = _estimateController.text.trim().isNotEmpty
          ? double.tryParse(_estimateController.text.trim())
          : null;

      await repo.updateIssue(
        widget.issue.id,
        title: title,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        type: _selectedType,
        priority: _selectedPriority,
        estimate: estimate,
      );

      if (!mounted) return;
      await ref.read(backlogNotifierProvider(widget.projectId).notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Issue updated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to update issue: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
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
                border: Border.all(color: AppColors.errorLight),
              ),
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.errorLight),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                ),
                child: Text(
                  widget.issue.formattedKey(widget.projectKey),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                ),
              ),
              const SizedBox(width: 10.0),
              _buildStatusBadge(widget.issue.status),
            ],
          ),
          const SizedBox(height: 16.0),
          AppTextFormField(
            controller: _titleController,
            label: 'Title',
            hintText: 'Issue summary...',
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6.0),
                    DropdownButtonFormField<IssueType>(
                      initialValue: _selectedType,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      items: IssueType.values.map((t) {
                        return DropdownMenuItem<IssueType>(
                          value: t,
                          child: Row(
                            children: [
                              Icon(t.icon, size: 16, color: t.color),
                              const SizedBox(width: 8.0),
                              Text(t.label, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Priority', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6.0),
                    DropdownButtonFormField<IssuePriority>(
                      initialValue: _selectedPriority,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      items: IssuePriority.values.map((p) {
                        return DropdownMenuItem<IssuePriority>(
                          value: p,
                          child: Row(
                            children: [
                              Icon(p.icon, size: 16, color: p.color),
                              const SizedBox(width: 8.0),
                              Text(p.label, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPriority = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          AppTextFormField(
            controller: _estimateController,
            label: 'Story Points',
            hintText: 'e.g. 3.0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16.0),
          AppTextFormField(
            controller: _descController,
            label: 'Description',
            hintText: 'Detailed issue description...',
            maxLines: 4,
          ),
          const SizedBox(height: 24.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppOutlinedButton(
                label: 'Close',
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12.0),
              AppPrimaryButton(
                label: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _handleSave,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(IssueStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
