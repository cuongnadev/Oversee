import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Inline bar for quickly creating and inserting issues into the backlog aligned with Figma quick-add.
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
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted && _isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
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
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final typeColor = _selectedType.colorFor(brightness);
    final priorityColor = _selectedPriority.colorFor(brightness);
    final accentColor = AppColors.accentFor(isDark);
    final borderColor = _isFocused ? accentColor : AppColors.borderFor(isDark);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(isDark),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(
          color: borderColor,
          width: _isFocused ? 1.4 : 1.0,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: isDark ? 0.14 : 0.10),
                  blurRadius: 10.0,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Type selector popup button
          PopupMenuButton<IssueType>(
            tooltip: 'Select Issue Type',
            initialValue: _selectedType,
            onSelected: (type) => setState(() => _selectedType = type),
            child: Container(
              height: 30.0,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: isDark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: typeColor.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_selectedType.icon, size: 15, color: typeColor),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: typeColor),
                ],
              ),
            ),
            itemBuilder: (context) {
              return IssueType.values.map((t) {
                final c = t.colorFor(brightness);
                return PopupMenuItem<IssueType>(
                  value: t,
                  child: Row(
                    children: [
                      Icon(t.icon, size: 16, color: c),
                      const SizedBox(width: 10.0),
                      Text(t.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          const SizedBox(width: 7.0),

          // Priority popup button
          PopupMenuButton<IssuePriority>(
            tooltip: 'Select Priority',
            initialValue: _selectedPriority,
            onSelected: (priority) => setState(() => _selectedPriority = priority),
            child: Container(
              height: 30.0,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: isDark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: priorityColor.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_selectedPriority.icon, size: 15, color: priorityColor),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: priorityColor),
                ],
              ),
            ),
            itemBuilder: (context) {
              return IssuePriority.values.map((p) {
                final c = p.colorFor(brightness);
                return PopupMenuItem<IssuePriority>(
                  value: p,
                  child: Row(
                    children: [
                      Icon(p.icon, size: 16, color: c),
                      const SizedBox(width: 10.0),
                      Text(p.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
              style: TextStyle(
                fontSize: 13.0,
                color: AppColors.textPrimaryFor(isDark),
              ),
              decoration: InputDecoration(
                hintText: 'What needs to be done? Type and press Enter...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMutedFor(isDark),
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          const SizedBox(width: 8.0),

          // Create Button
          AppPrimaryButton(
            label: 'Add to Backlog',
            icon: Icons.add_rounded,
            height: 34.0,
            isLoading: state.isCreating,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
