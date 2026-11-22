import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';

/// Sprint group with its issues and completion metrics returned by `GET /projects/{id}/backlog/grouped`.
class BacklogSprintGroupModel extends Equatable {
  final SprintModel sprint;
  final List<IssueModel> issues;
  final int totalIssues;
  final int completedIssues;
  final double totalStoryPoints;
  final double completedStoryPoints;
  final double completionPercentage;

  const BacklogSprintGroupModel({
    required this.sprint,
    required this.issues,
    required this.totalIssues,
    required this.completedIssues,
    required this.totalStoryPoints,
    required this.completedStoryPoints,
    required this.completionPercentage,
  });

  double get completionRatio => totalIssues > 0 ? (completedIssues / totalIssues).clamp(0.0, 1.0) : 0.0;

  factory BacklogSprintGroupModel.fromJson(Map<String, dynamic> json) {
    final rawIssues = json['issues'] as List<dynamic>? ?? const [];
    final parsedIssues = rawIssues
        .map((e) => IssueModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return BacklogSprintGroupModel(
      sprint: SprintModel.fromJson(json['sprint'] as Map<String, dynamic>),
      issues: parsedIssues,
      totalIssues: (json['total_issues'] as int?) ?? parsedIssues.length,
      completedIssues: (json['completed_issues'] as int?) ??
          parsedIssues.where((i) => i.status == IssueStatus.done).length,
      totalStoryPoints: (json['total_story_points'] as num?)?.toDouble() ??
          parsedIssues.fold<double>(0.0, (s, i) => s + (i.estimate ?? 0.0)),
      completedStoryPoints: (json['completed_story_points'] as num?)?.toDouble() ?? 0.0,
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  BacklogSprintGroupModel withIssues(List<IssueModel> nextIssues) {
    final total = nextIssues.length;
    final done = nextIssues.where((i) => i.status == IssueStatus.done).length;
    final pts = nextIssues.fold<double>(0.0, (s, i) => s + (i.estimate ?? 0.0));
    final donePts = nextIssues
        .where((i) => i.status == IssueStatus.done)
        .fold<double>(0.0, (s, i) => s + (i.estimate ?? 0.0));
    return BacklogSprintGroupModel(
      sprint: sprint,
      issues: nextIssues,
      totalIssues: total,
      completedIssues: done,
      totalStoryPoints: pts,
      completedStoryPoints: donePts,
      completionPercentage: total > 0 ? (done / total * 100.0) : 0.0,
    );
  }

  @override
  List<Object?> get props => [
        sprint,
        issues,
        totalIssues,
        completedIssues,
        totalStoryPoints,
        completedStoryPoints,
        completionPercentage,
      ];
}

/// Complete sprint-grouped backlog payload.
class BacklogOverviewModel extends Equatable {
  final List<BacklogSprintGroupModel> sprints;
  final List<IssueModel> backlogIssues;
  final int totalIssues;
  final int backlogTotalIssues;
  final int backlogCompletedIssues;
  final double backlogStoryPoints;

  const BacklogOverviewModel({
    this.sprints = const [],
    this.backlogIssues = const [],
    this.totalIssues = 0,
    this.backlogTotalIssues = 0,
    this.backlogCompletedIssues = 0,
    this.backlogStoryPoints = 0.0,
  });

  factory BacklogOverviewModel.fromJson(Map<String, dynamic> json) {
    final rawSprints = json['sprints'] as List<dynamic>? ?? const [];
    final rawBacklog = json['backlog_issues'] as List<dynamic>? ?? const [];
    final sprints = rawSprints
        .map((e) => BacklogSprintGroupModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final backlogIssues = rawBacklog
        .map((e) => IssueModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return BacklogOverviewModel(
      sprints: sprints,
      backlogIssues: backlogIssues,
      totalIssues: (json['total_issues'] as int?) ??
          (backlogIssues.length + sprints.fold<int>(0, (s, g) => s + g.issues.length)),
      backlogTotalIssues: (json['backlog_total_issues'] as int?) ?? backlogIssues.length,
      backlogCompletedIssues: (json['backlog_completed_issues'] as int?) ??
          backlogIssues.where((i) => i.status == IssueStatus.done).length,
      backlogStoryPoints: (json['backlog_story_points'] as num?)?.toDouble() ??
          backlogIssues.fold<double>(0.0, (s, i) => s + (i.estimate ?? 0.0)),
    );
  }

  @override
  List<Object?> get props => [
        sprints,
        backlogIssues,
        totalIssues,
        backlogTotalIssues,
        backlogCompletedIssues,
        backlogStoryPoints,
      ];
}
