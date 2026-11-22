import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/shared/widgets/app_badge.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Card widget representing an individual issue inside a Kanban column aligned with Figma .issue-card.
class KanbanIssueCard extends StatefulWidget {
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
  State<KanbanIssueCard> createState() => _KanbanIssueCardState();
}

class _KanbanIssueCardState extends State<KanbanIssueCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final issue = widget.issue;

    final cardBg = _isHovered ? AppColors.surface2For(isDark) : AppColors.surfaceFor(isDark);
    final borderColor = _isHovered ? AppColors.textMutedFor(isDark) : AppColors.borderFor(isDark);
    final typeColor = issue.type.colorFor(brightness);
    final statusColor = issue.status.colorFor(brightness);

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 9),
        transform: Matrix4.translationValues(0.0, _isHovered ? -1.5 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? (isDark ? 0.30 : 0.08) : (isDark ? 0.16 : 0.035)),
              blurRadius: _isHovered ? 8.0 : 3.0,
              offset: Offset(0, _isHovered ? 3.0 : 1.5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            hoverColor: Colors.transparent,
            onTap: () async {
              await IssueDetailDialog.show(
                context,
                projectId: issue.projectId,
                projectKey: widget.projectKey,
                issue: issue,
              );
              if (widget.onUpdated != null) {
                widget.onUpdated!();
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row (Figma .card-key-row): Type icon, Monospace Key, Priority Badge
                  Row(
                    children: [
                      Icon(issue.type.icon, size: 14, color: typeColor),
                      const SizedBox(width: 6),
                      Text(
                        issue.formattedKey(widget.projectKey),
                        style: AppTypography.mono(
                          isDark,
                          fontSize: 10.5,
                          color: AppColors.textMutedFor(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IssuePriorityBadge(priority: issue.priority, isSmall: true),
                    ],
                  ),
                  const SizedBox(height: 9),

                  // Title Row (Figma .card-title): Status Icon + Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.5),
                        child: Icon(issue.status.icon, size: 13.5, color: statusColor),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          issue.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textPrimaryFor(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),

                  // Bottom Footer Row (Figma .card-footer): Meta, Points, Avatar
                  Row(
                    children: [
                      // Sub-issue progress pill
                      if (issue.subIssueCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface3For(isDark),
                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_box_outlined,
                                size: 11.5,
                                color: AppColors.textSecondaryFor(isDark),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${issue.completedSubIssueCount}/${issue.subIssueCount}',
                                style: AppTypography.mono(
                                  isDark,
                                  fontSize: 10,
                                  color: AppColors.textSecondaryFor(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      const Spacer(),

                      // Story Points monospace box (Figma .points)
                      if (issue.estimate != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface2For(isDark),
                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                            border: Border.all(color: AppColors.borderFor(isDark)),
                          ),
                          child: Text(
                            issue.estimate! % 1 == 0
                                ? '${issue.estimate!.toInt()} pts'
                                : '${issue.estimate} pts',
                            style: AppTypography.mono(
                              isDark,
                              fontSize: 10,
                              color: AppColors.textSecondaryFor(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],

                      // Assignee Avatar
                      _buildAssigneeAvatar(isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatar(bool isDark) {
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
