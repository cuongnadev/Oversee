import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Modal dialog for creating a new project with auto-suggested uppercase key.
class CreateProjectDialog extends ConsumerStatefulWidget {
  final String workspaceId;

  const CreateProjectDialog({super.key, required this.workspaceId});

  static Future<void> show(BuildContext context, {required String workspaceId}) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Create Project',
      child: CreateProjectDialog(workspaceId: workspaceId),
    );
  }

  /// Suggests a 2-10 character uppercase project key from the project name.
  static String suggestKey(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
    if (cleaned.isEmpty) return '';

    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      final acronym = words.map((w) => w[0]).join().toUpperCase();
      return acronym.length > 10 ? acronym.substring(0, 10) : acronym;
    }

    final single = words.first.toUpperCase();
    if (single.length >= 3) {
      return single.substring(0, 3);
    }
    return single.length == 2 ? single : '${single}P';
  }

  @override
  ConsumerState<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _descController = TextEditingController();

  bool _isKeyManuallyEdited = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (!_isKeyManuallyEdited) {
      final suggested = CreateProjectDialog.suggestKey(value);
      _keyController.text = suggested;
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final key = _keyController.text.trim().toUpperCase();
    final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();

    final notifier = ref.read(projectListNotifierProvider(widget.workspaceId).notifier);
    final created = await notifier.createProject(
      name: name,
      key: key,
      description: desc,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (created != null) {
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, 'Project "${created.name}" created successfully!');
      context.go(AppRoutes.projectOverviewPath(widget.workspaceId, created.id));
    } else {
      final error = ref.read(projectListNotifierProvider(widget.workspaceId)).errorMessage ??
          'Failed to create project.';
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
            label: 'Project Name',
            hintText: 'e.g. Mobile Application, Core Platform',
            isRequired: true,
            prefixIcon: const Icon(Icons.folder_outlined, size: 18.0),
            onChanged: _onNameChanged,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a project name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16.0),

          AppTextFormField(
            controller: _keyController,
            label: 'Project Key',
            hintText: 'e.g. MA, OVS, API',
            helperText: '2-10 uppercase alphanumeric characters used as prefix for issues',
            isRequired: true,
            prefixIcon: const Icon(Icons.tag_rounded, size: 18.0),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
            onChanged: (val) {
              _isKeyManuallyEdited = true;
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a project key';
              }
              final upper = value.trim().toUpperCase();
              final keyRegex = RegExp(r'^[A-Z0-9]{2,10}$');
              if (!keyRegex.hasMatch(upper)) {
                return 'Key must be 2 to 10 uppercase letters or numbers (e.g. OVS)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16.0),

          AppTextFormField(
            controller: _descController,
            label: 'Description',
            hintText: 'Optional summary of project scope and goals',
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
                label: 'Create Project',
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

/// Formatter that automatically converts entered text to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
