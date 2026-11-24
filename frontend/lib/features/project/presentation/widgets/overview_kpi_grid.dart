import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';

/// 4-column Figma Overview KPI cards (node 1:518):
/// Total Issues, In Progress, Completed, Story Points — each with corner dot,
/// large tabular value, mini sparkline, and bottom trend/context line.
class OverviewKpiGrid extends StatelessWidget {
  final ProjectOverviewState state;
  final bool isDark;

  const OverviewKpiGrid({
    super.key,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = state.totalIssues;
    final inProgress = state.inProgressIssues;
    final inReview = state.inReviewIssues;
    final done = state.completedIssues;
    final completedPts = state.completedStoryPoints;
    final totalPts = state.totalStoryPoints;
    final pct = state.completionPercentage;

    final cards = [
      _OverviewKpiCard(
        title: 'Total Issues',
        value: '$total',
        dotColor: AppColors.textSecondaryFor(isDark),
        sparklineColor: AppColors.accentFor(isDark),
        deltaText: state.activeSprint != null ? state.activeSprint!.name : 'Project scope',
        deltaAccent: state.activeSprint != null,
        suffixText: '${state.todoIssues} to do',
        sparklinePoints: const [0.22, 0.34, 0.30, 0.50, 0.45, 0.66, 0.72, 0.90],
        isDark: isDark,
      ),
      _OverviewKpiCard(
        title: 'In Progress',
        value: '$inProgress',
        dotColor: AppColors.warningFor(isDark),
        sparklineColor: AppColors.warningFor(isDark),
        deltaText: '$inReview in review',
        deltaAccent: inProgress > 0,
        suffixText: 'active workflow',
        sparklinePoints: const [0.18, 0.25, 0.40, 0.36, 0.55, 0.50, 0.68, 0.80],
        isDark: isDark,
      ),
      _OverviewKpiCard(
        title: 'Completed',
        value: '$done',
        dotColor: AppColors.successFor(isDark),
        sparklineColor: AppColors.successFor(isDark),
        deltaText: '$pct%',
        deltaAccent: true,
        suffixText: 'of $total issues',
        sparklinePoints: const [0.14, 0.22, 0.30, 0.38, 0.52, 0.60, 0.74, 0.92],
        isDark: isDark,
      ),
      _OverviewKpiCard(
        title: 'Story Points',
        value: completedPts % 1 == 0 ? '${completedPts.toInt()}' : completedPts.toStringAsFixed(1),
        dotColor: AppColors.accentFor(isDark),
        sparklineColor: AppColors.accentFor(isDark),
        deltaText: totalPts > 0 ? '${(completedPts / totalPts * 100).round()}%' : '0%',
        deltaAccent: completedPts > 0,
        suffixText:
            '/ ${totalPts % 1 == 0 ? totalPts.toInt() : totalPts.toStringAsFixed(1)} planned pts',
        sparklinePoints: const [0.20, 0.28, 0.35, 0.48, 0.54, 0.68, 0.78, 0.88],
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: c,
                    ))
                .toList(),
          );
        }
        if (constraints.maxWidth < 1040) {
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
}

class _OverviewKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color dotColor;
  final Color sparklineColor;
  final String deltaText;
  final bool deltaAccent;
  final String suffixText;
  final List<double> sparklinePoints;
  final bool isDark;

  const _OverviewKpiCard({
    required this.title,
    required this.value,
    required this.dotColor,
    required this.sparklineColor,
    required this.deltaText,
    required this.deltaAccent,
    required this.suffixText,
    required this.sparklinePoints,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final successColor = AppColors.successFor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(isDark),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.borderFor(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.1,
                    height: 1.1,
                    color: textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 68,
                height: 26,
                child: CustomPaint(
                  painter: _OverviewSparklinePainter(
                    color: sparklineColor.withValues(alpha: 0.78),
                    points: sparklinePoints,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.north_east_rounded,
                size: 12,
                color: deltaAccent ? successColor : textMuted,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  deltaText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: deltaAccent ? successColor : textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  suffixText,
                  style: TextStyle(fontSize: 10.5, color: textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewSparklinePainter extends CustomPainter {
  final Color color;
  final List<double> points;

  const _OverviewSparklinePainter({
    required this.color,
    required this.points,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (points.length - 1);
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height * (1.0 - points[i].clamp(0.05, 0.95));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OverviewSparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.points != points;
  }
}
