import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Role types mapped 100% to Oversee backend `RoleType`.
enum RoleType {
  owner('owner', 'Owner'),
  admin('admin', 'Admin'),
  member('member', 'Member'),
  viewer('viewer', 'Viewer');

  final String value;
  final String label;

  const RoleType(this.value, this.label);

  static RoleType fromString(String? val) {
    if (val == null) return RoleType.viewer;
    return RoleType.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => RoleType.viewer,
    );
  }

  Color get color {
    switch (this) {
      case RoleType.owner:
        return AppColors.primary;
      case RoleType.admin:
        return AppColors.secondary;
      case RoleType.member:
        return AppColors.success;
      case RoleType.viewer:
        return AppColors.textSecondaryLight;
    }
  }

  IconData get icon {
    switch (this) {
      case RoleType.owner:
        return Icons.verified_user_rounded;
      case RoleType.admin:
        return Icons.admin_panel_settings_rounded;
      case RoleType.member:
        return Icons.person_rounded;
      case RoleType.viewer:
        return Icons.visibility_rounded;
    }
  }
}

/// Issue categorization mapped 100% to Oversee backend `IssueType`.
enum IssueType {
  epic('epic', 'Epic'),
  story('story', 'Story'),
  task('task', 'Task'),
  bug('bug', 'Bug'),
  subtask('subtask', 'Subtask');

  final String value;
  final String label;

  const IssueType(this.value, this.label);

  static IssueType fromString(String? val) {
    if (val == null) return IssueType.task;
    return IssueType.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => IssueType.task,
    );
  }

  Color get color {
    switch (this) {
      case IssueType.epic:
        return const Color(0xFF8B5CF6); // Purple 500
      case IssueType.story:
        return const Color(0xFF10B981); // Green 500
      case IssueType.task:
        return const Color(0xFF3B82F6); // Blue 500
      case IssueType.bug:
        return const Color(0xFFEF4444); // Red 500
      case IssueType.subtask:
        return const Color(0xFF0EA5E9); // Sky 500
    }
  }

  IconData get icon {
    switch (this) {
      case IssueType.epic:
        return Icons.bolt_rounded;
      case IssueType.story:
        return Icons.bookmark_rounded;
      case IssueType.task:
        return Icons.check_box_outlined;
      case IssueType.bug:
        return Icons.bug_report_rounded;
      case IssueType.subtask:
        return Icons.subdirectory_arrow_right_rounded;
    }
  }
}

/// Issue workflow statuses mapped 100% to Oversee backend `IssueStatus`.
enum IssueStatus {
  backlog('backlog', 'Backlog'),
  todo('todo', 'To Do'),
  inProgress('in_progress', 'In Progress'),
  inReview('in_review', 'In Review'),
  done('done', 'Done'),
  canceled('canceled', 'Canceled');

  final String value;
  final String label;

  const IssueStatus(this.value, this.label);

  static IssueStatus fromString(String? val) {
    if (val == null) return IssueStatus.todo;
    final normalized = val.toLowerCase().replaceAll('-', '_').trim();
    return IssueStatus.values.firstWhere(
      (e) => e.value == normalized,
      orElse: () => IssueStatus.todo,
    );
  }

  Color get color {
    switch (this) {
      case IssueStatus.backlog:
        return AppColors.statusBacklog;
      case IssueStatus.todo:
        return AppColors.statusTodo;
      case IssueStatus.inProgress:
        return AppColors.statusInProgress;
      case IssueStatus.inReview:
        return AppColors.statusInReview;
      case IssueStatus.done:
        return AppColors.statusDone;
      case IssueStatus.canceled:
        return AppColors.statusCanceled;
    }
  }

  IconData get icon {
    switch (this) {
      case IssueStatus.backlog:
        return Icons.inventory_2_outlined;
      case IssueStatus.todo:
        return Icons.radio_button_unchecked_rounded;
      case IssueStatus.inProgress:
        return Icons.incomplete_circle_rounded;
      case IssueStatus.inReview:
        return Icons.rate_review_outlined;
      case IssueStatus.done:
        return Icons.check_circle_rounded;
      case IssueStatus.canceled:
        return Icons.cancel_outlined;
    }
  }
}

/// Issue priority levels mapped 100% to Oversee backend `IssuePriority`.
enum IssuePriority {
  lowest('lowest', 'Lowest'),
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  final String value;
  final String label;

  const IssuePriority(this.value, this.label);

  static IssuePriority fromString(String? val) {
    if (val == null) return IssuePriority.medium;
    return IssuePriority.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => IssuePriority.medium,
    );
  }

  Color get color {
    switch (this) {
      case IssuePriority.lowest:
        return AppColors.priorityLowest;
      case IssuePriority.low:
        return AppColors.priorityLow;
      case IssuePriority.medium:
        return AppColors.priorityMedium;
      case IssuePriority.high:
        return AppColors.priorityHigh;
      case IssuePriority.urgent:
        return AppColors.priorityUrgent;
    }
  }

  IconData get icon {
    switch (this) {
      case IssuePriority.lowest:
        return Icons.keyboard_double_arrow_down_rounded;
      case IssuePriority.low:
        return Icons.keyboard_arrow_down_rounded;
      case IssuePriority.medium:
        return Icons.drag_handle_rounded;
      case IssuePriority.high:
        return Icons.keyboard_arrow_up_rounded;
      case IssuePriority.urgent:
        return Icons.priority_high_rounded;
    }
  }
}

/// Sprint lifecycle status mapped 100% to Oversee backend `SprintStatus`.
enum SprintStatus {
  planned('planned', 'Planned'),
  active('active', 'Active'),
  completed('completed', 'Completed'),
  closed('closed', 'Closed');

  final String value;
  final String label;

  const SprintStatus(this.value, this.label);

  static SprintStatus fromString(String? val) {
    if (val == null) return SprintStatus.planned;
    return SprintStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => SprintStatus.planned,
    );
  }

  Color get color {
    switch (this) {
      case SprintStatus.planned:
        return AppColors.statusBacklog;
      case SprintStatus.active:
        return AppColors.primary;
      case SprintStatus.completed:
        return AppColors.success;
      case SprintStatus.closed:
        return AppColors.textMutedLight;
    }
  }
}
