import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';
import 'package:frontend/shared/widgets/user_avatar.dart';

/// Widget showcasing workload balance aligned with Figma `.workload-mini` / `.panel`.
class WorkloadByAssigneeWidget extends StatelessWidget {
  final DashboardState state;
  final bool isDark;

  const WorkloadByAssigneeWidget({
    super.key,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final workloads = state.assigneeWorkloads;
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoftColor = AppColors.borderSoftFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

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
        children: [
          // Panel Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 13),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderSoftColor)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Workload by Assignee (${workloads.length})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                Text(
                  'Task allocation & completion rate',
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                ),
              ],
            ),
          ),

          if (workloads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No workload data available for this sprint.',
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: workloads.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: borderSoftColor),
              itemBuilder: (context, index) {
                final item = workloads[index];
                final isUnassigned = item.userId == null;

                return Semantics(
                  label:
                      'Workload for ${item.name}: ${item.totalIssues} issues, ${item.totalStoryPoints.toInt()} story points, ${item.completedIssues} of ${item.totalIssues} completed (${item.completionPercentage.toStringAsFixed(0)}%)',
                  container: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 380;

                        final avatar = isUnassigned
                            ? Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.surface3For(isDark),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: borderColor),
                                ),
                                child: Center(
                                  child: Text(
                                    '?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                    ),
                                  ),
                                ),
                              )
                            : UserAvatar(
                                name: item.name,
                                imageUrl: item.avatarUrl,
                                size: UserAvatarSize.sm,
                                showTooltip: false,
                              );

                        final nameColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.totalIssues} issue${item.totalIssues == 1 ? '' : 's'} · ${item.totalStoryPoints.toInt()} pts',
                              style: AppTypography.mono(isDark, fontSize: 10.5, color: textMuted),
                            ),
                          ],
                        );

                        final progressColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item.completedIssues} of ${item.totalIssues} done',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                                Text(
                                  '${item.completionPercentage.toStringAsFixed(0)}%',
                                  style: AppTypography.mono(
                                    isDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: item.completionRatio >= 1.0 ? successColor : textPrimary,
                                  ),
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
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  avatar,
                                  const SizedBox(width: 10),
                                  Expanded(child: nameColumn),
                                ],
                              ),
                              const SizedBox(height: 8),
                              progressColumn,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            avatar,
                            const SizedBox(width: 11),
                            Expanded(flex: 3, child: nameColumn),
                            const SizedBox(width: 14),
                            Expanded(flex: 4, child: progressColumn),
                          ],
                        );
                      },
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
