import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/application/issue_detail_provider.dart';
import 'package:frontend/features/issue/domain/issue_activity_model.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';

/// Comprehensive responsive issue detail panel supporting both Light and Dark themes:
/// - Desktop/Web slide-in right drawer & Mobile modal sheet
/// - Inline editable title and description with Markdown preview
/// - Real-time status, priority, assignee, sprint, dates, and story points editing
/// - Sub-task checklist management with progress bar
/// - Activity timeline audit log
/// - In-place provider sync without refetching the underlying page on close
class IssueDetailPanel extends ConsumerStatefulWidget {
  final String projectId;
  final String projectKey;
  final IssueModel issue;
  final VoidCallback? onIssueUpdated;

  const IssueDetailPanel({
    super.key,
    required this.projectId,
    required this.projectKey,
    required this.issue,
    this.onIssueUpdated,
  });

  /// Opens the detail panel adaptively based on device screen size.
  static Future<void> show(
    BuildContext context, {
    required String projectId,
    required String projectKey,
    required IssueModel issue,
    VoidCallback? onIssueUpdated,
  }) async {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surfaceFor(isDark),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.9,
          child: IssueDetailPanel(
            projectId: projectId,
            projectKey: projectKey,
            issue: issue,
            onIssueUpdated: onIssueUpdated,
          ),
        ),
      );
    } else {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Issue Details',
        barrierColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.35),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (ctx, anim1, anim2) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 580,
                height: double.infinity,
                child: IssueDetailPanel(
                  projectId: projectId,
                  projectKey: projectKey,
                  issue: issue,
                  onIssueUpdated: onIssueUpdated,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim, secondaryAnim, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
    }
  }

  @override
  ConsumerState<IssueDetailPanel> createState() => _IssueDetailPanelState();
}

