import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';

/// Bar Chart widget displaying issue distribution by `IssuePriority` aligned with Figma charts.
class PriorityBreakdownWidget extends StatelessWidget {
  final DashboardState state;
  final bool isDark;

  const PriorityBreakdownWidget({
    super.key,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final priorityCounts = state.priorityCounts;
    final totalIssues = state.totalTasks;
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final chartGrid = AppColors.chartGridFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    const priorities = [
      IssuePriority.urgent,
      IssuePriority.high,
      IssuePriority.medium,
      IssuePriority.low,
      IssuePriority.lowest,
    ];

    int maxCount = 0;
    for (final p in priorities) {
      final count = priorityCounts[p] ?? 0;
      if (count > maxCount) maxCount = count;
    }
    final maxY = max(4.0, (maxCount * 1.25).ceilToDouble());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority Breakdown',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Distribution by urgency and business impact',
            style: TextStyle(fontSize: 11.5, color: textMuted),
          ),
          const SizedBox(height: 18),

          if (totalIssues == 0)
            SizedBox(
              height: 196,
              child: Center(
                child: Text(
                  'No issues recorded in this sprint.',
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
              ),
            )
          else
            Semantics(
              label:
                  'Priority breakdown bar chart. Urgent: ${priorityCounts[IssuePriority.urgent] ?? 0}, High: ${priorityCounts[IssuePriority.high] ?? 0}, Medium: ${priorityCounts[IssuePriority.medium] ?? 0}, Low: ${priorityCounts[IssuePriority.low] ?? 0}, Lowest: ${priorityCounts[IssuePriority.lowest] ?? 0}',
              container: true,
              child: SizedBox(
                height: 196,
                child: RepaintBoundary(
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY / 4).clamp(1.0, 100.0),
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: chartGrid,
                          strokeWidth: 1,
                          dashArray: [3, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: (maxY / 4).clamp(1.0, 100.0),
                            getTitlesWidget: (value, meta) {
                              if (value % 1 != 0) return const SizedBox.shrink();
                              return Text(
                                value.toInt().toString(),
                                style: AppTypography.mono(isDark, fontSize: 10, color: textMuted),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= priorities.length) {
                                return const SizedBox.shrink();
                              }
                              final priority = priorities[index];
                              return Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  priority.label,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.surface2For(isDark),
                          tooltipBorder: BorderSide(color: borderColor),
                          tooltipBorderRadius: BorderRadius.circular(AppColors.radiusMd),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final priority = priorities[group.x.toInt()];
                            return BarTooltipItem(
                              '${priority.label}: ${rod.toY.toInt()} issues',
                              TextStyle(
                                color: priority.colorFor(brightness),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                      barGroups: List.generate(priorities.length, (index) {
                        final priority = priorities[index];
                        final count = priorityCounts[priority] ?? 0;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: count.toDouble(),
                              color: priority.colorFor(brightness),
                              width: 22,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY,
                                color: AppColors.surface2For(isDark),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
