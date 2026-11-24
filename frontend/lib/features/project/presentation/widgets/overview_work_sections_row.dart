import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_panel.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Three equal-width (`flex: 1` each) horizontal Overview sections:
/// 1. My Ongoing Jobs
/// 2. Upcoming Jobs
/// 3. Project Participant Workloads
///
/// Stacks vertically below 1024px for responsive tablet/mobile layouts.
class OverviewWorkSectionsRow extends StatelessWidget {
  final ProjectOverviewState state;
  final String workspaceId;
  final String projectId;
  final String? currentUserId;
  final bool isDark;
  final VoidCallback? onIssueUpdated;

  const OverviewWorkSectionsRow({
    super.key,
    required this.state,
    required this.workspaceId,
    required this.projectId,
    required this.currentUserId,
    required this.isDark,
    this.onIssueUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final projectKey = state.project?.key ?? 'PROJ';
    final ongoing = state.myOngoingJobsFor(currentUserId);
    final upcoming = state.upcomingJobs();
    final workloads = state.participantWorkloads;
    final sprintNames = {for (final s in state.sprints) s.id: s.name};

    final ongoingCard = _OngoingJobsCard(
      issues: ongoing,
      projectId: projectId,
      projectKey: projectKey,
      workspaceId: workspaceId,
      isDark: isDark,
      onIssueUpdated: onIssueUpdated,
    );

    final upcomingCard = _UpcomingJobsCard(
      issues: upcoming,
      sprintNames: sprintNames,
      projectId: projectId,
      projectKey: projectKey,
      workspaceId: workspaceId,
      isDark: isDark,
      onIssueUpdated: onIssueUpdated,
    );

    final workloadsCard = _ParticipantWorkloadsCard(
      workloads: workloads,
      isDark: isDark,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 1, child: ongoingCard),
                const SizedBox(width: 18),
                Expanded(flex: 1, child: upcomingCard),
                const SizedBox(width: 18),
                Expanded(flex: 1, child: workloadsCard),
              ],
            ),
          );
        }

        return Column(
          children: [
            ongoingCard,
            const SizedBox(height: 16),
            upcomingCard,
            const SizedBox(height: 16),
            workloadsCard,
          ],
        );
      },
    );
  }
}

