import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Modal dialog for creating a new project with live identity preview and
/// auto-suggested uppercase key, aligned with Figma modal design tokens.
class CreateProjectDialog extends ConsumerStatefulWidget {
  final String workspaceId;

  const CreateProjectDialog({super.key, required this.workspaceId});

  static Future<void> show(BuildContext context, {required String workspaceId}) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Create Project',
      maxWidth: 520.0,
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
    setState(() {
      if (!_isKeyManuallyEdited) {
        _keyController.text = CreateProjectDialog.suggestKey(value);
      }
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final errorColor = AppColors.errorFor(isDark);
    final dangerSoft = AppColors.dangerSoftFor(isDark);

    final previewName =
        _nameController.text.trim().isEmpty ? 'New Project' : _nameController.text.trim();
    final previewKey =
        _keyController.text.trim().isEmpty ? 'PRJ' : _keyController.text.trim().toUpperCase();
    final previewInitial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : previewKey[0];

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Project Identity Preview
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: AppColors.surface2For(isDark),
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(color: accentColor.withValues(alpha: 0.22)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    previewInitial,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        previewName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _nameController.text.trim().isEmpty ? textMuted : textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Issue prefix: $previewKey-101 · Software project',
                        style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFor(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    previewKey,
                    style: AppTypography.mono(isDark, fontSize: 10.5, color: accentColor)
                        .copyWith(fontWeight: FontWeight.w700),
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
                color: dangerSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: errorColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 17.0, color: errorColor),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: errorColor, fontSize: 12.0, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),
          ],

          AppTextFormField(
            controller: _nameController,
            label: 'Project Name',
            hintText: 'e.g. Mobile Application, Core Platform',
            isRequired: true,
            prefixIcon: Icon(Icons.folder_outlined, size: 17.0, color: textMuted),
            onChanged: _onNameChanged,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a project name';
              }
              return null;
            },
          ),
          const SizedBox(height: 14.0),

          AppTextFormField(
            controller: _keyController,
            label: 'Project Key',
            hintText: 'e.g. MA, OVS, API',
            helperText: '2-10 uppercase alphanumeric characters used as prefix for issues',
            isRequired: true,
            prefixIcon: Icon(Icons.tag_rounded, size: 17.0, color: textMuted),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
            onChanged: (_) {
              setState(() {
                _isKeyManuallyEdited = true;
              });
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
          const SizedBox(height: 14.0),

          AppTextFormField(
            controller: _descController,
            label: 'Description',
            hintText: 'Optional summary of project scope and goals',
            maxLines: 3,
            prefixIcon: Icon(Icons.notes_rounded, size: 17.0, color: textMuted),
          ),
          const SizedBox(height: 18.0),

          // Figma .modal-footer separator & actions
          Container(
            padding: const EdgeInsets.only(top: 14.0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Esc to close',
                    style: TextStyle(fontSize: 11.0, color: textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8.0),
                AppOutlinedButton(
                  label: 'Cancel',
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10.0),
                AppPrimaryButton(
                  icon: Icons.add_rounded,
                  label: 'Create Project',
                  isLoading: _isLoading,
                  onPressed: _handleCreate,
                ),
              ],
            ),
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
