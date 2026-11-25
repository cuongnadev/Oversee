import 'package:frontend/features/issue/domain/issue_model.dart';

/// Groups finished issues by the local day of their [IssueModel.updatedAt].
/// Issues with a null `updatedAt` are skipped. Keys are start-of-day DateTimes.
Map<DateTime, List<IssueModel>> groupFinishedIssuesByDay(List<IssueModel> issues) {
  final Map<DateTime, List<IssueModel>> byDay = {};
  for (final issue in issues) {
    final updatedAt = issue.updatedAt;
    if (updatedAt == null) continue;
    final day = startOfDay(updatedAt.toLocal());
    (byDay[day] ??= <IssueModel>[]).add(issue);
  }
  return byDay;
}

/// Heatmap intensity level 0-4 (GitHub-style 5 levels).
/// Returns 0 when [maxCount] is 0; otherwise scales [count] against [maxCount].
int heatmapLevel(int count, int maxCount) {
  if (maxCount == 0) return 0;
  return ((count / maxCount) * 4).round().clamp(0, 4);
}

/// `yyyy-MM-dd` of the local day.
String dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// Start of the local day (time reset to 00:00:00).
DateTime startOfDay(DateTime day) => DateTime(day.year, day.month, day.day);
