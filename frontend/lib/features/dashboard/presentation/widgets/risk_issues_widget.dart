import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';

/// Card surfacing critical blockers, overdue issues and stagnant tasks in progress.
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: riskIssues.isNotEmpty
              ? AppColors.warning.withValues(alpha: 0.4)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: riskIssues.isNotEmpty
                  ? AppColors.warning.withValues(alpha: 0.08)
                  : (isDark ? AppColors.surfaceDark : Colors.grey.shade50),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      riskIssues.isNotEmpty ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                      color: riskIssues.isNotEmpty ? AppColors.warning : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Attention Required (${riskIssues.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Critical blockers & stagnant tasks',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
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
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'No risk issues detected. All active sprint tasks are pacing on schedule.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
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
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
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
                    onTap: () async {
                    await IssueDetailDialog.show(
                      context,
                      projectId: projectId,
                      projectKey: projectKey,
                      issue: issue,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 450;

                        final keyBadge = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            issue.formattedKey(projectKey),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        );

                        final titleWidget = Text(
                          issue.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );

                        final riskBadge = isOverdue
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                                ),
                                child: const Text(
                                  'URGENT BLOCKER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                              )
                            : isLingering
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text(
                                      '3+ DAYS IN PROGRESS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
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
                                  _buildStatusBadge(issue.status),
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
                            _buildStatusBadge(issue.status),
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

  Widget _buildStatusBadge(IssueStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: status.color,
        ),
      ),
    );
  }
}
