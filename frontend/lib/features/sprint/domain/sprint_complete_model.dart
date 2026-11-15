import 'package:equatable/equatable.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';

/// Response entity returned upon completing a sprint with issue rollover details.
class SprintCompleteModel extends Equatable {
  final SprintModel sprint;
  final int completedIssuesCount;
  final int incompleteIssuesCount;
  final String? movedToSprintId;
  final bool movedToBacklog;

  const SprintCompleteModel({
    required this.sprint,
    required this.completedIssuesCount,
    required this.incompleteIssuesCount,
    this.movedToSprintId,
    this.movedToBacklog = false,
  });

  factory SprintCompleteModel.fromJson(Map<String, dynamic> json) {
    return SprintCompleteModel(
      sprint: SprintModel.fromJson(json['sprint'] as Map<String, dynamic>),
      completedIssuesCount: (json['completed_issues_count'] as num?)?.toInt() ?? 0,
      incompleteIssuesCount: (json['incomplete_issues_count'] as num?)?.toInt() ?? 0,
      movedToSprintId: json['moved_to_sprint_id'] as String?,
      movedToBacklog: json['moved_to_backlog'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sprint': sprint.toJson(),
      'completed_issues_count': completedIssuesCount,
      'incomplete_issues_count': incompleteIssuesCount,
      if (movedToSprintId != null) 'moved_to_sprint_id': movedToSprintId,
      'moved_to_backlog': movedToBacklog,
    };
  }

  @override
  List<Object?> get props => [
        sprint,
        completedIssuesCount,
        incompleteIssuesCount,
        movedToSprintId,
        movedToBacklog,
      ];
}
