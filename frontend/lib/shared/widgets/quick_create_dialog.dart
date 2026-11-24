import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/dashboard/application/dashboard_provider.dart';
import 'package:frontend/features/document/data/document_repository.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/application/project_issues_provider.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';
import 'package:frontend/features/sprint/application/sprint_overview_provider.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';
import 'package:frontend/shared/widgets/app_dialog.dart';
import 'package:frontend/shared/widgets/app_feedback.dart';
import 'package:frontend/shared/widgets/app_text_field.dart';

/// Entity categories supported by the Quick Create modal.
enum QuickCreateEntityType {
  issue('Issue', Icons.check_box_outlined, 'Create a task, story, or bug'),
  epic('Epic', Icons.bolt_rounded, 'Group a larger body of work'),
  sprint('Sprint', Icons.timer_outlined, 'Plan a new time-boxed iteration'),
  document('Document', Icons.description_outlined, 'Write a spec, RFC, or note');

  final String label;
  final IconData icon;
  final String subtitle;

  const QuickCreateEntityType(this.label, this.icon, this.subtitle);
}

/// Unified Quick Create modal allowing fast creation of Issue, Epic, Sprint, or Document
/// with full per-entity form validation and backend API integration.
class QuickCreateDialog extends ConsumerStatefulWidget {
  final String projectId;
  final QuickCreateEntityType initialType;
  final IssueStatus? initialStatus;
  final String? initialSprintId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final VoidCallback? onCreated;

  const QuickCreateDialog({
    super.key,
    required this.projectId,
    this.initialType = QuickCreateEntityType.issue,
    this.initialStatus,
    this.initialSprintId,
    this.initialStartDate,
    this.initialEndDate,
    this.onCreated,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String projectId,
    QuickCreateEntityType initialType = QuickCreateEntityType.issue,
    IssueStatus? initialStatus,
    String? initialSprintId,
    DateTime? initialStartDate,
    DateTime? initialEndDate,
    VoidCallback? onCreated,
  }) {
    return AppAdaptiveDialog.show<bool>(
      context,
      title: 'Quick Create',
      maxWidth: 580,
      child: QuickCreateDialog(
        projectId: projectId,
        initialType: initialType,
        initialStatus: initialStatus,
        initialSprintId: initialSprintId,
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
        onCreated: onCreated,
      ),
    );
  }

  @override
  ConsumerState<QuickCreateDialog> createState() => _QuickCreateDialogState();
}

