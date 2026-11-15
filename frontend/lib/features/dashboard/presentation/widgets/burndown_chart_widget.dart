import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:intl/intl.dart';

/// Interactive Burndown Chart component using `fl_chart`.
/// Renders an Ideal line (dashed gray) and an Actual line (solid indigo/primary)
/// with touch/hover tooltips and responsive axes.
class BurndownChartWidget extends StatelessWidget {
  final SprintProgressModel progress;
  final bool isDark;

  const BurndownChartWidget({
    super.key,
    required this.progress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final burndown = progress.burndown;

    if (burndown.isEmpty) {
      return Container(
        width: double.infinity,
        height: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'No Burndown Data Available',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Burndown data will accumulate daily as the sprint progresses.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build Ideal and Actual spots
    final List<FlSpot> idealSpots = [];
    final List<FlSpot> actualSpots = [];
    double maxPoints = progress.totalStoryPoints > 0 ? progress.totalStoryPoints : 10.0;

    for (int i = 0; i < burndown.length; i++) {
      final point = burndown[i];
      idealSpots.add(FlSpot(i.toDouble(), point.idealRemaining));
      if (point.idealRemaining > maxPoints) {
        maxPoints = point.idealRemaining;
      }
      if (point.actualRemaining != null) {
        actualSpots.add(FlSpot(i.toDouble(), point.actualRemaining!));
        if (point.actualRemaining! > maxPoints) {
          maxPoints = point.actualRemaining!;
        }
      }
    }

    final maxY = (maxPoints * 1.15).ceilToDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title & Legend
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.trending_down_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sprint Burndown Chart',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Story points burned over sprint duration',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Legend
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildLegendItem(
                    label: 'Ideal Burndown',
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                    isDashed: true,
                  ),
                  _buildLegendItem(
                    label: 'Actual Remaining',
                    color: AppColors.primary,
                    isDashed: false,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Area
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (burndown.length - 1).toDouble().clamp(1.0, 100.0),
                minY: 0,
                maxY: maxY > 0 ? maxY : 10.0,
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
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: (maxY / 4).clamp(1.0, 100.0),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            '${value.toInt()} pts',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (burndown.length > 7 ? (burndown.length / 5).ceilToDouble() : 1.0),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= burndown.length) {
                          return const SizedBox.shrink();
                        }
                        final dateStr = burndown[index].date;
                        String formattedDate = dateStr;
                        try {
                          final parsed = DateTime.parse(dateStr);
                          formattedDate = DateFormat('MM/dd').format(parsed);
                        } catch (_) {}

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                    left: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isIdeal = spot.barIndex == 0;
                        final label = isIdeal ? 'Ideal' : 'Actual';
                        final color = isIdeal ? Colors.grey : AppColors.primary;
                        return LineTooltipItem(
                          '$label: ${spot.y.toStringAsFixed(1)} pts',
                          TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // 1. Ideal Line (Dashed)
                  LineChartBarData(
                    spots: idealSpots,
                    isCurved: false,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),

                  // 2. Actual Line (Solid Indigo)
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: false,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: isDark ? AppColors.cardDark : Colors.white,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required Color color,
    required bool isDashed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
