import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/features/project/application/project_list_provider.dart';
import 'package:frontend/features/project/presentation/widgets/create_project_dialog.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/shared/layout/sidebar_icons.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Dedicated full-page Project creation screen at `/workspaces/:workspaceId/projects/new`,
/// aligned with Figma design tokens and live sidebar/card preview.
class CreateProjectScreen extends ConsumerStatefulWidget {
  final String workspaceId;

  const CreateProjectScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  static const _templates = <(String, String, String)>[
    ('Platform v2.0', 'PLT', 'Core platform architecture, APIs, and sprint delivery'),
    ('Mobile Application', 'MOB', 'Cross-platform Flutter mobile release roadmap'),
    ('Design System', 'DS', 'Shared UI tokens, components, and accessibility specs'),
    ('Backend Services', 'API', 'Microservices, database migrations, and reliability'),
  ];

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

  void _applyTemplate(String name, String key, String description) {
    setState(() {
      _nameController.text = name;
      _keyController.text = key;
      _descController.text = description;
      _isKeyManuallyEdited = false;
      _errorMessage = null;
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
    final workspaceState = ref.watch(workspaceNotifierProvider);
    final activeWorkspace = workspaceState.workspaces
            .where((w) => w.id == widget.workspaceId)
            .firstOrNull ??
        workspaceState.selectedWorkspace;
    final workspaceName = activeWorkspace?.name ?? 'Workspace';

    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Scaffold(
      backgroundColor: AppColors.bgFor(isDark),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64.0),
        child: Container(
          height: 64.0,
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          decoration: BoxDecoration(
            color: AppColors.bgFor(isDark),
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => context.go(AppRoutes.workspaceProjectsPath(widget.workspaceId)),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 17.0, color: textSecondary),
                      const SizedBox(width: 8.0),
                      Text(
                        workspaceName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              Icon(Icons.chevron_right_rounded, size: 15.0, color: textMuted),
              const SizedBox(width: 6.0),
              InkWell(
                onTap: () => context.go(AppRoutes.workspaceProjectsPath(widget.workspaceId)),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: Text(
                    'Projects',
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              Icon(Icons.chevron_right_rounded, size: 15.0, color: textMuted),
              const SizedBox(width: 6.0),
              Text(
                'New Project',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Toggle Theme',
                icon: Icon(
                  ref.watch(themeModeProvider) == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 18.0,
                  color: textSecondary,
                ),
                onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900.0;

          final formPanel = _buildFormPanel(
            context,
            isDark: isDark,
            accentColor: accentColor,
            accentSoft: accentSoft,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textMuted: textMuted,
          );

          final previewPanel = _buildPreviewPanel(
            isDark: isDark,
            workspaceName: workspaceName,
            accentColor: accentColor,
            accentSoft: accentSoft,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32.0 : 18.0,
              vertical: 28.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('NEW PROJECT · ${workspaceName.toUpperCase()}',
                        style: AppTypography.eyebrow(isDark)),
                    const SizedBox(height: 6.0),
                    Text(
                      'Create a Project',
                      style: TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5.0),
                    Text(
                      'Configure a project key and description to launch your board, backlog, and sprints.',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                    const SizedBox(height: 24.0),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: formPanel),
                          const SizedBox(width: 22.0),
                          Expanded(flex: 2, child: previewPanel),
                        ],
                      )
                    else ...[
                      previewPanel,
                      const SizedBox(height: 18.0),
                      formPanel,
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormPanel(
    BuildContext context, {
    required bool isDark,
    required Color accentColor,
    required Color accentSoft,
    required Color borderColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final errorColor = AppColors.errorFor(isDark);
    final dangerSoft = AppColors.dangerSoftFor(isDark);

    return AppCard(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('PROJECT STARTERS', style: AppTypography.eyebrow(isDark)),
            const SizedBox(height: 10.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                for (final (tplName, tplKey, tplDesc) in _templates)
                  InkWell(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    onTap: () => _applyTemplate(tplName, tplKey, tplDesc),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                      decoration: BoxDecoration(
                        color: _nameController.text.trim() == tplName
                            ? accentSoft
                            : AppColors.surface2For(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(
                          color: _nameController.text.trim() == tplName
                              ? accentColor.withValues(alpha: 0.4)
                              : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tplKey,
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 9.5,
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            tplName,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0),
              child: Divider(height: 1.0, color: AppColors.borderSoftFor(isDark)),
            ),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                margin: const EdgeInsets.only(bottom: 16.0),
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
                        style: TextStyle(
                          color: errorColor,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            const SizedBox(height: 16.0),
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
            const SizedBox(height: 16.0),
            AppTextFormField(
              controller: _descController,
              label: 'Description',
              hintText: 'Optional summary of project scope and goals',
              maxLines: 3,
              prefixIcon: Icon(Icons.notes_rounded, size: 17.0, color: textMuted),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 22.0),
            Container(
              padding: const EdgeInsets.only(top: 16.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12.0,
                runSpacing: 10.0,
                children: [
                  Text(
                    'Creates Board, Backlog & Sprints',
                    style: TextStyle(fontSize: 11.5, color: textMuted),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppOutlinedButton(
                        label: 'Cancel',
                        onPressed: _isLoading
                            ? null
                            : () => context.go(AppRoutes.workspaceProjectsPath(widget.workspaceId)),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel({
    required bool isDark,
    required String workspaceName,
    required Color accentColor,
    required Color accentSoft,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final previewName =
        _nameController.text.trim().isEmpty ? 'Platform v2.0' : _nameController.text.trim();
    final previewKey =
        _keyController.text.trim().isEmpty ? 'PLT' : _keyController.text.trim().toUpperCase();
    final previewDesc = _descController.text.trim().isEmpty
        ? 'Track issues, backlogs, sprints, and roadmaps with your engineering team.'
        : _descController.text.trim();
    final initial = previewName.isNotEmpty ? previewName[0].toUpperCase() : 'P';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Sidebar Selector Card Preview (Figma 1:23)
        AppCard(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SIDEBAR PREVIEW', style: AppTypography.eyebrow(isDark)),
              const SizedBox(height: 12.0),
              Container(
                padding: const EdgeInsets.all(9.0),
                decoration: BoxDecoration(
                  color: AppColors.sidebarFor(isDark),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 29.0,
                      height: 29.0,
                      decoration: BoxDecoration(
                        color: accentSoft,
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            previewName,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            workspaceName,
                            style: TextStyle(fontSize: 9.5, color: textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    FigmaSidebarIcon(
                      FigmaIconType.chevronsUpDown,
                      size: 13.0,
                      color: textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14.0),

        // Live Project Card Preview
        Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentSoft.withValues(alpha: isDark ? 0.65 : 0.55),
                AppColors.surfaceFor(isDark),
              ],
              stops: const [0.0, 0.72],
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: Color.lerp(borderColor, accentColor, 0.25) ?? borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ISSUE PREFIX PREVIEW', style: AppTypography.eyebrow(isDark)),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFor(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      '$previewKey-101',
                      style: AppTypography.mono(
                        isDark,
                        fontSize: 11.0,
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Sample sprint issue',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Text(
                previewDesc,
                style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.45),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
