import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/profile/domain/profile_domain.dart';

IssueModel _issue({
  required String id,
  required int issueNumber,
  DateTime? updatedAt,
}) =>
    IssueModel(
      id: id,
      projectId: 'p',
      issueNumber: issueNumber,
      title: 'Task $issueNumber',
      reporterId: 'u',
      assigneeId: 'u',
      updatedAt: updatedAt,
    );

void main() {
  test('groupFinishedIssuesByDay groups by local day and skips null updatedAt', () {
    final issues = [
      _issue(id: 'a', issueNumber: 1, updatedAt: DateTime(2026, 10, 10, 14, 30)),
      _issue(id: 'b', issueNumber: 2, updatedAt: DateTime(2026, 10, 10, 9, 0)),
      _issue(id: 'c', issueNumber: 3, updatedAt: DateTime(2026, 10, 11, 20, 0)),
      _issue(id: 'd', issueNumber: 4), // null updatedAt → skipped
    ];

    final byDay = groupFinishedIssuesByDay(issues);

    expect(byDay.keys, hasLength(2));
    expect(byDay[DateTime(2026, 10, 10)]?.length, equals(2));
    expect(byDay[DateTime(2026, 10, 11)]?.length, equals(1));
  });

  test('heatmapLevel returns 0-4 and 0 for empty max', () {
    expect(heatmapLevel(0, 0), equals(0));
    expect(heatmapLevel(1, 10), equals(0));
    expect(heatmapLevel(3, 10), equals(1));
    expect(heatmapLevel(5, 10), equals(2));
    expect(heatmapLevel(8, 10), equals(3));
    expect(heatmapLevel(10, 10), equals(4));
  });

  test('dayKey formats yyyy-MM-dd', () {
    expect(dayKey(DateTime(2026, 1, 5)), equals('2026-01-05'));
  });

  test('startOfDay resets time to midnight', () {
    expect(startOfDay(DateTime(2026, 10, 10, 14, 30)), equals(DateTime(2026, 10, 10)));
  });
}
