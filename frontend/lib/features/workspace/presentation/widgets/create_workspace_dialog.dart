import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Modal dialog for creating a new workspace organization with live identity preview
/// and automatic URL slug generation, aligned with Figma modal & form design tokens.
class CreateWorkspaceDialog extends ConsumerStatefulWidget {
  const CreateWorkspaceDialog({super.key});

  static Future<void> show(BuildContext context) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Create Workspace',
      maxWidth: 520.0,
      child: const CreateWorkspaceDialog(),
    );
  }

  /// Computes a 1-2 character uppercase monogram for workspace preview avatars.
  static String computeInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'W';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Generates a URL-safe lowercase slug from a workspace name.
  static String generateSlug(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
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
    setState(() {
      if (!_isSlugManuallyEdited) {
        _slugController.text = CreateWorkspaceDialog.generateSlug(value);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final errorColor = AppColors.errorFor(isDark);
    final dangerSoft = AppColors.dangerSoftFor(isDark);

    final previewName = _nameController.text.trim().isEmpty
        ? 'New Workspace'
        : _nameController.text.trim();
    final previewSlug = _slugController.text.trim().isEmpty
        ? 'workspace-slug'
        : _slugController.text.trim().toLowerCase();
    final initials = CreateWorkspaceDialog.computeInitials(_nameController.text);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Workspace Identity Preview (Figma .project-settings-identity)
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
                    initials,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.0,
                      letterSpacing: 0.2,
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
                      Row(
                        children: [
                          Icon(Icons.link_rounded, size: 12.0, color: textMuted),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Text(
                              'oversee.app/w/$previewSlug',
                              style: AppTypography.mono(isDark, fontSize: 11.0, color: textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Text(
                    'OWNER',
                    style: TextStyle(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: accentColor,
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
            label: 'Workspace Name',
            hintText: 'e.g. Engineering Team, Mobile Division',
            isRequired: true,
            prefixIcon: Icon(Icons.layers_outlined, size: 17.0, color: textMuted),
            onChanged: _onNameChanged,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a workspace name';
              }
              return null;
            },
          ),
          const SizedBox(height: 14.0),

          AppTextFormField(
            controller: _slugController,
            label: 'Workspace Slug',
            hintText: 'e.g. engineering-team',
            helperText: 'URL identifier: lowercase letters, numbers, and single hyphens',
            isRequired: true,
            prefixIcon: Icon(Icons.alternate_email_rounded, size: 16.0, color: textMuted),
            onChanged: (_) {
              setState(() {
                _isSlugManuallyEdited = true;
              });
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
          const SizedBox(height: 14.0),

          AppTextFormField(
            controller: _descController,
            label: 'Description',
            hintText: 'Add context, team scope, and goals (optional)',
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
                Text(
                  'Esc to close',
                  style: TextStyle(fontSize: 11.0, color: textMuted),
                ),
                const Spacer(),
                AppOutlinedButton(
                  label: 'Cancel',
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10.0),
                AppPrimaryButton(
                  icon: Icons.add_rounded,
                  label: 'Create Workspace',
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
