import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/sprint/domain/sprint_complete_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';

enum RolloverAction {
  moveToBacklog,
  moveToNextSprint,
}

/// Dialog confirming sprint completion and rollover aligned with Figma Modal.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppColors.borderFor(isDark);
    final successColor = AppColors.successFor(isDark);
    final warningColor = AppColors.warningFor(isDark);
    final errorColor = AppColors.errorFor(isDark);

    final hasIncompleteIssues = _incompleteIssuesCount > 0;
    final hasPlannedSprints = widget.plannedSprints.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        side: BorderSide(color: borderColor),
      ),
      backgroundColor: AppColors.surfaceFor(isDark),
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoftFor(isDark),
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          ),
                          child: Icon(Icons.check_circle_rounded, color: successColor, size: 19),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Complete Sprint',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryFor(isDark),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMutedFor(isDark)),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                  ],
                ),
              ),

              // Modal Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sprint Name & Duration
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2For(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusLg),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.sprint.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryFor(isDark),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.sprint.dateRangeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryFor(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Summary Stats (Completed vs Incomplete)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoftFor(isDark),
                              borderRadius: BorderRadius.circular(AppColors.radiusLg),
                              border: Border.all(color: successColor.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.task_alt_rounded, color: successColor, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Completed',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimaryFor(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$_completedIssuesCount',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: successColor,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                Text(
                                  'of $_totalIssuesCount issue${_totalIssuesCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryFor(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: hasIncompleteIssues
                                  ? AppColors.warningSoftFor(isDark)
                                  : AppColors.surface2For(isDark),
                              borderRadius: BorderRadius.circular(AppColors.radiusLg),
                              border: Border.all(
                                color: hasIncompleteIssues
                                    ? warningColor.withValues(alpha: 0.35)
                                    : borderColor,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      hasIncompleteIssues ? Icons.pending_actions_rounded : Icons.done_all_rounded,
                                      color: hasIncompleteIssues ? warningColor : AppColors.textMutedFor(isDark),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Incomplete',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimaryFor(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$_incompleteIssuesCount',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: hasIncompleteIssues ? warningColor : AppColors.textMutedFor(isDark),
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                Text(
                                  'issues open',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryFor(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Rollover Section
                    if (hasIncompleteIssues) ...[
                      Text(
                        'Select action for incomplete issues:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryFor(isDark),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRolloverOptionTile(
                        action: RolloverAction.moveToBacklog,
                        title: 'Move to Product Backlog',
                        subtitle: 'Issues will return to the backlog for future sprint allocation.',
                        isSelected: _selectedAction == RolloverAction.moveToBacklog,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
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
                                padding: const EdgeInsets.only(left: 28, top: 6),
                                child: DropdownButtonFormField<String>(
                                  initialValue: _targetSprintId,
                                  decoration: InputDecoration(
                                    labelText: 'Target Sprint',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                    ),
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoftFor(isDark),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          border: Border.all(color: successColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.celebration_rounded, color: successColor, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Fantastic! All issues in this sprint were marked as Done. No rollover needed.',
                                style: TextStyle(
                                  color: successColor,
                                  fontSize: 12.5,
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
                        style: TextStyle(color: errorColor, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),

              // Modal Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSubmitting)
                            const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.check_rounded, size: 17),
                          const SizedBox(width: 6),
                          Text(
                            _isSubmitting ? 'Completing...' : 'Complete Sprint',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    final accentColor = AppColors.accentFor(isDark);
    final borderColor = isSelected ? accentColor : AppColors.borderFor(isDark);

    return InkWell(
      onTap: enabled ? () => setState(() => _selectedAction = action) : null,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.4 : 1.0,
          ),
          color: isSelected ? AppColors.accentSoftFor(isDark).withValues(alpha: 0.45) : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? accentColor
                      : (enabled ? AppColors.textMutedFor(isDark) : AppColors.textMutedFor(isDark).withValues(alpha: 0.4)),
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: enabled ? AppColors.textPrimaryFor(isDark) : AppColors.textMutedFor(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: enabled
                              ? AppColors.textSecondaryFor(isDark)
                              : AppColors.textMutedFor(isDark).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (extraChild != null) ...[
              const SizedBox(height: 8),
              extraChild,
            ],
          ],
        ),
      ),
    );
  }
}
