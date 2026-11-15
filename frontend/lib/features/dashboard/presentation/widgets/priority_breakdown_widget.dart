import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';

/// Bar Chart widget displaying issue distribution by `IssuePriority`.
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
    final priorityCounts = state.priorityCounts;
    final totalIssues = state.totalTasks;

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
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Priority Breakdown',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Distribution by urgency and business impact',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (totalIssues == 0)
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'No issues recorded in this sprint.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).clamp(1.0, 100.0),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (maxY / 4).clamp(1.0, 100.0),
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= priorities.length) {
                            return const SizedBox.shrink();
                          }
                          final priority = priorities[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              priority.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      left: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final priority = priorities[group.x.toInt()];
                        return BarTooltipItem(
                          '${priority.label}: ${rod.toY.toInt()} issues',
                          TextStyle(
                            color: priority.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                          color: priority.color,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
