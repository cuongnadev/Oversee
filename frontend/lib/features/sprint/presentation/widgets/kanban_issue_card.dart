import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_dialog.dart';
import 'package:frontend/shared/widgets/app_badge.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Card widget representing an individual issue inside a Kanban column aligned with Figma IssueCard (node 6:602).
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
    final borderColor = _isHovered
        ? AppColors.accentFor(isDark).withValues(alpha: 0.55)
        : AppColors.borderFor(isDark);
    final typeColor = issue.type.colorFor(brightness);
    final statusColor = issue.status.colorFor(brightness);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: _isHovered ? (isDark ? 0.28 : 0.08) : (isDark ? 0.14 : 0.04),
                ),
                blurRadius: _isHovered ? 8.0 : 2.5,
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
                  onIssueUpdated: widget.onUpdated,
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1 (Figma 6:603): Monospace Key + Priority Badge
                    Row(
                      children: [
                        Text(
                          issue.formattedKey(widget.projectKey),
                          style: AppTypography.mono(
                            isDark,
                            fontSize: 10.5,
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IssuePriorityBadge(priority: issue.priority, isSmall: true),
                      ],
                    ),
                    const SizedBox(height: 9),

                    // Row 2 (Figma 6:611): Status Icon + Title
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
                              fontSize: 12.5,
                              height: 1.45,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),

                    // Row 3 (Figma 6:625 LabelBadge): Type pill indented under title
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          border: Border.all(color: AppColors.borderFor(isDark)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: typeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              issue.type.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Row 4 (Figma 6:630): Meta (date, sub-issues), Story Points, Assignee Avatar
                    Row(
                      children: [
                        if (issue.updatedAt != null || issue.createdAt != null) ...[
                          Icon(Icons.calendar_today_outlined, size: 10.5, color: textMuted),
                          const SizedBox(width: 3),
                          Text(
                            DateFormat('dd-MM').format(issue.updatedAt ?? issue.createdAt!),
                            style: TextStyle(fontSize: 9.5, color: textMuted),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (issue.subIssueCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.surface2For(isDark),
                              borderRadius: BorderRadius.circular(AppColors.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_box_outlined,
                                  size: 11,
                                  color: textSecondary,
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  '${issue.completedSubIssueCount}/${issue.subIssueCount}',
                                  style: AppTypography.mono(
                                    isDark,
                                    fontSize: 9.5,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const Spacer(),

                        // Story Points monospace box (Figma 6:650)
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
                                fontSize: 9.5,
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                        ],

                        // Assignee Avatar (Figma 6:653)
                        _buildAssigneeAvatar(isDark),
                      ],
                    ),
                  ],
                ),
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
