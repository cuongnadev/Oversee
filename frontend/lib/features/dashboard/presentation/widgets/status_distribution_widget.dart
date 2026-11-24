import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';

/// Donut / Pie Chart widget aligned with Figma `StatusDonut`.
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
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

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
            'Status Distribution',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Proportion of issues across workflow columns',
            style: TextStyle(fontSize: 11.5, color: textMuted),
          ),
          const SizedBox(height: 16),

          if (totalIssues == 0)
            SizedBox(
              height: 218,
              child: Center(
                child: Text(
                  'No issues recorded in this sprint.',
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
              ),
            )
          else
            Column(
              children: [
                // Thin Ring Donut Chart (Figma .donut-chart)
                Semantics(
                  label:
                      'Status Distribution donut chart. Total tasks: $totalIssues. Todo: ${statusCounts[IssueStatus.todo] ?? 0}, In Progress: ${statusCounts[IssueStatus.inProgress] ?? 0}, In Review: ${statusCounts[IssueStatus.inReview] ?? 0}, Done: ${statusCounts[IssueStatus.done] ?? 0}',
                  container: true,
                  child: SizedBox(
                    width: 170,
                    height: 170,
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
                              centerSpaceRadius: 54,
                              sections: _buildSections(statusCounts, brightness),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$totalIssues',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.8,
                                  color: textPrimary,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                'Tasks',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2-Column Dot-Aligned Legend (Figma .donut-legend)
                Builder(
                  builder: (context) {
                    final entries = statusCounts.entries.toList();
                    final useTwoCols = MediaQuery.sizeOf(context).width >= 380;
                    if (!useTwoCols) {
                      return Column(
                        children: entries.map((e) => _buildLegendRow(e.key, e.value, totalIssues, brightness)).toList(),
                      );
                    }
                    return Column(
                      children: [
                        for (int i = 0; i < entries.length; i += 2) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildLegendRow(entries[i].key, entries[i].value, totalIssues, brightness),
                              ),
                              const SizedBox(width: 16),
                              if (i + 1 < entries.length)
                                Expanded(
                                  child: _buildLegendRow(
                                    entries[i + 1].key,
                                    entries[i + 1].value,
                                    totalIssues,
                                    brightness,
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox.shrink()),
                            ],
                          ),
                          if (i + 2 < entries.length) const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(IssueStatus status, int count, int total, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final pct = total > 0 ? (count / total * 100).round() : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: status.colorFor(brightness),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.label,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondaryFor(isDark)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count ($pct%)',
          style: AppTypography.mono(
            isDark,
            fontSize: 10.5,
            color: AppColors.textPrimaryFor(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(Map<IssueStatus, int> counts, Brightness brightness) {
    final List<PieChartSectionData> sections = [];
    int index = 0;

    for (final entry in counts.entries) {
      final status = entry.key;
      final count = entry.value;
      if (count == 0) continue;

      final isTouched = index == _touchedIndex;
      sections.add(
        PieChartSectionData(
          color: status.colorFor(brightness),
          value: count.toDouble(),
          showTitle: false,
          radius: isTouched ? 21.0 : 16.0,
        ),
      );
      index++;
    }

    return sections;
  }
}
