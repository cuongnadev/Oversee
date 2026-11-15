import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Inline bar for quickly creating and inserting issues into the backlog.
class QuickCreateIssueBar extends ConsumerStatefulWidget {
  final String projectId;

  const QuickCreateIssueBar({super.key, required this.projectId});

  @override
  ConsumerState<QuickCreateIssueBar> createState() => _QuickCreateIssueBarState();
}

class _QuickCreateIssueBarState extends ConsumerState<QuickCreateIssueBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  IssueType _selectedType = IssueType.task;
  IssuePriority _selectedPriority = IssuePriority.medium;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final notifier = ref.read(backlogNotifierProvider(widget.projectId).notifier);
    final success = await notifier.quickCreateIssue(
      title,
      type: _selectedType,
      priority: _selectedPriority,
    );

    if (success && mounted) {
      _controller.clear();
      _focusNode.requestFocus();
      AppFeedback.showSuccess(context, 'Issue added to backlog!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backlogNotifierProvider(widget.projectId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Type selector popup button
          PopupMenuButton<IssueType>(
            tooltip: 'Select Issue Type',
            initialValue: _selectedType,
            onSelected: (type) => setState(() => _selectedType = type),
            child: Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: _selectedType.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Icon(_selectedType.icon, size: 20, color: _selectedType.color),
            ),
            itemBuilder: (context) {
              return IssueType.values.map((t) {
                return PopupMenuItem<IssueType>(
                  value: t,
                  child: Row(
                    children: [
                      Icon(t.icon, size: 18, color: t.color),
                      const SizedBox(width: 10.0),
                      Text(t.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          const SizedBox(width: 8.0),
          // Priority popup button
          PopupMenuButton<IssuePriority>(
            tooltip: 'Select Priority',
            initialValue: _selectedPriority,
            onSelected: (priority) => setState(() => _selectedPriority = priority),
            child: Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: _selectedPriority.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Icon(_selectedPriority.icon, size: 20, color: _selectedPriority.color),
            ),
            itemBuilder: (context) {
              return IssuePriority.values.map((p) {
                return PopupMenuItem<IssuePriority>(
                  value: p,
                  child: Row(
                    children: [
                      Icon(p.icon, size: 18, color: p.color),
                      const SizedBox(width: 10.0),
                      Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          const SizedBox(width: 12.0),
          // Text Input
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !state.isCreating,
              decoration: const InputDecoration(
                hintText: 'What needs to be done? Type and press Enter...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8.0),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          const SizedBox(width: 8.0),
          // Create Button
          AppPrimaryButton(
            label: 'Add to Backlog',
            icon: Icons.add,
            isLoading: state.isCreating,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
