import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';

/// One finished task row shown when a heatmap day cell is tapped.
class _FinishedTaskItem extends StatelessWidget {
  const _FinishedTaskItem({required this.issue});

  final IssueModel issue;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final updated = issue.updatedAt;
    final subtitle = updated != null
        ? '${updated.month}/${updated.day} ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}'
        : null;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Icon(Icons.check_circle_rounded, size: 20, color: AppColors.successFor(isDark)),
      title: Text(
        issue.title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMutedFor(isDark)))
          : null,
      trailing: Icon(Icons.done, size: 18, color: AppColors.successFor(isDark)),
    );
  }
}