class _QuickCreateDialogState extends ConsumerState<QuickCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late QuickCreateEntityType _activeType;

  // Shared / Issue / Epic / Document fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimateController = TextEditingController();
  IssueType _issueType = IssueType.task;
  late IssueStatus _issueStatus;
  IssuePriority _priority = IssuePriority.medium;
  String? _assigneeId;
  String? _sprintId;
  DateTime? _issueStartDate;
  DateTime? _issueEndDate;
  String? _issueDateError;

  // Reference options loaded for human-readable labels (no raw UUIDs shown)
  List<ProjectMemberModel> _members = const [];
  List<SprintModel> _sprints = const [];

  // Sprint fields
  final _sprintNameController = TextEditingController();
  final _sprintGoalController = TextEditingController();
  final _sprintCapacityController = TextEditingController();
  DateTime? _sprintStartDate;
  DateTime? _sprintEndDate;
  String? _dateError;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _activeType = widget.initialType;
    _issueStatus = widget.initialStatus ?? IssueStatus.todo;
    _sprintId = widget.initialSprintId;
    _issueStartDate = widget.initialStartDate;
    _issueEndDate = widget.initialEndDate;
    final now = DateTime.now();
    _sprintStartDate = DateTime(now.year, now.month, now.day);
    _sprintEndDate = _sprintStartDate!.add(const Duration(days: 14));
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    try {
      final results = await Future.wait([
        ref.read(projectRepositoryProvider).listProjectMembers(widget.projectId).catchError((_) => <ProjectMemberModel>[]),
        ref.read(sprintRepositoryProvider).listProjectSprints(widget.projectId).catchError((_) => <SprintModel>[]),
      ]);
      if (!mounted) return;
      final members = results[0] as List<ProjectMemberModel>;
      final sprints = (results[1] as List<SprintModel>)
          .where((s) => s.status != SprintStatus.completed && s.status != SprintStatus.closed)
          .toList();
      setState(() {
        _members = members;
        _sprints = sprints;
        if (_sprintId != null && !_sprints.any((s) => s.id == _sprintId)) {
          _sprintId = null;
        }
      });
    } catch (_) {
      // Safe fallback when repositories are not mocked in isolated widget tests
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimateController.dispose();
    _sprintNameController.dispose();
    _sprintGoalController.dispose();
    _sprintCapacityController.dispose();
    super.dispose();
  }

  void _switchEntityType(QuickCreateEntityType next) {
    if (_isSubmitting || _activeType == next) return;
    setState(() {
      _activeType = next;
      _submitError = null;
      _dateError = null;
    });
    _formKey.currentState?.reset();
  }

  String? _validateNonEmptyTitle(String? val, String fieldName) {
    final trimmed = val?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$fieldName is required';
    }
    if (trimmed.length > 255) {
      return '$fieldName must be 255 characters or less';
    }
    return null;
  }

  String? _validateNonNegativeNumber(String? val, String fieldName) {
    final trimmed = val?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return '$fieldName must be a valid number';
    }
    if (parsed < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  Future<void> _pickSprintDate({required bool isStart}) async {
    final initial = isStart
        ? (_sprintStartDate ?? DateTime.now())
        : (_sprintEndDate ?? (_sprintStartDate ?? DateTime.now()).add(const Duration(days: 14)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _sprintStartDate = picked;
        if (_sprintEndDate != null && !_sprintEndDate!.isAfter(picked)) {
          _dateError = 'End date must be strictly after start date';
        } else {
          _dateError = null;
        }
      } else {
        _sprintEndDate = picked;
        if (_sprintStartDate != null && !picked.isAfter(_sprintStartDate!)) {
          _dateError = 'End date must be strictly after start date';
        } else {
          _dateError = null;
        }
      }
    });
  }

  Future<void> _pickIssueDate({required bool isStart}) async {
    final initial = isStart
        ? (_issueStartDate ?? DateTime.now())
        : (_issueEndDate ?? (_issueStartDate ?? DateTime.now()).add(const Duration(days: 3)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _issueStartDate = picked;
        if (_issueEndDate != null && _issueEndDate!.isBefore(picked)) {
          _issueDateError = 'End date cannot be earlier than start date';
        } else {
          _issueDateError = null;
        }
      } else {
        _issueEndDate = picked;
        if (_issueStartDate != null && picked.isBefore(_issueStartDate!)) {
          _issueDateError = 'End date cannot be earlier than start date';
        } else {
          _issueDateError = null;
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _submitError = null;
      _dateError = null;
      _issueDateError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    if (_activeType == QuickCreateEntityType.issue) {
      if (_issueStartDate != null &&
          _issueEndDate != null &&
          _issueEndDate!.isBefore(_issueStartDate!)) {
        setState(() => _issueDateError = 'End date cannot be earlier than start date');
        return;
      }
    }

    if (_activeType == QuickCreateEntityType.sprint) {
      if (_sprintStartDate != null &&
          _sprintEndDate != null &&
          !_sprintEndDate!.isAfter(_sprintStartDate!)) {
        setState(() => _dateError = 'End date must be strictly after start date');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      String successMessage;
      switch (_activeType) {
        case QuickCreateEntityType.issue:
          final estimate = _estimateController.text.trim().isNotEmpty
              ? double.parse(_estimateController.text.trim())
              : null;
          await ref.read(issueRepositoryProvider).createIssue(
                widget.projectId,
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                type: _issueType,
                status: _issueStatus,
                priority: _priority,
                estimate: estimate,
                assigneeId: _assigneeId,
                sprintId: _sprintId,
                startDate: _issueStartDate,
                endDate: _issueEndDate,
              );
          ref.invalidate(backlogNotifierProvider(widget.projectId));
          ref.invalidate(kanbanBoardProvider(widget.projectId));
          ref.invalidate(projectIssuesProvider(widget.projectId));
          ref.invalidate(dashboardProvider(widget.projectId));
          successMessage = 'Issue created successfully';
          break;

        case QuickCreateEntityType.epic:
          final estimate = _estimateController.text.trim().isNotEmpty
              ? double.parse(_estimateController.text.trim())
              : null;
          await ref.read(issueRepositoryProvider).createIssue(
                widget.projectId,
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
                type: IssueType.epic,
                priority: _priority,
                estimate: estimate,
              );
          ref.invalidate(backlogNotifierProvider(widget.projectId));
          ref.invalidate(dashboardProvider(widget.projectId));
          successMessage = 'Epic created successfully';
          break;

        case QuickCreateEntityType.sprint:
          final capacity = _sprintCapacityController.text.trim().isNotEmpty
              ? double.parse(_sprintCapacityController.text.trim())
              : null;
          await ref.read(sprintRepositoryProvider).createSprint(
                widget.projectId,
                name: _sprintNameController.text.trim(),
                goal: _sprintGoalController.text.trim().isEmpty
                    ? null
                    : _sprintGoalController.text.trim(),
                startDate: _sprintStartDate,
                endDate: _sprintEndDate,
                capacity: capacity,
              );
          ref.invalidate(sprintOverviewProvider(widget.projectId));
          ref.invalidate(dashboardProvider(widget.projectId));
          successMessage = 'Sprint created successfully';
          break;

        case QuickCreateEntityType.document:
          await ref.read(documentRepositoryProvider).createDocument(
                widget.projectId,
                title: _titleController.text.trim(),
                content: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
              );
          successMessage = 'Document created successfully';
          break;
      }

      if (!mounted) return;
      widget.onCreated?.call();
      AppFeedback.showSuccess(context, successMessage);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException ? e.message : e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isSubmitting = false;
        _submitError = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppColors.borderFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Entity Type Segmented Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface2For(isDark),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: QuickCreateEntityType.values.map((entity) {
                final selected = _activeType == entity;
                return Expanded(
                  child: InkWell(
                    onTap: () => _switchEntityType(entity),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.surfaceFor(isDark) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm + 1),
                        border: selected
                            ? Border.all(color: accentColor.withValues(alpha: 0.35))
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entity.icon,
                            size: 14,
                            color: selected ? accentColor : textMuted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              entity.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected ? textPrimary : textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Contextual subtitle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Text(
                  _activeType.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _activeType.subtitle,
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Error Alert Banner
          if (_submitError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.dangerSoftFor(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: AppColors.errorFor(isDark).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: AppColors.errorFor(isDark)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _submitError!,
                      style: TextStyle(fontSize: 12, color: AppColors.errorFor(isDark)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Form Body per entity type
          if (_activeType == QuickCreateEntityType.issue) _buildIssueFields(isDark),
          if (_activeType == QuickCreateEntityType.epic) _buildEpicFields(isDark),
          if (_activeType == QuickCreateEntityType.sprint) _buildSprintFields(isDark),
          if (_activeType == QuickCreateEntityType.document) _buildDocumentFields(isDark),

          const SizedBox(height: 18),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 14),

          // Footer Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppOutlinedButton(
                label: 'Cancel',
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 10),
              AppPrimaryButton(
                label: 'Create ${_activeType.label}',
                icon: Icons.add_rounded,
                isLoading: _isSubmitting,
                onPressed: _handleSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueFields(bool isDark) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final dateFormat = DateFormat('MMM d, yyyy');
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextFormField(
          controller: _titleController,
          label: 'Issue Title',
          isRequired: true,
          hintText: 'e.g. Implement OAuth2 refresh token flow',
          validator: (v) => _validateNonEmptyTitle(v, 'Issue title'),
        ),
        const SizedBox(height: 12),
        AppTextFormField(
          controller: _descriptionController,
          label: 'Description',
          hintText: 'Add context, acceptance criteria, or reproduction steps...',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        // Row 1: Type & Status
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<IssueType>(
                isDark: isDark,
                label: 'Type',
                value: _issueType,
                items: const [IssueType.task, IssueType.story, IssueType.bug],
                itemBuilder: (t) => Row(
                  children: [
                    Icon(t.icon, size: 14, color: t.colorFor(brightness)),
                    const SizedBox(width: 6),
                    Text(t.label, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _issueType = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField<IssueStatus>(
                isDark: isDark,
                label: 'Status',
                value: _issueStatus,
                items: IssueStatus.values,
                itemBuilder: (s) => Row(
                  children: [
                    Icon(s.icon, size: 14, color: s.colorFor(brightness)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        s.label,
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _issueStatus = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Priority & Story Points
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<IssuePriority>(
                isDark: isDark,
                label: 'Priority',
                value: _priority,
                items: IssuePriority.values,
                itemBuilder: (p) => Row(
                  children: [
                    Icon(p.icon, size: 14, color: p.colorFor(brightness)),
                    const SizedBox(width: 6),
                    Text(p.label, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _priority = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextFormField(
                controller: _estimateController,
                label: 'Story Points',
                hintText: 'e.g. 5',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => _validateNonNegativeNumber(v, 'Story points'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 3: Assignee & Sprint (human-readable labels, never raw UUIDs)
        Row(
          children: [
            Expanded(
              child: _buildNullableDropdownField<String>(
                isDark: isDark,
                label: 'Assignee',
                value: _assigneeId,
                emptyLabel: 'Unassigned',
                emptyIcon: Icons.person_outline_rounded,
                items: _members.map((m) => m.userId).toList(),
                itemLabel: (uid) {
                  final member = _members.where((m) => m.userId == uid).firstOrNull;
                  final name = member?.user?.fullName.trim();
                  if (name != null && name.isNotEmpty) return name;
                  return member?.user?.email ?? 'Team Member';
                },
                onChanged: (v) => setState(() => _assigneeId = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNullableDropdownField<String>(
                isDark: isDark,
                label: 'Sprint',
                value: _sprintId,
                emptyLabel: 'Product Backlog',
                emptyIcon: Icons.layers_outlined,
                items: _sprints.map((s) => s.id).toList(),
                itemLabel: (sid) {
                  final sprint = _sprints.where((s) => s.id == sid).firstOrNull;
                  if (sprint == null) return 'Sprint';
                  return sprint.isActive ? '${sprint.name} (Active)' : sprint.name;
                },
                onChanged: (v) => setState(() => _sprintId = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 4: Start Date & End Date
        Row(
          children: [
            Expanded(
              child: _buildOptionalDatePicker(
                isDark: isDark,
                label: 'Start Date',
                value: _issueStartDate,
                dateFormat: dateFormat,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textMuted: textMuted,
                onPick: () => _pickIssueDate(isStart: true),
                onClear: () => setState(() {
                  _issueStartDate = null;
                  _issueDateError = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOptionalDatePicker(
                isDark: isDark,
                label: 'End Date',
                value: _issueEndDate,
                dateFormat: dateFormat,
                borderColor: _issueDateError != null ? AppColors.errorFor(isDark) : borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textMuted: textMuted,
                onPick: () => _pickIssueDate(isStart: false),
                onClear: () => setState(() {
                  _issueEndDate = null;
                  _issueDateError = null;
                }),
              ),
            ),
          ],
        ),
        if (_issueDateError != null) ...[
          const SizedBox(height: 6),
          Text(
            _issueDateError!,
            style: TextStyle(color: AppColors.errorFor(isDark), fontSize: 11.5),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionalDatePicker({
    required bool isDark,
    required String label,
    required DateTime? value,
    required DateFormat dateFormat,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.bgFor(isDark),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13.5, color: textMuted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    value != null ? dateFormat.format(value) : 'Not set',
                    style: TextStyle(
                      color: value != null ? textPrimary : textMuted,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded, size: 14, color: textMuted),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNullableDropdownField<T>({
    required bool isDark,
    required String label,
    required T? value,
    required String emptyLabel,
    required IconData emptyIcon,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryFor(isDark),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.bgFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.borderFor(isDark)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T?>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              isDense: true,
              dropdownColor: AppColors.surfaceFor(isDark),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: textMuted,
              ),
              items: [
                DropdownMenuItem<T?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(emptyIcon, size: 14, color: textMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          emptyLabel,
                          style: TextStyle(fontSize: 12.5, color: textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ...items.map(
                  (item) => DropdownMenuItem<T?>(
                    value: item,
                    child: Text(
                      itemLabel(item),
                      style: TextStyle(fontSize: 12.5, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpicFields(bool isDark) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextFormField(
          controller: _titleController,
          label: 'Epic Name',
          isRequired: true,
          hintText: 'e.g. Platform v2.0 Experience',
          validator: (v) => _validateNonEmptyTitle(v, 'Epic name'),
        ),
        const SizedBox(height: 12),
        AppTextFormField(
          controller: _descriptionController,
          label: 'Objective & Scope',
          hintText: 'Outline goals, milestones, and success metrics for this epic...',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<IssuePriority>(
                isDark: isDark,
                label: 'Priority',
                value: _priority,
                items: IssuePriority.values,
                itemBuilder: (p) => Row(
                  children: [
                    Icon(p.icon, size: 14, color: p.colorFor(brightness)),
                    const SizedBox(width: 6),
                    Text(p.label, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _priority = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextFormField(
                controller: _estimateController,
                label: 'Estimated Points',
                hintText: 'e.g. 21',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => _validateNonNegativeNumber(v, 'Estimated points'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSprintFields(bool isDark) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextFormField(
          controller: _sprintNameController,
          label: 'Sprint Name',
          isRequired: true,
          hintText: 'e.g. Sprint 4 - Release Polish',
          validator: (v) => _validateNonEmptyTitle(v, 'Sprint name'),
        ),
        const SizedBox(height: 12),
        AppTextFormField(
          controller: _sprintGoalController,
          label: 'Sprint Goal',
          hintText: 'What is the main outcome for this sprint?',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Date',
                    style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _pickSprintDate(isStart: true),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgFor(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _sprintStartDate != null
                                  ? dateFormat.format(_sprintStartDate!)
                                  : 'Select date',
                              style: TextStyle(color: textPrimary, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.calendar_today_rounded, size: 14, color: textMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'End Date',
                    style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _pickSprintDate(isStart: false),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgFor(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(
                          color: _dateError != null ? AppColors.errorFor(isDark) : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _sprintEndDate != null
                                  ? dateFormat.format(_sprintEndDate!)
                                  : 'Select date',
                              style: TextStyle(color: textPrimary, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.calendar_today_rounded, size: 14, color: textMuted),
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
          Text(
            _dateError!,
            style: TextStyle(color: AppColors.errorFor(isDark), fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 12),
        AppTextFormField(
          controller: _sprintCapacityController,
          label: 'Capacity (Story Points)',
          hintText: 'e.g. 40',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => _validateNonNegativeNumber(v, 'Capacity'),
        ),
      ],
    );
  }

  Widget _buildDocumentFields(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextFormField(
          controller: _titleController,
          label: 'Document Title',
          isRequired: true,
          hintText: 'e.g. Architecture Decision Record - Auth v2',
          validator: (v) => _validateNonEmptyTitle(v, 'Document title'),
        ),
        const SizedBox(height: 12),
        AppTextFormField(
          controller: _descriptionController,
          label: 'Content (Markdown supported)',
          hintText: '# Overview\nWrite technical specs, meeting notes, or runbooks...',
          maxLines: 6,
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required bool isDark,
    required String label,
    required T value,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryFor(isDark),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.bgFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.borderFor(isDark)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              dropdownColor: AppColors.surfaceFor(isDark),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.textMutedFor(isDark),
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: itemBuilder(item),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
