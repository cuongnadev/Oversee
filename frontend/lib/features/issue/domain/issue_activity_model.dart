import 'package:equatable/equatable.dart';

/// Represents an audit log entry for issue attribute modifications.
class IssueActivityModel extends Equatable {
  final String id;
  final String issueId;
  final String actorId;
  final String action;
  final String? oldValue;
  final String? newValue;
  final DateTime createdAt;
  final String? actorName;

  const IssueActivityModel({
    required this.id,
    required this.issueId,
    required this.actorId,
    required this.action,
    this.oldValue,
    this.newValue,
    required this.createdAt,
    this.actorName,
  });

  /// Human-readable label for the action type.
  String get actionLabel {
    switch (action.toLowerCase()) {
      case 'status_changed':
        return 'changed status';
      case 'priority_changed':
        return 'changed priority';
      case 'assignee_changed':
        return 'changed assignee';
      case 'title_changed':
        return 'updated title';
      case 'description_changed':
        return 'updated description';
      case 'estimate_changed':
        return 'updated story points';
      case 'subissue_added':
        return 'added sub-task';
      case 'created':
        return 'created issue';
      case 'reordered':
        return 'reordered backlog';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  /// Relative time description (e.g. "Just now", "5m ago", "2h ago", "Yesterday").
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Formatted change summary (e.g. "To Do -> In Progress").
  String? get transitionText {
    if (oldValue != null && newValue != null) {
      return '$oldValue  →  $newValue';
    } else if (newValue != null) {
      return newValue;
    }
    return null;
  }

  factory IssueActivityModel.fromJson(Map<String, dynamic> json) {
    return IssueActivityModel(
      id: json['id'] as String,
      issueId: json['issue_id'] as String,
      actorId: json['actor_id'] as String,
      action: json['action'] as String? ?? 'updated',
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      actorName: json['actor_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'actor_id': actorId,
      'action': action,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': createdAt.toIso8601String(),
      if (actorName != null) 'actor_name': actorName,
    };
  }

  @override
  List<Object?> get props => [
        id,
        issueId,
        actorId,
        action,
        oldValue,
        newValue,
        createdAt,
        actorName,
      ];
}
