import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/shared/widgets/app_badge.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Card row item representing an issue within the Product Backlog list aligned with Figma IssueTable.
class BacklogItemCard extends StatefulWidget {
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
  State<BacklogItemCard> createState() => _BacklogItemCardState();
}

class _BacklogItemCardState extends State<BacklogItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final issue = widget.issue;

    final typeColor = issue.type.colorFor(brightness);
    final bgColor = _isHovered ? AppColors.hoverFor(isDark) : AppColors.surfaceFor(isDark);
    final borderColor = _isHovered ? AppColors.textMutedFor(isDark).withValues(alpha: 0.45) : AppColors.borderFor(isDark);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(vertical: 2.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            hoverColor: Colors.transparent,
            onTap: () => IssueDetailDialog.show(
              context,
              projectId: widget.projectId,
              projectKey: widget.projectKey,
              issue: issue,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              child: Row(
                children: [
                  // Reorder drag handle indicator (Figma .issue-drag-handle)
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: _isHovered ? 1.0 : 0.48,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 16,
                          color: AppColors.textMutedFor(isDark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // Issue Type Icon
                  Tooltip(
                    message: issue.type.label,
                    child: Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm + 1.0),
                      ),
                      child: Icon(issue.type.icon, size: 14, color: typeColor),
                    ),
                  ),
                  const SizedBox(width: 10.0),

                  // Monospace Issue Key
                  Text(
                    issue.formattedKey(widget.projectKey),
                    style: AppTypography.mono(
                      isDark,
                      fontSize: 11.0,
                      color: AppColors.textMutedFor(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // Title
                  Expanded(
                    child: Text(
                      issue.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimaryFor(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10.0),

                  // Status Badge (Figma StatusBadge)
                  if (!isMobile) ...[
                    IssueStatusBadge(status: issue.status, isSmall: true),
                    const SizedBox(width: 8.0),
                  ],

                  // Sub-issue count pill
                  if (issue.subIssueCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.surface3For(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_tree_outlined,
                            size: 11.5,
                            color: AppColors.textSecondaryFor(isDark),
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            '${issue.completedSubIssueCount}/${issue.subIssueCount}',
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 10.5,
                              color: AppColors.textSecondaryFor(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                  ],

                  // Story Points monospace pill (Figma .points)
                  if (issue.estimate != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.surface2For(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: Border.all(color: AppColors.borderFor(isDark)),
                      ),
                      child: Text(
                        '${issue.estimate!.toStringAsFixed(issue.estimate!.truncateToDouble() == issue.estimate ? 0 : 1)} SP',
                        style: AppTypography.mono(
                          isDark,
                          fontSize: 10.5,
                          color: AppColors.textSecondaryFor(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                  ],

                  // Priority Badge
                  IssuePriorityBadge(
                    priority: issue.priority,
                    showLabel: !isMobile,
                    isSmall: true,
                  ),
                  const SizedBox(width: 10.0),

                  // Assignee Avatar
                  _buildAssigneeAvatar(context, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatar(BuildContext context, bool isDark) {
    final assignee = widget.issue.assignee;
    if (assignee != null) {
      final name = assignee.fullName.isNotEmpty ? assignee.fullName : assignee.email;
      return UserAvatar(
        name: name,
        size: UserAvatarSize.xs,
      );
    }

    return Tooltip(
      message: 'Unassigned',
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.surface3For(isDark),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderFor(isDark)),
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: 13,
          color: AppColors.textMutedFor(isDark),
        ),
      ),
    );
  }
}
