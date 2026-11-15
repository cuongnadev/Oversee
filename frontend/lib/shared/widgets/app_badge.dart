import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';

/// Base badge container with soft-tinted background and saturated text.
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  final Widget? leading;
  final bool isSmall;
  final VoidCallback? onDeleted;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.icon,
    this.leading,
    this.isSmall = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveText = textColor ?? color;
    final double horizontalPadding = isSmall ? 6.0 : 8.0;
    final double verticalPadding = isSmall ? 2.0 : 4.0;
    final double fontSize = isSmall ? 11.0 : 12.0;
    final double iconSize = isSmall ? 12.0 : 14.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.0), // Pill shape
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 4.0),
          ] else if (icon != null) ...[
            Icon(icon, size: iconSize, color: effectiveText),
            const SizedBox(width: 4.0),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: effectiveText,
              letterSpacing: 0.2,
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 4.0),
            InkWell(
              onTap: onDeleted,
              borderRadius: BorderRadius.circular(10.0),
              child: Icon(Icons.close_rounded, size: iconSize, color: effectiveText),
            ),
          ],
        ],
      ),
    );
  }
}

/// Issue Status Badge mapping directly to Oversee backend `IssueStatus`.
class IssueStatusBadge extends StatelessWidget {
  final IssueStatus status;
  final bool isSmall;

  const IssueStatusBadge({
    super.key,
    required this.status,
    this.isSmall = false,
  });

  factory IssueStatusBadge.fromString(String? val, {bool isSmall = false, Key? key}) {
    return IssueStatusBadge(
      key: key,
      status: IssueStatus.fromString(val),
      isSmall: isSmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: status.label,
      color: status.color,
      icon: status.icon,
      isSmall: isSmall,
    );
  }
}

/// Issue Priority Badge mapping directly to Oversee backend `IssuePriority`.
class IssuePriorityBadge extends StatelessWidget {
  final IssuePriority priority;
  final bool showLabel;
  final bool isSmall;

  const IssuePriorityBadge({
    super.key,
    required this.priority,
    this.showLabel = true,
    this.isSmall = false,
  });

  factory IssuePriorityBadge.fromString(
    String? val, {
    bool showLabel = true,
    bool isSmall = false,
    Key? key,
  }) {
    return IssuePriorityBadge(
      key: key,
      priority: IssuePriority.fromString(val),
      showLabel: showLabel,
      isSmall: isSmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      final double size = isSmall ? 14.0 : 18.0;
      return Tooltip(
        message: 'Priority: ${priority.label}',
        child: Icon(priority.icon, size: size, color: priority.color),
      );
    }

    return AppBadge(
      label: priority.label,
      color: priority.color,
      icon: priority.icon,
      isSmall: isSmall,
    );
  }
}

/// Member Role Badge mapping directly to Oversee backend `RoleType`.
class RoleBadge extends StatelessWidget {
  final RoleType role;
  final bool isSmall;

  const RoleBadge({
    super.key,
    required this.role,
    this.isSmall = false,
  });

  factory RoleBadge.fromString(String? val, {bool isSmall = false, Key? key}) {
    return RoleBadge(
      key: key,
      role: RoleType.fromString(val),
      isSmall: isSmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: role.label,
      color: role.color,
      icon: role.icon,
      isSmall: isSmall,
    );
  }
}

/// Issue Type Badge mapping directly to Oversee backend `IssueType`.
class IssueTypeBadge extends StatelessWidget {
  final IssueType type;
  final bool showLabel;
  final bool isSmall;

  const IssueTypeBadge({
    super.key,
    required this.type,
    this.showLabel = true,
    this.isSmall = false,
  });

  factory IssueTypeBadge.fromString(
    String? val, {
    bool showLabel = true,
    bool isSmall = false,
    Key? key,
  }) {
    return IssueTypeBadge(
      key: key,
      type: IssueType.fromString(val),
      showLabel: showLabel,
      isSmall: isSmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      final double size = isSmall ? 14.0 : 18.0;
      return Tooltip(
        message: 'Type: ${type.label}',
        child: Icon(type.icon, size: size, color: type.color),
      );
    }

    return AppBadge(
      label: type.label,
      color: type.color,
      icon: type.icon,
      isSmall: isSmall,
    );
  }
}
