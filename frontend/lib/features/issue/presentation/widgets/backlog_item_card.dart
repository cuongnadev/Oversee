import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';

/// Card row item representing an issue within the Product Backlog list.
class BacklogItemCard extends StatelessWidget {
  final String projectId;
  final String projectKey;
  final IssueModel issue;
  final int index;

  const BacklogItemCard({
    super.key,
    required this.projectId,
    required this.projectKey,
    required this.issue,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () => IssueDetailDialog.show(
            context,
            projectId: projectId,
            projectKey: projectKey,
            issue: issue,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              children: [
                // Reorder drag handle indicator
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                // Type Icon
                Container(
                  padding: const EdgeInsets.all(5.0),
                  decoration: BoxDecoration(
                    color: issue.type.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Icon(issue.type.icon, size: 16, color: issue.type.color),
                ),
                const SizedBox(width: 10.0),
                // Issue Key
                Text(
                  issue.formattedKey(projectKey),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12.0),
                // Title
                Expanded(
                  child: Text(
                    issue.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12.0),
                // Sub-issue count pill
                if (issue.subIssueCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 12),
                        const SizedBox(width: 4.0),
                        Text(
                          '${issue.completedSubIssueCount}/${issue.subIssueCount}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
                // Story Points estimate badge
                if (issue.estimate != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      '${issue.estimate!.toStringAsFixed(issue.estimate!.truncateToDouble() == issue.estimate ? 0 : 1)} SP',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
                // Priority Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: issue.priority.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(issue.priority.icon, size: 14, color: issue.priority.color),
                      const SizedBox(width: 4.0),
                      Text(
                        issue.priority.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: issue.priority.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10.0),
                // Assignee Avatar
                _buildAssigneeAvatar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatar(BuildContext context) {
    if (issue.assignee != null) {
      final name = issue.assignee!.fullName.isNotEmpty
          ? issue.assignee!.fullName
          : issue.assignee!.email;
      return Tooltip(
        message: 'Assignee: $name',
        child: CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Unassigned',
      child: CircleAvatar(
        radius: 12,
        backgroundColor: Colors.grey.withValues(alpha: 0.15),
        child: const Icon(Icons.person_outline, size: 14, color: Colors.grey),
      ),
    );
  }
}
