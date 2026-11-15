import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';

/// Donut / Pie Chart widget displaying distribution of tasks by `IssueStatus`.
class StatusDistributionWidget extends StatefulWidget {
  final DashboardState state;
  final bool isDark;

  const StatusDistributionWidget({
    super.key,
    required this.state,
    required this.isDark,
  });

  @override
  State<StatusDistributionWidget> createState() => _StatusDistributionWidgetState();
}

class _StatusDistributionWidgetState extends State<StatusDistributionWidget> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final statusCounts = widget.state.statusCounts;
    final totalIssues = widget.state.totalTasks;
    final isDark = widget.isDark;

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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.donut_large_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Distribution',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Proportion of issues across workflow columns',
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 380;

                final chart = Semantics(
                  label:
                      'Status Distribution donut chart. Total tasks: $totalIssues. Todo: ${statusCounts[IssueStatus.todo] ?? 0}, In Progress: ${statusCounts[IssueStatus.inProgress] ?? 0}, In Review: ${statusCounts[IssueStatus.inReview] ?? 0}, Done: ${statusCounts[IssueStatus.done] ?? 0}',
                  container: true,
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: RepaintBoundary(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touchedIndex = -1;
                                      return;
                                    }
                                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 3,
                              centerSpaceRadius: 44,
                              sections: _buildSections(statusCounts, totalIssues),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$totalIssues',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                'Tasks',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                final legend = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: statusCounts.entries.map((entry) {
                    final status = entry.key;
                    final count = entry.value;
                    final pct = totalIssues > 0 ? (count / totalIssues * 100) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                          Text(
                            '$count (${pct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: 16),
                      legend,
                    ],
                  );
                }

                return Row(
                  children: [
                    chart,
                    const SizedBox(width: 24),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(Map<IssueStatus, int> counts, int total) {
    final List<PieChartSectionData> sections = [];
    int index = 0;

    for (final entry in counts.entries) {
      final status = entry.key;
      final count = entry.value;
      if (count == 0) continue;

      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 32.0 : 26.0;

      sections.add(
        PieChartSectionData(
          color: status.color,
          value: count.toDouble(),
          title: '$count',
          radius: radius,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      index++;
    }

    return sections;
  }
}