class _IssueDetailPanelState extends ConsumerState<IssueDetailPanel> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _subTaskController;
  late final TextEditingController _estimateController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descFocusNode = FocusNode();

  bool _isPreviewMode = false;
  bool _isEditingDesc = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.issue.title);
    _descController = TextEditingController(text: widget.issue.description ?? '');
    _subTaskController = TextEditingController();
    _estimateController = TextEditingController(
      text: widget.issue.estimate != null ? widget.issue.estimate!.toInt().toString() : '',
    );

    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus) {
        _handleSaveTitle();
      }
    });

    _descFocusNode.addListener(() {
      if (!_descFocusNode.hasFocus && _isEditingDesc) {
        _handleSaveDescription();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subTaskController.dispose();
    _estimateController.dispose();
    _titleFocusNode.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  IssueDetailNotifier get _notifier => ref.read(
        issueDetailProvider((
          projectId: widget.projectId,
          initialIssue: widget.issue,
        )).notifier,
      );

  void _syncWithBoardAndBacklog(IssueModel updatedIssue) {
    try {
      if (ref.exists(backlogNotifierProvider(widget.projectId))) {
        ref.read(backlogNotifierProvider(widget.projectId).notifier).updateIssueInState(updatedIssue);
      }
    } catch (_) {}

    try {
      if (ref.exists(kanbanBoardProvider(widget.projectId))) {
        ref.read(kanbanBoardProvider(widget.projectId).notifier).updateIssueInState(updatedIssue);
      }
    } catch (_) {}

    widget.onIssueUpdated?.call();
  }

  IssueModel _currentIssue() {
    return ref
        .read(issueDetailProvider((
          projectId: widget.projectId,
          initialIssue: widget.issue,
        )))
        .issue;
  }

  Future<void> _handleSaveTitle() async {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      final success = await _notifier.updateTitle(title);
      if (success && mounted) {
        _syncWithBoardAndBacklog(_currentIssue());
      }
    }
  }

  Future<void> _handleSaveDescription() async {
    final desc = _descController.text.trim();
    final success = await _notifier.updateDescription(desc);
    if (success && mounted) {
      setState(() => _isEditingDesc = false);
      _syncWithBoardAndBacklog(_currentIssue());
    }
  }

  Future<void> _handleSaveEstimate() async {
    final text = _estimateController.text.trim();
    final double? estimate = text.isNotEmpty ? double.tryParse(text) : null;
    final success = await _notifier.updateEstimate(estimate);
    if (success && mounted) {
      _syncWithBoardAndBacklog(_currentIssue());
    }
  }

  Future<void> _handleCreateSubTask() async {
    final title = _subTaskController.text.trim();
    if (title.isEmpty) return;

    final success = await _notifier.createSubTask(title);
    if (success && mounted) {
      _subTaskController.clear();
      _syncWithBoardAndBacklog(_currentIssue());
    }
  }

  Future<void> _handleToggleSubTask(String subId, bool isDone) async {
    final success = await _notifier.toggleSubTaskStatus(subId, isDone);
    if (success && mounted) {
      _syncWithBoardAndBacklog(_currentIssue());
    }
  }

  Future<void> _pickDate(IssueDetailState state, {required bool isStart}) async {
    final initial = isStart
        ? (state.issue.startDate ?? DateTime.now())
        : (state.issue.endDate ?? state.issue.startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    final success = await _notifier.updateDates(
      startDate: isStart ? picked : null,
      endDate: isStart ? null : picked,
    );
    if (success && mounted) {
      _syncWithBoardAndBacklog(_currentIssue());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceColor = AppColors.surfaceFor(isDark);
    final surface2Color = AppColors.surface2For(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSolid = AppColors.accentSolidFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final errorColor = AppColors.errorFor(isDark);

    final state = ref.watch(
      issueDetailProvider((
        projectId: widget.projectId,
        initialIssue: widget.issue,
      )),
    );

    if (!_titleFocusNode.hasFocus && _titleController.text != state.issue.title) {
      _titleController.text = state.issue.title;
    }
    if (!_descFocusNode.hasFocus &&
        !_isEditingDesc &&
        _descController.text != (state.issue.description ?? '')) {
      _descController.text = state.issue.description ?? '';
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: BorderSide(color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          _buildHeaderBar(state, isDark, brightness),
          Divider(height: 1, color: borderColor),

          // Error Banner if present
          if (state.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: errorColor.withValues(alpha: 0.14),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(color: errorColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Body Content
          Expanded(
            child: state.isLoading
                ? Center(
                    child: CircularProgressIndicator(color: accentColor),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTitleField(state, isDark),
                        const SizedBox(height: 16),

                        _buildPropertiesGrid(state, isDark, brightness),
                        const SizedBox(height: 20),
                        Divider(color: borderColor),
                        const SizedBox(height: 16),

                        _buildDescriptionSection(state, isDark),
                        const SizedBox(height: 20),
                        Divider(color: borderColor),
                        const SizedBox(height: 16),

                        _buildSubTasksSection(state, isDark),
                        const SizedBox(height: 20),
                        Divider(color: borderColor),
                        const SizedBox(height: 16),

                        _buildActivitySection(state, isDark),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),

          // Fixed Bottom Action Bar
          Divider(height: 1, color: borderColor),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: surface2Color,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    await _handleSaveTitle();
                    await _handleSaveDescription();
                    await _handleSaveEstimate();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentSolid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(IssueDetailState state, bool isDark, Brightness brightness) {
    final typeColor = state.issue.type.colorFor(brightness);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final accentColor = AppColors.accentFor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: typeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(state.issue.type.icon, size: 14, color: typeColor),
                const SizedBox(width: 6),
                Text(
                  state.issue.type.label,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${state.issue.formattedKey(widget.projectKey)} - Issue Details',
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
              ),
            ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: textSecondary),
            tooltip: 'Close panel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(IssueDetailState state, bool isDark) {
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      style: TextStyle(
        color: AppColors.textPrimaryFor(isDark),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      decoration: InputDecoration(
        hintText: 'Issue title',
        hintStyle: TextStyle(color: AppColors.textMutedFor(isDark)),
        border: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
      onSubmitted: (_) => _handleSaveTitle(),
    );
  }

  Widget _buildPropertiesGrid(IssueDetailState state, bool isDark, Brightness brightness) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final surface2Color = AppColors.surface2For(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final dateFmt = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface2Color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Status Row
          _buildPropertyRow(
            isDark: isDark,
            icon: Icons.check_circle_outline_rounded,
            label: 'Status',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<IssueStatus>(
                value: state.issue.status,
                isDense: true,
                dropdownColor: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                icon: Icon(Icons.arrow_drop_down, color: textSecondary),
                onChanged: (newStatus) async {
                  if (newStatus != null) {
                    final success = await _notifier.updateStatus(newStatus);
                    if (success && mounted) {
                      _syncWithBoardAndBacklog(_currentIssue());
                    }
                  }
                },
                items: IssueStatus.values.map((status) {
                  final sc = status.colorFor(brightness);
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 14, color: sc),
                        const SizedBox(width: 8),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: sc,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Divider(height: 10, color: borderColor),

          // Priority Row
          _buildPropertyRow(
            isDark: isDark,
            icon: Icons.flag_outlined,
            label: 'Priority',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<IssuePriority>(
                value: state.issue.priority,
                isDense: true,
                dropdownColor: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                icon: Icon(Icons.arrow_drop_down, color: textSecondary),
                onChanged: (newPriority) async {
                  if (newPriority != null) {
                    final success = await _notifier.updatePriority(newPriority);
                    if (success && mounted) {
                      _syncWithBoardAndBacklog(_currentIssue());
                    }
                  }
                },
                items: IssuePriority.values.map((priority) {
                  final pc = priority.colorFor(brightness);
                  return DropdownMenuItem(
                    value: priority,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(priority.icon, size: 14, color: pc),
                        const SizedBox(width: 8),
                        Text(
                          priority.label,
                          style: TextStyle(
                            color: pc,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Divider(height: 10, color: borderColor),

          // Assignee Row
          _buildPropertyRow(
            isDark: isDark,
            icon: Icons.person_outline_rounded,
            label: 'Assignee',
            child: _buildAssigneeSelector(state, isDark),
          ),
          Divider(height: 10, color: borderColor),

          // Sprint Row
          _buildPropertyRow(
            isDark: isDark,
            icon: Icons.layers_outlined,
            label: 'Sprint',
            child: _buildSprintSelector(state, isDark),
          ),
          Divider(height: 10, color: borderColor),

          // Start & End Date combined row
          _buildPropertyRow(
            isDark: isDark,
            icon: Icons.event_outlined,
            label: 'Dates',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDateChip(
                  isDark: isDark,
                  value: state.issue.startDate,
                  placeholder: 'Start',
                  dateFmt: dateFmt,
                  onTap: () => _pickDate(state, isStart: true),
                  onClear: () async {
                    final ok = await _notifier.updateDates(clearStartDate: true);
                    if (ok && mounted) _syncWithBoardAndBacklog(_currentIssue());
                  },
                ),
                Text('→', style: TextStyle(color: textMuted, fontSize: 12)),
                _buildDateChip(
                  isDark: isDark,
                  value: state.issue.endDate,
                  placeholder: 'Due',
                  dateFmt: dateFmt,
                  onTap: () => _pickDate(state, isStart: false),
                  onClear: () async {
                    final ok = await _notifier.updateDates(clearEndDate: true);
                    if (ok && mounted) _syncWithBoardAndBacklog(_currentIssue());
                  },
                ),
              ],
            ),
          ),
          Divider(height: 10, color: borderColor),

          // Story Points Estimate Row
          _buildPropertyRow(
            isDark: isDark,
            icon: Icons.timer_outlined,
            label: 'Story Points',
            child: SizedBox(
              width: 90,
              height: 32,
              child: TextField(
                controller: _estimateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '0 pts',
                  hintStyle: TextStyle(color: textMuted, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  filled: true,
                  fillColor: surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: accentColor),
                  ),
                ),
                onSubmitted: (_) => _handleSaveEstimate(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required bool isDark,
    required DateTime? value,
    required String placeholder,
    required DateFormat dateFmt,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: textMuted),
            const SizedBox(width: 5),
            Text(
              value != null ? dateFmt.format(value) : placeholder,
              style: TextStyle(
                color: value != null ? textPrimary : textMuted,
                fontSize: 11.5,
                fontWeight: value != null ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 12.5, color: textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSprintSelector(IssueDetailState state, bool isDark) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final accentColor = AppColors.accentFor(isDark);

    final availableSprints = state.sprints
        .where((s) => s.status != SprintStatus.completed && s.status != SprintStatus.closed)
        .toList();
    final currentSprint = state.sprints.where((s) => s.id == state.issue.sprintId).firstOrNull;

    return PopupMenuButton<String?>(
      tooltip: 'Change sprint',
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
      onSelected: (sprintId) async {
        final success = await _notifier.updateSprint(sprintId == '__backlog__' ? null : sprintId);
        if (success && mounted) {
          _syncWithBoardAndBacklog(_currentIssue());
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem<String?>(
            value: '__backlog__',
            child: Row(
              children: [
                Icon(Icons.layers_outlined, size: 14, color: textSecondary),
                const SizedBox(width: 8),
                Text('Product Backlog', style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (availableSprints.isNotEmpty) const PopupMenuDivider(),
          ...availableSprints.map(
            (sprint) => PopupMenuItem<String?>(
              value: sprint.id,
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: sprint.isActive ? accentColor : textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sprint.isActive ? '${sprint.name} (Active)' : sprint.name,
                      style: TextStyle(color: textPrimary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentSprint != null ? Icons.timer_outlined : Icons.layers_outlined,
              size: 13.5,
              color: currentSprint != null ? accentColor : textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              currentSprint != null ? currentSprint.name : 'Product Backlog',
              style: TextStyle(
                color: currentSprint != null ? textPrimary : textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final textSecondary = AppColors.textSecondaryFor(isDark);
    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        child,
      ],
    );
  }

  Widget _buildAssigneeSelector(IssueDetailState state, bool isDark) {
    final currentAssignee = state.issue.assignee;
    final surfaceColor = AppColors.surfaceFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final accentSolid = AppColors.accentSolidFor(isDark);

    return PopupMenuButton<String?>(
      tooltip: 'Change assignee',
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
      initialValue: state.issue.assigneeId,
      onSelected: (assigneeId) async {
        final success = await _notifier.updateAssignee(
          assigneeId == '__unassigned__' ? null : assigneeId,
        );
        if (success && mounted) {
          _syncWithBoardAndBacklog(_currentIssue());
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String?>>[
          PopupMenuItem<String?>(
            value: '__unassigned__',
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.surface3For(isDark),
                  child: Icon(Icons.person_off_rounded, size: 14, color: textSecondary),
                ),
                const SizedBox(width: 8),
                Text('Unassigned', style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ];

        for (final member in state.members) {
          final initials = member.user?.initials ?? 'U';
          items.add(
            PopupMenuItem<String?>(
              value: member.userId,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: accentSolid,
                    child: Text(
                      initials,
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    member.user?.fullName ?? member.user?.email ?? 'Member',
                    style: TextStyle(color: textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }
        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentAssignee != null) ...[
              CircleAvatar(
                radius: 10,
                backgroundColor: accentSolid,
                child: Text(
                  currentAssignee.initials,
                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                currentAssignee.fullName.isNotEmpty ? currentAssignee.fullName : currentAssignee.email,
                style: TextStyle(color: textPrimary, fontSize: 12),
              ),
            ] else ...[
              Icon(Icons.person_outline, size: 14, color: textSecondary),
              const SizedBox(width: 6),
              Text(
                'Unassigned',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(IssueDetailState state, bool isDark) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final surface2Color = AppColors.surface2For(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSolid = AppColors.accentSolidFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Description',
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: surface2Color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _isPreviewMode = false),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: !_isPreviewMode ? accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Write',
                        style: TextStyle(
                          fontSize: 12,
                          color: !_isPreviewMode ? accentColor : textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _isPreviewMode = true),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isPreviewMode ? accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isPreviewMode ? accentColor : textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isPreviewMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(minHeight: 100),
            decoration: BoxDecoration(
              color: surface2Color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: _descController.text.trim().isEmpty
                ? Text(
                    'No description provided.',
                    style: TextStyle(color: textMuted, fontStyle: FontStyle.italic, fontSize: 13),
                  )
                : MarkdownBody(
                    data: _descController.text,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(color: textPrimary, fontSize: 13, height: 1.5),
                      h1: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      h2: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      h3: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      code: TextStyle(
                        backgroundColor: surfaceColor,
                        color: AppColors.infoFor(isDark),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _descController,
                focusNode: _descFocusNode,
                maxLines: 8,
                minLines: 3,
                style: TextStyle(color: textPrimary, fontSize: 13, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Add a description... (Markdown supported)',
                  hintStyle: TextStyle(color: textMuted, fontSize: 13),
                  filled: true,
                  fillColor: surface2Color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: accentColor),
                  ),
                ),
                onChanged: (_) {
                  if (!_isEditingDesc) setState(() => _isEditingDesc = true);
                },
              ),
              if (_isEditingDesc) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _descController.text = state.issue.description ?? '';
                          _isEditingDesc = false;
                        });
                      },
                      child: Text('Cancel', style: TextStyle(color: textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _handleSaveDescription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentSolid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Save Description'),
                    ),
                  ],
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildSubTasksSection(IssueDetailState state, bool isDark) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final surface2Color = AppColors.surface2For(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSolid = AppColors.accentSolidFor(isDark);
    final successColor = AppColors.successFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sub-tasks',
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${state.completedSubIssues} of ${state.totalSubIssues} completed',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: state.subIssuesProgress,
            minHeight: 6,
            backgroundColor: AppColors.surface3For(isDark),
            valueColor: AlwaysStoppedAnimation<Color>(
              state.subIssuesProgress == 1.0 ? successColor : accentSolid,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (state.subIssues.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.subIssues.length,
            separatorBuilder: (_, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final sub = state.subIssues[index];
              final isDone = sub.status == IssueStatus.done || sub.status == IssueStatus.canceled;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: surface2Color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isDone,
                      activeColor: successColor,
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) {
                        if (val != null) _handleToggleSubTask(sub.id, val);
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sub.title,
                        style: TextStyle(
                          color: isDone ? textMuted : textPrimary,
                          fontSize: 13,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (sub.estimate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          '${sub.estimate!.toInt()} pts',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _subTaskController,
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a subtask...',
                    hintStyle: TextStyle(color: textMuted, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: surface2Color,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: accentColor),
                    ),
                  ),
                  onSubmitted: (_) => _handleCreateSubTask(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: state.isCreatingSubTask ? null : _handleCreateSubTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentSolid,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: state.isCreatingSubTask
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivitySection(IssueDetailState state, bool isDark) {
    final surface2Color = AppColors.surface2For(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity History',
          style: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (state.activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface2Color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                'No activity history yet.',
                style: TextStyle(color: textMuted, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.activities.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final act = state.activities[index];
              return _buildActivityItem(act, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildActivityItem(IssueActivityModel act, bool isDark) {
    final surfaceColor = AppColors.surfaceFor(isDark);
    final surface2Color = AppColors.surface2For(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final accentSolid = AppColors.accentSolidFor(isDark);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surface2Color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: accentSolid,
            child: const Icon(Icons.history_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      act.actorName ?? 'User',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      act.timeAgo,
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  act.actionLabel,
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                if (act.transitionText != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      act.transitionText!,
                      style: TextStyle(
                        color: AppColors.infoFor(isDark),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
