import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:intl/intl.dart';

/// Interactive Burndown Chart component aligned with Figma `BurndownChart`.
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
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoftColor = AppColors.borderSoftFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final chartGrid = AppColors.chartGridFor(isDark);

    if (burndown.isEmpty) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 310),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2For(isDark),
                  borderRadius: BorderRadius.circular(AppColors.radiusXl),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(Icons.show_chart_rounded, size: 30, color: textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                'No Burndown Data Available',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Burndown data will accumulate daily as the sprint progresses.',
                style: TextStyle(fontSize: 12, color: textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Header + Legend (Figma .panel-header + .chart-subheading)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sprint Burndown Chart',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Story points remaining over sprint duration',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildLegendItem(
                      label: 'Actual Remaining',
                      color: accentColor,
                      isDashed: false,
                    ),
                    _buildLegendItem(
                      label: 'Ideal Burndown',
                      color: textMuted,
                      isDashed: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chart Area
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
            child: Semantics(
              label:
                  'Sprint burndown chart showing ideal and actual remaining story points across ${burndown.length} time points',
              container: true,
              child: SizedBox(
                height: 224,
                child: RepaintBoundary(
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
                          color: chartGrid,
                          strokeWidth: 1,
                          dashArray: [3, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            interval: (maxY / 4).clamp(1.0, 100.0),
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  '${value.toInt()}',
                                  style: AppTypography.mono(
                                    isDark,
                                    fontSize: 10,
                                    color: textMuted,
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
                            reservedSize: 26,
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
                                formattedDate = DateFormat('MMM d').format(parsed);
                              } catch (_) {}

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  formattedDate,
                                  style: TextStyle(fontSize: 10, color: textMuted),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.surface2For(isDark),
                          tooltipBorder: BorderSide(color: borderColor),
                          tooltipBorderRadius: BorderRadius.circular(AppColors.radiusMd),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final isIdeal = spot.barIndex == 0;
                              final label = isIdeal ? 'Ideal' : 'Actual';
                              final color = isIdeal ? textSecondary : accentColor;
                              return LineTooltipItem(
                                '$label: ${spot.y.toStringAsFixed(1)} pts',
                                TextStyle(
                                  color: color,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        // 1. Ideal Line (Dashed subtle)
                        LineChartBarData(
                          spots: idealSpots,
                          isCurved: false,
                          color: textMuted.withValues(alpha: 0.75),
                          barWidth: 1.4,
                          dashArray: [4, 5],
                          dotData: const FlDotData(show: false),
                        ),

                        // 2. Actual Remaining Line (Smooth Violet with Gradient Area Fill)
                        LineChartBarData(
                          spots: actualSpots,
                          isCurved: true,
                          curveSmoothness: 0.22,
                          preventCurveOverShooting: true,
                          color: accentColor,
                          barWidth: 2.4,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accentColor.withValues(alpha: 0.20),
                                accentColor.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3.0,
                                color: accentColor,
                                strokeWidth: 1.8,
                                strokeColor: surfaceColor,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Footnote bar (Figma .chart-footnote)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderSoftColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${progress.remainingStoryPoints.toInt()} pts remaining · ${progress.completedStoryPoints.toInt()} of ${progress.totalStoryPoints.toInt()} story points completed',
                    style: TextStyle(fontSize: 10.5, color: textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
        if (isDashed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 5, height: 1.5, color: color),
              const SizedBox(width: 2),
              Container(width: 5, height: 1.5, color: color),
            ],
          )
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textMutedFor(isDark)),
        ),
      ],
    );
  }
}
