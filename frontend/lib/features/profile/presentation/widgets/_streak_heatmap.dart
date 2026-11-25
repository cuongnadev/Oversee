import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/profile/domain/profile_domain.dart';

/// 12-month GitHub-style streak heatmap: one cell per day, color scaled by
/// finished-task count for that day. Tapping a cell reports its day + tasks.
class _StreakHeatmap extends ConsumerWidget {
  const _StreakHeatmap({
    required this.finishedIssues,
    required this.selectedDay,
    required this.onDayTap,
  });

  final List<IssueModel> finishedIssues;
  final DateTime? selectedDay;
  final void Function(DateTime day, List<IssueModel> tasks) onDayTap;

  static const _cellSize = 24.0;
  static const _cellGap = 2.0;

  /// Heatmap fill color per intensity level.
  Color _levelColor(BuildContext context, int level) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentSoft = AppColors.accentSoftFor(isDark);
    final accent = AppColors.accentFor(isDark);
    switch (level) {
      case 0:
        return AppColors.borderSoftFor(isDark);
      case 1:
        return accentSoft.withValues(alpha: 0.35);
      case 2:
        return accentSoft.withValues(alpha: 0.60);
      case 3:
        return accentSoft.withValues(alpha: 0.85);
      default:
        return accent;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groups = groupFinishedIssuesByDay(finishedIssues);
    final maxCount = groups.isEmpty
        ? 0
        : groups.values.map((tasks) => tasks.length).reduce((a, b) => a > b ? a : b);
    final today = startOfDay(DateTime.now());

    // 12 month columns, oldest first.
    final months = <DateTime>[];
    for (var m = 11; m >= 0; m--) {
      months.add(DateTime(today.year, today.month - m, 1));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.streakHeatmap,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 6 * (_cellSize + _cellGap) + _cellGap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: months.map((month) {
              final firstOfMonth = DateTime(month.year, month.month, 1);
              final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
              final startOffset = firstOfMonth.weekday - 1; // Monday = 1

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(6, (week) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(7, (weekday) {
                      final dayIndex = week * 7 + weekday - startOffset + 1;
                      final isInMonth = dayIndex >= 1 && dayIndex <= daysInMonth;
                      final day = isInMonth
                          ? DateTime(month.year, month.month, dayIndex)
                          : null;
                      final tasks = day != null ? groups[startOfDay(day)] ?? const <IssueModel>[] : const <IssueModel>[];
                      final count = tasks.length;
                      final level = heatmapLevel(count, maxCount);
                      final isSelected = day != null &&
                          selectedDay != null &&
                          startOfDay(day) == startOfDay(selectedDay!);
                      final color = _levelColor(context, level);
                      return Container(
                        width: _cellSize,
                        height: _cellSize,
                        margin: const EdgeInsets.all(_cellGap / 2),
                        child: isInMonth
                            ? _DayCell(
                                day: day!,
                                count: count,
                                color: color,
                                selected: isSelected,
                                onTap: () => onDayTap(day, tasks),
                              )
                            : Container(
                                width: _cellSize,
                                height: _cellSize,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                      );
                    }),
                  );
                }),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Single heatmap day cell: colored square, hover cursor, tap to inspect the day.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Tooltip(
      message: l10n.dayFinishedLabel('${day.month}/${day.day}', count),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: selected ? Border.all(color: color, width: 2) : null,
            ),
            child: count > 0
                ? Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
