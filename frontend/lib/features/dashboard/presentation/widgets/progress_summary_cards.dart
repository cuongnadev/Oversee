import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';

/// Row/Grid of summary KPI cards aligned with Figma `.kpi-grid` / `.kpi-card` + Sparkline.
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
    final brightness = isDark ? Brightness.dark : Brightness.light;
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

    final accentColor = AppColors.accentFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final warningColor = AppColors.warningFor(isDark);
    final errorColor = AppColors.errorFor(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          // 1. Story Points Burned Card
          _buildMetricCard(
            title: 'Story Points Progress',
            accentColor: accentColor,
            value: '${completedPoints.toInt()} / ${totalPoints.toInt()} pts',
            subValue: state.averageStoryPoints > 0
                ? '${pointsProgressPct.toStringAsFixed(0)}% done (Avg: ${state.averageStoryPoints.toStringAsFixed(1)} pts/task)'
                : '${pointsProgressPct.toStringAsFixed(0)}% completed (${remainingPoints.toInt()} pts left)',
            progressRatio: progress?.storyPointProgressRatio ?? 0.0,
            sparklinePositive: pointsProgressPct >= 40,
          ),

          // 2. Issues Completion Card
          _buildMetricCard(
            title: 'Issues Completed',
            accentColor: successColor,
            value: '$completedIssues of $totalIssues',
            subValue: '${issueProgressPct.toStringAsFixed(0)}% resolved ($remainingIssues open)',
            progressRatio: progress?.issueProgressRatio ?? 0.0,
            sparklinePositive: issueProgressPct >= 40,
          ),

          // 3. Sprint Remaining Duration
          _buildMetricCard(
            title: 'Sprint Timeline',
            accentColor: warningColor,
            value: sprint != null && sprint.status == SprintStatus.completed
                ? 'Completed'
                : (daysRemaining != null ? '$daysRemaining days left' : 'No end date'),
            subValue: sprint?.dateRangeText ?? 'Unscheduled',
            badgeText: sprint?.status.label.toUpperCase() ?? 'NONE',
            badgeColor: sprint?.status.colorFor(brightness) ?? AppColors.textMutedFor(isDark),
            sparklinePositive: true,
          ),

          // 4. Burn Velocity & Schedule Status
          _buildMetricCard(
            title: 'Burn Velocity & Forecast',
            accentColor: state.blockerTasks > 0
                ? errorColor
                : (isOnTrack ? successColor : warningColor),
            value: velocity > 0 ? '${velocity.toStringAsFixed(1)} pts/day' : '0.0 pts/day',
            subValue: state.blockerTasks > 0
                ? '${state.blockerTasks} blocker task(s) active'
                : (isOnTrack ? 'Pacing ahead of deadline' : 'Behind schedule - risk flagged'),
            badgeText: state.blockerTasks > 0
                ? '${state.blockerTasks} BLOCKER${state.blockerTasks == 1 ? '' : 'S'}'
                : (isOnTrack ? 'ON TRACK' : 'AT RISK'),
            badgeColor: state.blockerTasks > 0
                ? errorColor
                : (isOnTrack ? successColor : warningColor),
            sparklinePositive: state.blockerTasks == 0 && isOnTrack,
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
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[1]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[3]),
                  ],
                ),
              ),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 16),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required Color accentColor,
    required String value,
    required String subValue,
    required bool sparklinePositive,
    double? progressRatio,
    String? badgeText,
    Color? badgeColor,
  }) {
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Semantics(
      label: '$title: $value. $subValue',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(isDark),
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(color: AppColors.borderFor(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Muted title + corner dot or status badge (Figma .kpi-card)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (badgeText != null && badgeColor != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: isDark ? 0.16 : 0.11),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.28)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: badgeColor,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Value + Mini Sparkline Row (Figma .kpi-value-row)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.7,
                      height: 1.2,
                      color: textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  height: 22,
                  child: CustomPaint(
                    painter: _MiniSparklinePainter(
                      color: accentColor.withValues(alpha: 0.78),
                      positive: sparklinePositive,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Subtitle / Details
            Text(
              subValue,
              style: TextStyle(
                fontSize: 11,
                color: textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Optional thin Figma progress bar
            if (progressRatio != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progressRatio.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: AppColors.surface3For(isDark),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final Color color;
  final bool positive;

  const _MiniSparklinePainter({
    required this.color,
    required this.positive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = positive
        ? const [0.16, 0.28, 0.20, 0.42, 0.34, 0.58, 0.52, 0.76, 0.70, 0.94]
        : const [0.90, 0.74, 0.82, 0.62, 0.68, 0.48, 0.54, 0.30, 0.36, 0.16];

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height * (1.0 - values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.positive != positive;
  }
}
