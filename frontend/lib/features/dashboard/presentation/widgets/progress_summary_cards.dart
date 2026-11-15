import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';

/// Row/Grid of summary KPI cards showcasing velocity, story points burned,
/// remaining sprint duration and on-track status.
class ProgressSummaryCards extends StatelessWidget {
  final DashboardState state;
  final bool isDark;

  const ProgressSummaryCards({
    super.key,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final sprint = state.selectedSprint;

    final totalPoints = progress?.totalStoryPoints ?? 0.0;
    final completedPoints = progress?.completedStoryPoints ?? 0.0;
    final remainingPoints = progress?.remainingStoryPoints ?? 0.0;
    final pointsProgressPct = progress?.storyPointProgressPercentage ?? 0.0;

    final totalIssues = progress?.totalIssues ?? 0;
    final completedIssues = progress?.completedIssues ?? 0;
    final remainingIssues = progress?.remainingIssues ?? 0;
    final issueProgressPct = progress?.issueProgressPercentage ?? 0.0;

    final daysRemaining = sprint?.daysRemaining;
    final velocity = state.burnVelocityPerDay;
    final isOnTrack = state.isOnTrack;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          // 1. Story Points Burned Card
          _buildMetricCard(
            title: 'Story Points Progress',
            icon: Icons.pie_chart_outline_rounded,
            iconColor: AppColors.primary,
            value: '${completedPoints.toInt()} / ${totalPoints.toInt()} pts',
            subValue: '${pointsProgressPct.toStringAsFixed(0)}% completed (${remainingPoints.toInt()} pts left)',
            progressRatio: progress?.storyPointProgressRatio ?? 0.0,
            progressColor: AppColors.primary,
          ),

          // 2. Issues Completion Card
          _buildMetricCard(
            title: 'Issues Completed',
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.success,
            value: '$completedIssues of $totalIssues',
            subValue: '${issueProgressPct.toStringAsFixed(0)}% resolved ($remainingIssues open)',
            progressRatio: progress?.issueProgressRatio ?? 0.0,
            progressColor: AppColors.success,
          ),

          // 3. Sprint Remaining Duration
          _buildMetricCard(
            title: 'Sprint Timeline',
            icon: Icons.timer_outlined,
            iconColor: AppColors.warning,
            value: sprint != null && sprint.status == SprintStatus.completed
                ? 'Completed'
                : (daysRemaining != null ? '$daysRemaining days left' : 'No end date'),
            subValue: sprint?.dateRangeText ?? 'Unscheduled',
            badgeText: sprint?.status.label.toUpperCase() ?? 'NONE',
            badgeColor: sprint?.status.color ?? Colors.grey,
          ),

          // 4. Burn Velocity & Schedule Status
          _buildMetricCard(
            title: 'Burn Velocity & Forecast',
            icon: Icons.speed_rounded,
            iconColor: isOnTrack ? AppColors.success : AppColors.error,
            value: velocity > 0 ? '${velocity.toStringAsFixed(1)} pts/day' : '0.0 pts/day',
            subValue: isOnTrack ? 'Pacing ahead of deadline' : 'Behind schedule - risk flagged',
            badgeText: isOnTrack ? 'ON TRACK' : 'AT RISK',
            badgeColor: isOnTrack ? AppColors.success : AppColors.error,
          ),
        ];

        if (constraints.maxWidth < 640) {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: c,
                    ))
                .toList(),
          );
        } else if (constraints.maxWidth < 1100) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: cards
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String subValue,
    double? progressRatio,
    Color? progressColor,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Top Row: Icon + Title + Optional Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, color: iconColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null && badgeColor != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Primary Value
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle / Details
          Text(
            subValue,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),

          // Optional Progress Bar
          if (progressRatio != null && progressColor != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressRatio.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
