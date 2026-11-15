import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';

/// Data point in the sprint burndown chart series.
class BurndownPointModel extends Equatable {
  final String date;
  final double idealRemaining;
  final double? actualRemaining;

  const BurndownPointModel({
    required this.date,
    required this.idealRemaining,
    this.actualRemaining,
  });

  factory BurndownPointModel.fromJson(Map<String, dynamic> json) {
    return BurndownPointModel(
      date: json['date'] as String? ?? '',
      idealRemaining: (json['ideal_remaining'] as num?)?.toDouble() ?? 0.0,
      actualRemaining: (json['actual_remaining'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'ideal_remaining': idealRemaining,
      if (actualRemaining != null) 'actual_remaining': actualRemaining,
    };
  }

  @override
  List<Object?> get props => [date, idealRemaining, actualRemaining];
}

/// Progress metrics entity mapped 1:1 to Oversee backend `SprintProgressResponse`.
class SprintProgressModel extends Equatable {
  final String sprintId;
  final String sprintName;
  final SprintStatus status;
  final int totalIssues;
  final int completedIssues;
  final int remainingIssues;
  final double issueProgressPercentage;
  final double totalStoryPoints;
  final double completedStoryPoints;
  final double remainingStoryPoints;
  final double storyPointProgressPercentage;
  final Map<String, int> statusBreakdown;
  final List<BurndownPointModel> burndown;

  const SprintProgressModel({
    required this.sprintId,
    required this.sprintName,
    required this.status,
    required this.totalIssues,
    required this.completedIssues,
    required this.remainingIssues,
    required this.issueProgressPercentage,
    required this.totalStoryPoints,
    required this.completedStoryPoints,
    required this.remainingStoryPoints,
    required this.storyPointProgressPercentage,
    this.statusBreakdown = const {},
    this.burndown = const [],
  });

  factory SprintProgressModel.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['status_breakdown'];
    final Map<String, int> breakdown = {};
    if (breakdownRaw is Map<String, dynamic>) {
      breakdownRaw.forEach((key, val) {
        if (val is num) breakdown[key] = val.toInt();
      });
    }

    final burndownRaw = json['burndown'];
    final List<BurndownPointModel> burndownList = [];
    if (burndownRaw is List<dynamic>) {
      for (final item in burndownRaw) {
        if (item is Map<String, dynamic>) {
          burndownList.add(BurndownPointModel.fromJson(item));
        }
      }
    }

    return SprintProgressModel(
      sprintId: json['sprint_id'] as String? ?? '',
      sprintName: json['sprint_name'] as String? ?? '',
      status: SprintStatus.fromString(json['status'] as String?),
      totalIssues: (json['total_issues'] as num?)?.toInt() ?? 0,
      completedIssues: (json['completed_issues'] as num?)?.toInt() ?? 0,
      remainingIssues: (json['remaining_issues'] as num?)?.toInt() ?? 0,
      issueProgressPercentage: (json['issue_progress_percentage'] as num?)?.toDouble() ?? 0.0,
      totalStoryPoints: (json['total_story_points'] as num?)?.toDouble() ?? 0.0,
      completedStoryPoints: (json['completed_story_points'] as num?)?.toDouble() ?? 0.0,
      remainingStoryPoints: (json['remaining_story_points'] as num?)?.toDouble() ?? 0.0,
      storyPointProgressPercentage:
          (json['story_point_progress_percentage'] as num?)?.toDouble() ?? 0.0,
      statusBreakdown: breakdown,
      burndown: burndownList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sprint_id': sprintId,
      'sprint_name': sprintName,
      'status': status.value,
      'total_issues': totalIssues,
      'completed_issues': completedIssues,
      'remaining_issues': remainingIssues,
      'issue_progress_percentage': issueProgressPercentage,
      'total_story_points': totalStoryPoints,
      'completed_story_points': completedStoryPoints,
      'remaining_story_points': remainingStoryPoints,
      'story_point_progress_percentage': storyPointProgressPercentage,
      'status_breakdown': statusBreakdown,
      'burndown': burndown.map((b) => b.toJson()).toList(),
    };
  }

  bool get hasIssues => totalIssues > 0;
  bool get hasStoryPoints => totalStoryPoints > 0;

  double get issueProgressRatio =>
      totalIssues > 0 ? (completedIssues / totalIssues).clamp(0.0, 1.0) : 0.0;

  double get storyPointProgressRatio =>
      totalStoryPoints > 0 ? (completedStoryPoints / totalStoryPoints).clamp(0.0, 1.0) : 0.0;

  @override
  List<Object?> get props => [
        sprintId,
        sprintName,
        status,
        totalIssues,
        completedIssues,
        remainingIssues,
        issueProgressPercentage,
        totalStoryPoints,
        completedStoryPoints,
        remainingStoryPoints,
        storyPointProgressPercentage,
        statusBreakdown,
        burndown,
      ];
}
