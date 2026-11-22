import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Dedicated empty-state page for each additional Figma sidebar route inside the project shell.
class ProjectFeatureEmptyScreen extends StatelessWidget {
  final String workspaceId;
  final String projectId;
  final String routeKey;
  final String sectionEyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final String emptyTitle;
  final String emptyDescription;
  final String? badgeLabel;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final String? primaryActionPath;

  const ProjectFeatureEmptyScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.routeKey,
    required this.sectionEyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.emptyTitle,
    required this.emptyDescription,
    this.badgeLabel,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.primaryActionPath,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accentColor = AppColors.accentFor(isDark);
    final Color accentSoft = AppColors.accentSoftFor(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color textPrimary = AppColors.textPrimaryFor(isDark);
    final Color textSecondary = AppColors.textSecondaryFor(isDark);

    return ProjectScreenScaffold(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: routeKey,
      title: title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(sectionEyebrow.toUpperCase(), style: AppTypography.eyebrow(isDark)),
                const SizedBox(height: 6.0),
                Wrap(
                  spacing: 10.0,
                  runSpacing: 6.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 25.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: textPrimary,
                      ),
                    ),
                    if (badgeLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: accentSoft,
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          border: Border.all(color: accentColor.withValues(alpha: 0.24)),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5.0),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
                const SizedBox(height: 24.0),
                Container(
                  constraints: const BoxConstraints(minHeight: 360.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFor(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    border: Border.all(color: borderColor),
                  ),
                  child: AppEmptyState(
                    icon: icon,
                    title: emptyTitle,
                    description: emptyDescription,
                    action: primaryActionLabel != null && primaryActionPath != null
                        ? AppPrimaryButton(
                            label: primaryActionLabel!,
                            icon: primaryActionIcon,
                            onPressed: () => context.go(primaryActionPath!),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
