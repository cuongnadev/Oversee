import 'package:equatable/equatable.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';

/// Domain model representing sprint planning summary metrics.
/// Mapped 100% to Oversee backend `SprintPlanningResponse`.
class SprintPlanningModel extends Equatable {
  final SprintModel sprint;
  final List<IssueModel> issues;
  final int totalIssues;
  final double totalEstimate;
  final double? capacity;
  final bool isOverCapacity;
  final String? warning;

  const SprintPlanningModel({
    required this.sprint,
    this.issues = const [],
    this.totalIssues = 0,
    this.totalEstimate = 0.0,
    this.capacity,
    this.isOverCapacity = false,
    this.warning,
  });

  /// Ratio of totalEstimate to capacity (0.0 to 1.0+).
  double get capacityUsageRatio {
    if (capacity == null || capacity! <= 0) return 0.0;
    return totalEstimate / capacity!;
  }

  /// Formatted capacity progress percentage string (e.g. "80%").
  String get capacityPercentageText {
    if (capacity == null || capacity! <= 0) return 'No limit';
    return '${(capacityUsageRatio * 100).toInt()}%';
  }

  SprintPlanningModel copyWith({
    SprintModel? sprint,
    List<IssueModel>? issues,
    int? totalIssues,
    double? totalEstimate,
    double? capacity,
    bool? isOverCapacity,
    String? warning,
  }) {
    return SprintPlanningModel(
      sprint: sprint ?? this.sprint,
      issues: issues ?? this.issues,
      totalIssues: totalIssues ?? this.totalIssues,
      totalEstimate: totalEstimate ?? this.totalEstimate,
      capacity: capacity ?? this.capacity,
      isOverCapacity: isOverCapacity ?? this.isOverCapacity,
      warning: warning ?? this.warning,
    );
  }

  factory SprintPlanningModel.fromJson(Map<String, dynamic> json) {
    final sprintObj = SprintModel.fromJson(json['sprint'] as Map<String, dynamic>);
    final issuesList = (json['issues'] as List<dynamic>? ?? [])
        .map((i) => IssueModel.fromJson(i as Map<String, dynamic>))
        .toList();

    return SprintPlanningModel(
      sprint: sprintObj,
      issues: issuesList,
      totalIssues: (json['total_issues'] as num?)?.toInt() ?? issuesList.length,
      totalEstimate: (json['total_estimate'] as num?)?.toDouble() ??
          issuesList.fold(0.0, (sum, i) => sum + (i.estimate ?? 0.0)),
      capacity: (json['capacity'] as num?)?.toDouble() ?? sprintObj.capacity,
      isOverCapacity: json['is_over_capacity'] as bool? ?? false,
      warning: json['warning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sprint': sprint.toJson(),
      'issues': issues.map((i) => i.toJson()).toList(),
      'total_issues': totalIssues,
      'total_estimate': totalEstimate,
      if (capacity != null) 'capacity': capacity,
      'is_over_capacity': isOverCapacity,
      if (warning != null) 'warning': warning,
    };
  }

  @override
  List<Object?> get props => [
        sprint,
        issues,
        totalIssues,
        totalEstimate,
        capacity,
        isOverCapacity,
        warning,
      ];
}
