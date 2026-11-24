import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/presentation/widgets/create_workspace_dialog.dart';
import 'package:frontend/shared/layout/sidebar_icons.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Dedicated full-page Workspace creation screen at `/workspaces/new`,
/// aligned with Figma design tokens and live workspace/sidebar preview.
class CreateWorkspaceScreen extends ConsumerStatefulWidget {
  const CreateWorkspaceScreen({super.key});

  @override
  ConsumerState<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends ConsumerState<CreateWorkspaceScreen> {
  static const _templates = <(String, String, String)>[
    ('Engineering Team', 'Product engineering, sprint delivery, and release tracking', 'ENG'),
    ('Product Studio', 'Discovery, roadmap prioritization, and cross-functional launches', 'PRD'),
    ('Design System', 'Component library, design tokens, and UI review workflows', 'DSG'),
    ('Operations', 'Internal processes, incident tracking, and team requests', 'OPS'),
  ];

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

  void _applyTemplate(String name, String description) {
    setState(() {
      _nameController.text = name;
      _slugController.text = CreateWorkspaceDialog.generateSlug(name);
      _descController.text = description;
      _isSlugManuallyEdited = false;
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
      AppFeedback.showSuccess(context, 'Workspace "${created.name}" created successfully!');
      context.go(AppRoutes.workspaceDetailPath(created.id));
    } else {
      final error =
          ref.read(workspaceNotifierProvider).errorMessage ?? 'Failed to create workspace.';
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
                onTap: () => context.go(AppRoutes.workspaces),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 17.0, color: textSecondary),
                      const SizedBox(width: 8.0),
                      FigmaSidebarIcon(
                        FigmaIconType.layers3,
                        size: 18.0,
                        color: accentColor,
                        strokeWidth: 1.75,
                      ),
                      const SizedBox(width: 7.0),
                      Text(
                        'Workspaces',
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
              Text(
                'New Workspace',
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
            textSecondary: textSecondary,
            textMuted: textMuted,
          );

          final previewPanel = _buildPreviewPanel(
            isDark: isDark,
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
                    Text('NEW WORKSPACE', style: AppTypography.eyebrow(isDark)),
                    const SizedBox(height: 6.0),
                    Text(
                      'Create a Workspace',
                      style: TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5.0),
                    Text(
                      'Set up a dedicated home for your team projects, sprints, issues, and access control.',
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
    required Color textSecondary,
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
            Text('QUICK STARTERS', style: AppTypography.eyebrow(isDark)),
            const SizedBox(height: 10.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                for (final (tplName, tplDesc, tplTag) in _templates)
                  InkWell(
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    onTap: () => _applyTemplate(tplName, tplDesc),
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
                            tplTag,
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
            const SizedBox(height: 16.0),
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
            const SizedBox(height: 16.0),
            AppTextFormField(
              controller: _descController,
              label: 'Description',
              hintText: 'Add context, team scope, and goals (optional)',
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
                    'You will be assigned as Owner',
                    style: TextStyle(fontSize: 11.5, color: textMuted),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppOutlinedButton(
                        label: 'Cancel',
                        onPressed: _isLoading ? null : () => context.go(AppRoutes.workspaces),
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
    required Color accentColor,
    required Color accentSoft,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final previewName = _nameController.text.trim().isEmpty
        ? 'Engineering Team'
        : _nameController.text.trim();
    final previewSlug = _slugController.text.trim().isEmpty
        ? 'engineering-team'
        : _slugController.text.trim().toLowerCase();
    final previewDesc = _descController.text.trim().isEmpty
        ? 'Organize projects, sprints, backlogs, and team velocity in one place.'
        : _descController.text.trim();
    final initials = CreateWorkspaceDialog.computeInitials(previewName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Workspace Card Preview
        Container(
          padding: const EdgeInsets.all(20.0),
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
              Text('LIVE PREVIEW', style: AppTypography.eyebrow(isDark)),
              const SizedBox(height: 14.0),
              Row(
                children: [
                  Container(
                    width: 44.0,
                    height: 44.0,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFor(isDark),
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      border: Border.all(color: accentColor.withValues(alpha: 0.28)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                previewName,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: accentSoft,
                                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                              ),
                              child: Text(
                                'OWNER',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          'oversee.app/w/$previewSlug',
                          style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                previewDesc,
                style: TextStyle(fontSize: 12.0, color: textSecondary, height: 1.45),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14.0),

        // Sidebar Appearance Preview
        AppCard(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INCLUDED CAPABILITIES', style: AppTypography.eyebrow(isDark)),
              const SizedBox(height: 12.0),
              _CapabilityRow(
                icon: FigmaIconType.folderKanban,
                title: 'Unlimited Projects & Boards',
                subtitle: 'Organize multiple product streams under @$previewSlug.',
                isDark: isDark,
              ),
              const SizedBox(height: 10.0),
              _CapabilityRow(
                icon: FigmaIconType.timer,
                title: 'Sprint Planning & Velocity',
                subtitle: 'Track burndown charts, backlogs, and release cycles.',
                isDark: isDark,
              ),
              const SizedBox(height: 10.0),
              _CapabilityRow(
                icon: FigmaIconType.users,
                title: 'Role-Based Access Control',
                subtitle: 'Invite Owners, Admins, Members, and Viewers anytime.',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  final FigmaIconType icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _CapabilityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.accentFor(isDark);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28.0,
          height: 28.0,
          decoration: BoxDecoration(
            color: AppColors.accentSoftFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          alignment: Alignment.center,
          child: FigmaSidebarIcon(icon, size: 14.0, color: accentColor),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryFor(isDark),
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.0,
                  color: AppColors.textSecondaryFor(isDark),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
