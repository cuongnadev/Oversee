import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/shared/widgets/app_badge.dart';

/// Card surfacing critical blockers, overdue issues and stagnant tasks aligned with Figma panels.
class RiskIssuesWidget extends StatelessWidget {
  final DashboardState state;
  final String workspaceId;
  final String projectId;
  final bool isDark;

  const RiskIssuesWidget({
    super.key,
    required this.state,
    required this.workspaceId,
    required this.projectId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final riskIssues = state.riskIssues;
    final projectKey = state.project?.key ?? 'OVS';
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoftColor = AppColors.borderSoftFor(isDark);
    final warningColor = AppColors.warningFor(isDark);
    final errorColor = AppColors.errorFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(
          color: riskIssues.isNotEmpty
              ? warningColor.withValues(alpha: 0.35)
              : borderColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 13),
            decoration: BoxDecoration(
              color: riskIssues.isNotEmpty
                  ? AppColors.warningSoftFor(isDark).withValues(alpha: isDark ? 0.55 : 0.65)
                  : AppColors.surface2For(isDark),
              border: Border(bottom: BorderSide(color: borderSoftColor)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      riskIssues.isNotEmpty ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                      color: riskIssues.isNotEmpty ? warningColor : successColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Attention Required (${riskIssues.length})',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Critical blockers & stagnant tasks',
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                ),
              ],
            ),
          ),

          // Content
          if (riskIssues.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: successColor, size: 18),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        'No risk issues detected. All active sprint tasks are pacing on schedule.',
                        style: TextStyle(fontSize: 12.5, color: textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: riskIssues.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: borderSoftColor),
              itemBuilder: (context, index) {
                final issue = riskIssues[index];
                final isOverdue = issue.status != IssueStatus.done &&
                    (issue.priority == IssuePriority.urgent);
                final isLingering = issue.status == IssueStatus.inProgress;

                return Semantics(
                  label:
                      'Risk issue ${issue.formattedKey(projectKey)}: ${issue.title}. ${isOverdue ? "Urgent Blocker." : ""} Status: ${issue.status.label}',
                  button: true,
                  child: InkWell(
                    hoverColor: AppColors.hoverFor(isDark),
                    onTap: () async {
                      await IssueDetailDialog.show(
                        context,
                        projectId: projectId,
                        projectKey: projectKey,
                        issue: issue,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 460;

                          final keyBadge = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.surface2For(isDark),
                              borderRadius: BorderRadius.circular(AppColors.radiusSm),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              issue.formattedKey(projectKey),
                              style: AppTypography.mono(
                                isDark,
                                fontSize: 10.5,
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );

                          final titleWidget = Text(
                            issue.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );

                          final riskBadge = isOverdue
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerSoftFor(isDark),
                                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                    border: Border.all(color: errorColor.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    'URGENT BLOCKER',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      color: errorColor,
                                    ),
                                  ),
                                )
                              : isLingering
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.warningSoftFor(isDark),
                                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                        border: Border.all(color: warningColor.withValues(alpha: 0.35)),
                                      ),
                                      child: Text(
                                        '3+ DAYS IN PROGRESS',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                          color: warningColor,
                                        ),
                                      ),
                                    )
                                  : null;

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    keyBadge,
                                    const SizedBox(width: 8),
                                    Expanded(child: titleWidget),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (riskBadge != null) riskBadge,
                                    IssueStatusBadge(status: issue.status, isSmall: true),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              keyBadge,
                              const SizedBox(width: 12),
                              Expanded(child: titleWidget),
                              if (riskBadge != null) ...[
                                const SizedBox(width: 12),
                                riskBadge,
                              ],
                              const SizedBox(width: 10),
                              IssueStatusBadge(status: issue.status, isSmall: true),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
