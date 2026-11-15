import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';

/// Card widget representing an individual issue inside a Kanban board column.
class KanbanIssueCard extends StatelessWidget {
  final IssueModel issue;
  final String projectKey;
  final VoidCallback? onUpdated;

  const KanbanIssueCard({
    super.key,
    required this.issue,
    required this.projectKey,
    this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 1),
      ),
      color: cardBg,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await IssueDetailDialog.show(
            context,
            projectId: issue.projectId,
            projectKey: projectKey,
            issue: issue,
          );
          if (onUpdated != null) {
            onUpdated!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Type icon, Key, Priority Indicator
              Row(
                children: [
                  Icon(
                    issue.type.icon,
                    size: 16,
                    color: issue.type.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    issue.formattedKey(projectKey),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.secondaryLight : AppColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  _buildPriorityIndicator(isDark),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                issue.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),

              // Bottom Row: Sub-issue progress, Story points, Assignee avatar
              Row(
                children: [
                  // Sub-issue progress pill
                  if (issue.subIssueCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_box_outlined,
                            size: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${issue.completedSubIssueCount}/${issue.subIssueCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Story Points estimate pill
                  if (issue.estimate != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 13,
                            color: isDark ? AppColors.secondaryLight : AppColors.secondaryDark,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            issue.estimate! % 1 == 0
                                ? '${issue.estimate!.toInt()} pts'
                                : '${issue.estimate} pts',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.secondaryLight : AppColors.secondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Assignee Avatar
                  _buildAssigneeAvatar(isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: issue.priority.color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: issue.priority.color.withAlpha(60),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            issue.priority.icon,
            size: 12,
            color: issue.priority.color,
          ),
          const SizedBox(width: 3),
          Text(
            issue.priority.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: issue.priority.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeAvatar(bool isDark) {
    if (issue.assignee != null) {
      final initials = issue.assignee!.initials;
      return CircleAvatar(
        radius: 12,
        backgroundColor: AppColors.primaryLight,
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 12,
      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
      child: Icon(
        Icons.person_outline,
        size: 14,
        color: isDark ? Colors.white38 : Colors.grey.shade600,
      ),
    );
  }
}