class _OverviewSectionShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool isDark;
  final Widget? trailing;
  final Widget child;

  const _OverviewSectionShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.isDark,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoftColor = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderSoftColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: accentSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '$count',
                              style: AppTypography.mono(
                                isDark,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing!,
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _OngoingJobsCard extends StatelessWidget {
  final List<IssueModel> issues;
  final String projectId;
  final String projectKey;
  final String workspaceId;
  final bool isDark;
  final VoidCallback? onIssueUpdated;

  const _OngoingJobsCard({
    required this.issues,
    required this.projectId,
    required this.projectKey,
    required this.workspaceId,
    required this.isDark,
    this.onIssueUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accentColor = AppColors.accentFor(isDark);
    final borderSoftColor = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final visible = issues.take(6).toList();

    return _OverviewSectionShell(
      key: const Key('overview_section_ongoing_jobs'),
      title: l10n.myOngoingJobs,
      subtitle: l10n.myOngoingJobsSubtitle,
      count: issues.length,
      icon: Icons.play_circle_outline_rounded,
      iconColor: accentColor,
      iconBg: AppColors.accentSoftFor(isDark),
      isDark: isDark,
      trailing: issues.length > visible.length
          ? InkWell(
              onTap: () => context.go(AppRoutes.projectIssuesPath(workspaceId, projectId)),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  l10n.viewAll,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
                ),
              ),
            )
          : null,
      child: visible.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Center(
                child: Text(
                  l10n.noOngoingJobs,
                  style: TextStyle(fontSize: 12, color: textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int index = 0; index < visible.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: borderSoftColor),
                  Builder(
                    builder: (context) {
                      final issue = visible[index];
                      final statusColor = issue.status.colorFor(brightness);
                      final priorityColor = issue.priority.colorFor(brightness);

                      return InkWell(
                        onTap: () => IssueDetailPanel.show(
                          context,
                          projectId: projectId,
                          projectKey: projectKey,
                          issue: issue,
                          onIssueUpdated: onIssueUpdated,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Icon(issue.status.icon, size: 15, color: statusColor),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      issue.title,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          issue.formattedKey(projectKey),
                                          style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: priorityColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          l10n.priorityLabel(issue.priority),
                                          style: TextStyle(fontSize: 10.5, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                ),
                                child: Text(
                                  l10n.statusLabel(issue.status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

class _UpcomingJobsCard extends StatelessWidget {
  final List<IssueModel> issues;
  final Map<String, String> sprintNames;
  final String projectId;
  final String projectKey;
  final String workspaceId;
  final bool isDark;
  final VoidCallback? onIssueUpdated;

  const _UpcomingJobsCard({
    required this.issues,
    required this.sprintNames,
    required this.projectId,
    required this.projectKey,
    required this.workspaceId,
    required this.isDark,
    this.onIssueUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final infoColor = AppColors.infoFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final borderSoftColor = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final visible = issues.take(6).toList();
    final dateFmt = DateFormat('MMM d');

    return _OverviewSectionShell(
      key: const Key('overview_section_upcoming_jobs'),
      title: l10n.upcomingJobs,
      subtitle: l10n.upcomingJobsSubtitle,
      count: issues.length,
      icon: Icons.upcoming_rounded,
      iconColor: infoColor,
      iconBg: infoColor.withValues(alpha: 0.14),
      isDark: isDark,
      trailing: issues.length > visible.length
          ? InkWell(
              onTap: () => context.go(AppRoutes.projectCalendarPath(workspaceId, projectId)),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  l10n.viewAll,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
                ),
              ),
            )
          : null,
      child: visible.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Center(
                child: Text(
                  l10n.noUpcomingJobs,
                  style: TextStyle(fontSize: 12, color: textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int index = 0; index < visible.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: borderSoftColor),
                  Builder(
                    builder: (context) {
                      final issue = visible[index];
                      final sprintLabel = issue.sprintId != null ? sprintNames[issue.sprintId] : null;
                      final dateText = issue.startDate != null
                          ? '${l10n.startsLabel} ${dateFmt.format(issue.startDate!)}'
                          : (issue.endDate != null
                              ? '${l10n.dueLabel} ${dateFmt.format(issue.endDate!)}'
                              : (sprintLabel ?? l10n.statusLabel(issue.status)));

                      return InkWell(
                        onTap: () => IssueDetailPanel.show(
                          context,
                          projectId: projectId,
                          projectKey: projectKey,
                          issue: issue,
                          onIssueUpdated: onIssueUpdated,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(Icons.calendar_today_outlined, size: 14, color: infoColor),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      issue.title,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          issue.formattedKey(projectKey),
                                          style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
                                        ),
                                        if (sprintLabel != null) ...[
                                          Text(' · ', style: TextStyle(fontSize: 10.5, color: textMuted)),
                                          Flexible(
                                            child: Text(
                                              sprintLabel,
                                              style: TextStyle(fontSize: 10.5, color: textSecondary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2For(isDark),
                                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                  border: Border.all(color: AppColors.borderFor(isDark)),
                                ),
                                child: Text(
                                  dateText,
                                  style: AppTypography.mono(isDark, fontSize: 10, color: textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

class _ParticipantWorkloadsCard extends StatelessWidget {
  final List<ParticipantWorkloadItem> workloads;
  final bool isDark;

  const _ParticipantWorkloadsCard({
    required this.workloads,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final successColor = AppColors.successFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoftColor = AppColors.borderSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final visible = workloads.take(6).toList();

    return _OverviewSectionShell(
      key: const Key('overview_section_participant_workloads'),
      title: l10n.participantWorkloads,
      subtitle: l10n.participantWorkloadsSubtitle,
      count: workloads.length,
      icon: Icons.groups_outlined,
      iconColor: successColor,
      iconBg: AppColors.greenSoftFor(isDark),
      isDark: isDark,
      child: visible.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Center(
                child: Text(
                  l10n.noParticipantWorkloads,
                  style: TextStyle(fontSize: 12, color: textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int index = 0; index < visible.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: borderSoftColor),
                  Builder(
                    builder: (context) {
                      final item = visible[index];
                      final isUnassigned = item.userId == null;
                      final displayName = isUnassigned ? l10n.unassigned : item.name;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isUnassigned)
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface3For(isDark),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: borderColor),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '?',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: textMuted,
                                      ),
                                    ),
                                  )
                                else
                                  UserAvatar(
                                    name: displayName,
                                    imageUrl: item.avatarUrl,
                                    size: UserAvatarSize.xs,
                                    showTooltip: false,
                                  ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        l10n.issuesAndPoints(
                                          item.totalIssues,
                                          item.totalStoryPoints.round(),
                                        ),
                                        style: AppTypography.mono(isDark, fontSize: 10, color: textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.completionPercentage}%',
                                      style: AppTypography.mono(
                                        isDark,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: item.completionRatio >= 1.0 ? successColor : textPrimary,
                                      ),
                                    ),
                                    Text(
                                      l10n.doneOfTotal(item.completedIssues, item.totalIssues),
                                      style: TextStyle(fontSize: 10, color: textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: item.completionRatio,
                                minHeight: 4,
                                backgroundColor: AppColors.surface3For(isDark),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  item.completionRatio >= 1.0 ? successColor : accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}
