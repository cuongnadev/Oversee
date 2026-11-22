import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Figma Overview Active Sprint Hero Banner (node 1:454).
/// Gracefully adapts to a clean project summary banner if no sprint exists yet.
class OverviewSprintHero extends StatelessWidget {
  final ProjectOverviewState state;
  final String workspaceId;
  final String projectId;
  final bool isDark;

  const OverviewSprintHero({
    super.key,
    required this.state,
    required this.workspaceId,
    required this.projectId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sprint = state.activeSprint;
    final project = state.project;
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    final memberNames = state.members
        .map((m) => m.user?.fullName.isNotEmpty == true ? m.user!.fullName : (m.user?.email ?? m.userId))
        .toList();

    final completed = state.completedIssues;
    final total = state.totalIssues;
    final pct = state.completionPercentage;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;

        final infoBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isCompact) ...[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(AppColors.radiusXl),
                  border: Border.all(color: accentColor.withValues(alpha: 0.24)),
                ),
                child: Icon(
                  sprint != null ? Icons.timer_outlined : Icons.layers_outlined,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 18),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        sprint != null
                            ? '${sprint.name}${sprint.status == SprintStatus.active ? ' in progress' : ''}'
                            : (project?.name ?? 'Project Workspace'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sprint != null
                                  ? (sprint.status == SprintStatus.active
                                      ? 'ACTIVE SPRINT'
                                      : sprint.status.label.toUpperCase())
                                  : (project?.isArchived == true ? 'ARCHIVED' : 'ACTIVE'),
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    sprint?.goal?.isNotEmpty == true
                        ? sprint!.goal!
                        : (project?.description?.isNotEmpty == true
                            ? project!.description!
                            : 'Plan sprints, track issue velocity, and collaborate across your team.'),
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (memberNames.isNotEmpty)
                        UserAvatarGroup(
                          names: memberNames,
                          size: UserAvatarSize.xs,
                          maxVisible: 4,
                        ),
                      Text(
                        sprint != null
                            ? '${state.members.length} ${state.members.length == 1 ? 'member' : 'members'} · ${sprint.dateRangeText}'
                            : '${state.members.length} ${state.members.length == 1 ? 'member' : 'members'} · Key: ${project?.key ?? 'OVS'}',
                        style: TextStyle(fontSize: 10.5, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        final progressBlock = SizedBox(
          width: isCompact ? double.infinity : 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sprint Progress', style: TextStyle(fontSize: 11, color: textSecondary)),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0,
                  minHeight: 4.5,
                  backgroundColor: accentColor.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '$completed/$total issues completed',
                      style: TextStyle(fontSize: 10, color: textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (sprint?.daysRemaining != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${sprint!.daysRemaining} days left',
                      style: TextStyle(fontSize: 10, color: textMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => context.go(
                    sprint != null
                        ? AppRoutes.projectBoardPath(workspaceId, projectId)
                        : AppRoutes.projectSprintsPath(workspaceId, projectId),
                  ),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sprint != null ? 'Open Sprint Board' : 'Plan First Sprint',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: accentColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentSoft.withValues(alpha: isDark ? 0.72 : 0.85),
                  AppColors.surfaceFor(isDark),
                ],
                stops: const [0.08, 0.75],
              ),
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(
                color: Color.lerp(borderColor, accentColor, 0.28) ?? borderColor,
              ),
            ),
            child: Stack(
              children: [
                // Subtle decorative concentric ring watermark matching Figma node 1:496
                if (!isCompact)
                  Positioned(
                    right: 170,
                    top: -95,
                    child: IgnorePointer(
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.03),
                              spreadRadius: 24,
                            ),
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.02),
                              spreadRadius: 48,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(isCompact ? 16 : 22),
                  child: isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            infoBlock,
                            const SizedBox(height: 16),
                            progressBlock,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: infoBlock),
                            const SizedBox(width: 24),
                            progressBlock,
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
