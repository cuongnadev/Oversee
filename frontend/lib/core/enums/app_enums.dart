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

  Color get color => colorFor(Brightness.light);

  Color colorFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case RoleType.owner:
        return AppColors.accentFor(isDark);
      case RoleType.admin:
        return AppColors.infoFor(isDark);
      case RoleType.member:
        return AppColors.successFor(isDark);
      case RoleType.viewer:
        return AppColors.textSecondaryFor(isDark);
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

  Color get color => colorFor(Brightness.light);

  Color colorFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case IssueType.epic:
        return AppColors.accentFor(isDark);
      case IssueType.story:
        return AppColors.successFor(isDark);
      case IssueType.task:
        return AppColors.infoFor(isDark);
      case IssueType.bug:
        return AppColors.errorFor(isDark);
      case IssueType.subtask:
        return isDark ? const Color(0xFF6DBDC0) : const Color(0xFF23636B);
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

  Color get color => colorFor(Brightness.light);

  Color colorFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case IssueStatus.backlog:
        return isDark ? AppColors.statusTodoDark : AppColors.statusBacklog;
      case IssueStatus.todo:
        return isDark ? AppColors.statusTodoDark : AppColors.statusTodo;
      case IssueStatus.inProgress:
        return isDark ? AppColors.statusInProgressDark : AppColors.statusInProgress;
      case IssueStatus.inReview:
        return isDark ? AppColors.statusInReviewDark : AppColors.statusInReview;
      case IssueStatus.done:
        return isDark ? AppColors.statusDoneDark : AppColors.statusDone;
      case IssueStatus.canceled:
        return AppColors.textMutedFor(isDark);
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

  Color get color => colorFor(Brightness.light);

  Color colorFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case IssuePriority.lowest:
        return isDark ? AppColors.priorityLowDark : AppColors.priorityLowest;
      case IssuePriority.low:
        return isDark ? AppColors.priorityLowDark : AppColors.priorityLow;
      case IssuePriority.medium:
        return isDark ? AppColors.priorityMediumDark : AppColors.priorityMedium;
      case IssuePriority.high:
        return isDark ? AppColors.priorityHighDark : AppColors.priorityHigh;
      case IssuePriority.urgent:
        return isDark ? AppColors.priorityUrgentDark : AppColors.priorityUrgent;
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

  Color get color => colorFor(Brightness.light);

  Color colorFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case SprintStatus.planned:
        return AppColors.textSecondaryFor(isDark);
      case SprintStatus.active:
        return AppColors.accentFor(isDark);
      case SprintStatus.completed:
        return AppColors.successFor(isDark);
      case SprintStatus.closed:
        return AppColors.textMutedFor(isDark);
    }
  }
}
