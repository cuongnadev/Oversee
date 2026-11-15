import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';

/// Widget showcasing workload balance, assigned task counts, and completion rates per team member.
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
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
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.people_outline_rounded, color: AppColors.secondaryLight, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Workload by Assignee (${workloads.length})',
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
                  'Task allocation & completion rate',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          // Content List
          if (workloads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No workload data available for this sprint.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: workloads.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
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
                        final isCompact = constraints.maxWidth < 420;

                        final avatar = CircleAvatar(
                          radius: 16,
                          backgroundColor: isUnassigned
                              ? (isDark ? Colors.white12 : Colors.grey.shade300)
                              : AppColors.primary.withValues(alpha: 0.2),
                          child: Text(
                            isUnassigned ? '?' : _getInitials(item.name),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUnassigned
                                  ? (isDark ? Colors.white70 : Colors.black54)
                                  : AppColors.primary,
                            ),
                          ),
                        );

                        final nameColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.totalIssues} issue${item.totalIssues == 1 ? '' : 's'} • ${item.totalStoryPoints.toInt()} pts',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                Text(
                                  '${item.completionPercentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.completionRatio >= 1.0
                                        ? AppColors.success
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: item.completionRatio,
                                minHeight: 6,
                                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  item.completionRatio >= 1.0 ? AppColors.success : AppColors.primary,
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
                                  const SizedBox(width: 12),
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
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: nameColumn),
                            const SizedBox(width: 16),
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

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
