import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:intl/intl.dart';

/// Dialog allowing project members to start a planned sprint aligned with Figma Modal.
class StartSprintDialog extends StatefulWidget {
  final SprintModel sprint;
  final bool hasOtherActiveSprint;
  final Future<bool> Function({DateTime? startDate, DateTime? endDate}) onStart;

  const StartSprintDialog({
    super.key,
    required this.sprint,
    this.hasOtherActiveSprint = false,
    required this.onStart,
  });

  @override
  State<StartSprintDialog> createState() => _StartSprintDialogState();
}

class _StartSprintDialogState extends State<StartSprintDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = widget.sprint.startDate ?? now;
    _endDate = widget.sprint.endDate ?? _startDate.add(const Duration(days: 14));
    if (!_endDate.isAfter(_startDate)) {
      _endDate = _startDate.add(const Duration(days: 14));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (!_endDate.isAfter(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 14));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate) ? _endDate : _startDate.add(const Duration(days: 1)),
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (widget.hasOtherActiveSprint) return;

    if (!_endDate.isAfter(_startDate)) {
      setState(() {
        _errorMessage = 'End date must be strictly after start date.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await widget.onStart(
      startDate: _startDate,
      endDate: _endDate,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');
    final borderColor = AppColors.borderFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final warningColor = AppColors.warningFor(isDark);
    final errorColor = AppColors.errorFor(isDark);

    final canStart = !widget.hasOtherActiveSprint &&
        !_isSubmitting &&
        widget.sprint.status == SprintStatus.planned;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        side: BorderSide(color: borderColor),
      ),
      backgroundColor: AppColors.surfaceFor(isDark),
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                            color: AppColors.accentSoftFor(isDark),
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          ),
                          child: Icon(Icons.play_arrow_rounded, color: accentColor, size: 19),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Start Sprint',
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
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
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
                          if (widget.sprint.goal != null && widget.sprint.goal!.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Goal: ${widget.sprint.goal}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondaryFor(isDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (widget.hasOtherActiveSprint)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoftFor(isDark),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          border: Border.all(color: warningColor.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: warningColor, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Another sprint is currently active. Oversee allows only one active sprint per project. Please complete or close the active sprint before starting this one.',
                                style: TextStyle(
                                  color: warningColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Text(
                      'Duration & Schedule',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryFor(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _isSubmitting ? null : _pickStartDate,
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                suffixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: AppColors.textMutedFor(isDark),
                                ),
                                filled: true,
                                fillColor: AppColors.bgFor(isDark),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              child: Text(
                                dateFormat.format(_startDate),
                                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimaryFor(isDark)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _isSubmitting ? null : _pickEndDate,
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                suffixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: AppColors.textMutedFor(isDark),
                                ),
                                filled: true,
                                fillColor: AppColors.bgFor(isDark),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              child: Text(
                                dateFormat.format(_endDate),
                                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimaryFor(isDark)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Duration: ${_endDate.difference(_startDate).inDays} days',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMutedFor(isDark),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
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
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentSolidFor(isDark),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: canStart ? _handleSubmit : null,
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
                            const Icon(Icons.play_arrow_rounded, size: 17),
                          const SizedBox(width: 6),
                          Text(_isSubmitting ? 'Starting...' : 'Start Sprint'),
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
}
