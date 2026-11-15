import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/sprint/domain/sprint_complete_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';

enum RolloverAction {
  moveToBacklog,
  moveToNextSprint,
}

/// Dialog confirming sprint completion and managing rollover for incomplete issues.
class CompleteSprintDialog extends StatefulWidget {
  final SprintModel sprint;
  final SprintProgressModel? progress;
  final List<SprintModel> plannedSprints;
  final Future<SprintCompleteModel?> Function({String? targetSprintId}) onComplete;

  const CompleteSprintDialog({
    super.key,
    required this.sprint,
    this.progress,
    this.plannedSprints = const [],
    required this.onComplete,
  });

  @override
  State<CompleteSprintDialog> createState() => _CompleteSprintDialogState();
}

class _CompleteSprintDialogState extends State<CompleteSprintDialog> {
  RolloverAction _selectedAction = RolloverAction.moveToBacklog;
  String? _targetSprintId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.plannedSprints.isNotEmpty) {
      _targetSprintId = widget.plannedSprints.first.id;
    }
  }

  int get _completedIssuesCount => widget.progress?.completedIssues ?? 0;
  int get _incompleteIssuesCount => widget.progress?.remainingIssues ?? 0;
  int get _totalIssuesCount => widget.progress?.totalIssues ?? 0;

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final targetId = (_selectedAction == RolloverAction.moveToNextSprint)
        ? _targetSprintId
        : null;

    final result = await widget.onComplete(targetSprintId: targetId);

    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasIncompleteIssues = _incompleteIssuesCount > 0;
    final hasPlannedSprints = widget.plannedSprints.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Complete Sprint',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sprint Name & Duration
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sprint.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.sprint.dateRangeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary Stats (Completed vs Incomplete)
              Row(
                children: [
                  // Completed Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.task_alt, color: AppColors.success, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_completedIssuesCount',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            'of $_totalIssuesCount issue${_totalIssuesCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Incomplete Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasIncompleteIssues
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasIncompleteIssues
                              ? AppColors.warning.withValues(alpha: 0.4)
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                hasIncompleteIssues ? Icons.pending_actions : Icons.done_all,
                                color: hasIncompleteIssues ? AppColors.warning : AppColors.textMutedDark,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Incomplete',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_incompleteIssuesCount',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: hasIncompleteIssues ? AppColors.warning : AppColors.textMutedDark,
                            ),
                          ),
                          Text(
                            'issues open',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Rollover Section if there are open issues
              if (hasIncompleteIssues) ...[
                const Text(
                  'Select action for incomplete issues:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                // Option 1: Move to Product Backlog
                _buildRolloverOptionTile(
                  action: RolloverAction.moveToBacklog,
                  title: 'Move to Product Backlog',
                  subtitle: 'Issues will return to the backlog for future sprint allocation.',
                  isSelected: _selectedAction == RolloverAction.moveToBacklog,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),

                // Option 2: Move to Next Sprint
                _buildRolloverOptionTile(
                  action: RolloverAction.moveToNextSprint,
                  title: 'Move to Next Sprint',
                  subtitle: hasPlannedSprints
                      ? 'Transfer incomplete issues directly into an upcoming planned sprint.'
                      : 'No planned sprints available. Issues must be moved to backlog.',
                  isSelected: _selectedAction == RolloverAction.moveToNextSprint,
                  isDark: isDark,
                  enabled: hasPlannedSprints,
                  extraChild: (hasPlannedSprints && _selectedAction == RolloverAction.moveToNextSprint)
                      ? Padding(
                          padding: const EdgeInsets.only(left: 30, top: 4),
                          child: DropdownButtonFormField<String>(
                            initialValue: _targetSprintId,
                            decoration: InputDecoration(
                              labelText: 'Target Sprint',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: widget.plannedSprints.map((s) {
                              return DropdownMenuItem<String>(
                                value: s.id,
                                child: Text(s.name, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _targetSprintId = val);
                            },
                          ),
                        )
                      : null,
                ),
              ] else ...[
                // All issues completed banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.celebration, color: AppColors.success, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fantastic! All issues in this sprint were marked as Done. No rollover needed.',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSubmitting)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        else
                          const Icon(Icons.check, size: 18),
                        const SizedBox(width: 6),
                        Text(_isSubmitting ? 'Completing...' : 'Complete Sprint'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRolloverOptionTile({
    required RolloverAction action,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    bool enabled = true,
    Widget? extraChild,
  }) {
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primary;
    final borderColor = isSelected
        ? primaryColor
        : (isDark ? AppColors.borderDark : AppColors.borderLight);

    return InkWell(
      onTap: enabled ? () => setState(() => _selectedAction = action) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
          color: isSelected ? primaryColor.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected
                      ? primaryColor
                      : (enabled ? (isDark ? Colors.white54 : Colors.black45) : Colors.grey),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: enabled ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: enabled
                              ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (extraChild != null) ...[
              const SizedBox(height: 10),
              extraChild,
            ],
          ],
        ),
      ),
    );
  }
}
