import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/widgets/widgets.dart';

/// Modal dialog for creating a new planned sprint.
class CreateSprintDialog extends StatefulWidget {
  final Future<bool> Function({
    required String name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
    double? capacity,
  }) onSubmit;

  const CreateSprintDialog({
    super.key,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<bool> Function({
      required String name,
      String? goal,
      DateTime? startDate,
      DateTime? endDate,
      double? capacity,
    }) onSubmit,
  }) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Create New Sprint',
      child: CreateSprintDialog(onSubmit: onSubmit),
    );
  }

  @override
  State<CreateSprintDialog> createState() => _CreateSprintDialogState();
}

class _CreateSprintDialogState extends State<CreateSprintDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _goalController;
  late final TextEditingController _capacityController;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Sprint ${DateTime.now().month}.${DateTime.now().day}');
    _goalController = TextEditingController();
    _capacityController = TextEditingController(text: '30');

    // Default dates: today and 14 days later
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate!.add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate!.add(const Duration(days: 14));
        }
        _dateError = null;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 14)),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      if (_startDate != null && picked.isBefore(_startDate!)) {
        setState(() => _dateError = 'End date must be after start date');
        return;
      }
      setState(() {
        _endDate = picked;
        _dateError = null;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      setState(() => _dateError = 'End date must be after start date');
      return;
    }

    setState(() => _isSubmitting = true);

    final double? capacity = _capacityController.text.trim().isNotEmpty
        ? double.tryParse(_capacityController.text.trim())
        : null;

    final success = await widget.onSubmit(
      name: _nameController.text.trim(),
      goal: _goalController.text.trim().isEmpty ? null : _goalController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      capacity: capacity,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sprint Name
          AppTextFormField(
            controller: _nameController,
            label: 'Sprint Name *',
            hintText: 'e.g. Sprint 2 - Core Workflows',
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Sprint name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Sprint Goal
          AppTextFormField(
            controller: _goalController,
            label: 'Sprint Goal',
            hintText: 'What is the key objective of this sprint?',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Date Selection Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start Date',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickStartDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _startDate != null ? dateFormat.format(_startDate!) : 'Select date',
                              style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondaryDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'End Date',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickEndDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _endDate != null ? dateFormat.format(_endDate!) : 'Select date',
                              style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondaryDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_dateError != null) ...[
            const SizedBox(height: 6),
            Text(_dateError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: 16),

          // Capacity Limit
          AppTextFormField(
            controller: _capacityController,
            label: 'Capacity Limit (Story Points)',
            hintText: 'e.g. 30',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppOutlinedButton(
                label: 'Cancel',
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              AppPrimaryButton(
                label: 'Create Sprint',
                isLoading: _isSubmitting,
                onPressed: _handleSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
