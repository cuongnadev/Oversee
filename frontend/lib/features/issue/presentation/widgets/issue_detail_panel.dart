import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/issue/application/issue_detail_provider.dart';
import 'package:frontend/features/issue/domain/issue_activity_model.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';

/// Comprehensive responsive issue detail panel supporting:
/// - Desktop/Web slide-in right drawer
/// - Mobile full modal sheet
/// - Inline editable title and description with Markdown preview
/// - Real-time status, priority, assignee, and story points editing
/// - Sub-task checklist management with progress bar
/// - Activity timeline audit log
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

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surfaceDark,
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
        barrierColor: Colors.black.withValues(alpha: 0.55),
        transitionDuration: const Duration(milliseconds: 280),
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

  Future<void> _handleSaveTitle() async {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      final success = await _notifier.updateTitle(title);
      if (success && mounted) {
        final state = ref.read(issueDetailProvider((
          projectId: widget.projectId,
          initialIssue: widget.issue,
        )));
        _syncWithBoardAndBacklog(state.issue);
      }
    }
  }

  Future<void> _handleSaveDescription() async {
    final desc = _descController.text.trim();
    final success = await _notifier.updateDescription(desc);
    if (success && mounted) {
      setState(() => _isEditingDesc = false);
      final state = ref.read(issueDetailProvider((
        projectId: widget.projectId,
        initialIssue: widget.issue,
      )));
      _syncWithBoardAndBacklog(state.issue);
    }
  }

  Future<void> _handleSaveEstimate() async {
    final text = _estimateController.text.trim();
    final double? estimate = text.isNotEmpty ? double.tryParse(text) : null;
    final success = await _notifier.updateEstimate(estimate);
    if (success && mounted) {
      final state = ref.read(issueDetailProvider((
        projectId: widget.projectId,
        initialIssue: widget.issue,
      )));
      _syncWithBoardAndBacklog(state.issue);
    }
  }

  Future<void> _handleCreateSubTask() async {
    final title = _subTaskController.text.trim();
    if (title.isEmpty) return;

    final success = await _notifier.createSubTask(title);
    if (success && mounted) {
      _subTaskController.clear();
      final state = ref.read(issueDetailProvider((
        projectId: widget.projectId,
        initialIssue: widget.issue,
      )));
      _syncWithBoardAndBacklog(state.issue);
    }
  }

  Future<void> _handleToggleSubTask(String subId, bool isDone) async {
    final success = await _notifier.toggleSubTaskStatus(subId, isDone);
    if (success && mounted) {
      final state = ref.read(issueDetailProvider((
        projectId: widget.projectId,
        initialIssue: widget.issue,
      )));
      _syncWithBoardAndBacklog(state.issue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      issueDetailProvider((
        projectId: widget.projectId,
        initialIssue: widget.issue,
      )),
    );

    // Keep controllers in sync if updated from server
    if (!_titleFocusNode.hasFocus && _titleController.text != state.issue.title) {
      _titleController.text = state.issue.title;
    }
    if (!_descFocusNode.hasFocus &&
        !_isEditingDesc &&
        _descController.text != (state.issue.description ?? '')) {
      _descController.text = state.issue.description ?? '';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          left: BorderSide(color: AppColors.borderDark),
        ),
      ),
      child: Column(
        children: [
          // Header Bar
          _buildHeaderBar(state),
          const Divider(height: 1, color: AppColors.borderDark),

          // Error Banner if present
          if (state.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Body Content
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Editable Title
                      _buildTitleField(state),
                      const SizedBox(height: 20),

                      // Properties Section
                      _buildPropertiesGrid(state),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.borderDark),
                      const SizedBox(height: 20),

                      // Description Section with Markdown Preview
                      _buildDescriptionSection(state),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.borderDark),
                      const SizedBox(height: 20),

                      // Sub-tasks Section
                      _buildSubTasksSection(state),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.borderDark),
                      const SizedBox(height: 20),

                      // Activity Timeline Section
                      _buildActivitySection(state),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),

          // Fixed Bottom Action Bar
          const Divider(height: 1, color: AppColors.borderDark),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.cardDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondaryDark,
                    side: const BorderSide(color: AppColors.borderDark),
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
                    backgroundColor: AppColors.primary,
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

  Widget _buildHeaderBar(IssueDetailState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Type Icon and Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: state.issue.type.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: state.issue.type.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(state.issue.type.icon, size: 14, color: state.issue.type.color),
                const SizedBox(width: 6),
                Text(
                  state.issue.type.label,
                  style: TextStyle(
                    color: state.issue.type.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Formatted Issue Key
          Expanded(
            child: Text(
              '${state.issue.formattedKey(widget.projectKey)} - Issue Details',
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Saving indicator
          if (state.isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),

          // Close Button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondaryDark),
            tooltip: 'Close panel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(IssueDetailState state) {
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      style: const TextStyle(
        color: AppColors.textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      decoration: const InputDecoration(
        hintText: 'Issue title',
        hintStyle: TextStyle(color: AppColors.textMutedDark),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onSubmitted: (_) => _handleSaveTitle(),
    );
  }

  Widget _buildPropertiesGrid(IssueDetailState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          // Status Row
          _buildPropertyRow(
            icon: Icons.check_circle_outline_rounded,
            label: 'Status',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<IssueStatus>(
                value: state.issue.status,
                dropdownColor: AppColors.cardDark,
                borderRadius: BorderRadius.circular(8),
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondaryDark),
                onChanged: (newStatus) async {
                  if (newStatus != null) {
                    final success = await _notifier.updateStatus(newStatus);
                    if (success && mounted) {
                      _syncWithBoardAndBacklog(
                        ref.read(issueDetailProvider((
                          projectId: widget.projectId,
                          initialIssue: widget.issue,
                        ))).issue,
                      );
                    }
                  }
                },
                items: IssueStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 14, color: status.color),
                        const SizedBox(width: 8),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: status.color,
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
          const Divider(height: 16, color: AppColors.borderDark),

          // Priority Row
          _buildPropertyRow(
            icon: Icons.flag_outlined,
            label: 'Priority',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<IssuePriority>(
                value: state.issue.priority,
                dropdownColor: AppColors.cardDark,
                borderRadius: BorderRadius.circular(8),
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondaryDark),
                onChanged: (newPriority) async {
                  if (newPriority != null) {
                    final success = await _notifier.updatePriority(newPriority);
                    if (success && mounted) {
                      _syncWithBoardAndBacklog(
                        ref.read(issueDetailProvider((
                          projectId: widget.projectId,
                          initialIssue: widget.issue,
                        ))).issue,
                      );
                    }
                  }
                },
                items: IssuePriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(priority.icon, size: 14, color: priority.color),
                        const SizedBox(width: 8),
                        Text(
                          priority.label,
                          style: TextStyle(
                            color: priority.color,
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
          const Divider(height: 16, color: AppColors.borderDark),

          // Assignee Row
          _buildPropertyRow(
            icon: Icons.person_outline_rounded,
            label: 'Assignee',
            child: _buildAssigneeSelector(state),
          ),
          const Divider(height: 16, color: AppColors.borderDark),

          // Story Points Estimate Row
          _buildPropertyRow(
            icon: Icons.timer_outlined,
            label: 'Story Points',
            child: SizedBox(
              width: 90,
              height: 36,
              child: TextField(
                controller: _estimateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '0 pts',
                  hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.primary),
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

  Widget _buildPropertyRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondaryDark),
        const SizedBox(width: 10),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
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

  Widget _buildAssigneeSelector(IssueDetailState state) {
    final currentAssignee = state.issue.assignee;

    return PopupMenuButton<String?>(
      tooltip: 'Change assignee',
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      initialValue: state.issue.assigneeId,
      onSelected: (assigneeId) async {
        final success = await _notifier.updateAssignee(assigneeId);
        if (success && mounted) {
          _syncWithBoardAndBacklog(
            ref.read(issueDetailProvider((
              projectId: widget.projectId,
              initialIssue: widget.issue,
            ))).issue,
          );
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String?>>[
          const PopupMenuItem<String?>(
            value: null,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.borderDark,
                  child: Icon(Icons.person_off_rounded, size: 14, color: AppColors.textSecondaryDark),
                ),
                SizedBox(width: 8),
                Text('Unassigned', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
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
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    member.user?.fullName ?? member.user?.email ?? 'Member',
                    style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
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
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentAssignee != null) ...[
              CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primary,
                child: Text(
                  currentAssignee.initials,
                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                currentAssignee.fullName,
                style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 12),
              ),
            ] else ...[
              const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondaryDark),
              const SizedBox(width: 6),
              const Text(
                'Unassigned',
                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(IssueDetailState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Description',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Write / Preview Switcher
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _isPreviewMode = false),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: !_isPreviewMode ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Write',
                        style: TextStyle(
                          fontSize: 12,
                          color: !_isPreviewMode ? AppColors.primary : AppColors.textSecondaryDark,
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
                        color: _isPreviewMode ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isPreviewMode ? AppColors.primary : AppColors.textSecondaryDark,
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
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: _descController.text.trim().isEmpty
                ? const Text(
                    'No description provided.',
                    style: TextStyle(color: AppColors.textMutedDark, fontStyle: FontStyle.italic, fontSize: 13),
                  )
                : MarkdownBody(
                    data: _descController.text,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, height: 1.5),
                      h1: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 18, fontWeight: FontWeight.bold),
                      h2: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 16, fontWeight: FontWeight.bold),
                      h3: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14, fontWeight: FontWeight.w600),
                      code: const TextStyle(
                        backgroundColor: AppColors.surfaceDark,
                        color: AppColors.secondary,
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
                style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Add a description... (Markdown supported)',
                  hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
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
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _handleSaveDescription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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

  Widget _buildSubTasksSection(IssueDetailState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sub-tasks',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${state.completedSubIssues} of ${state.totalSubIssues} completed',
              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Linear Progress Indicator
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: state.subIssuesProgress,
            minHeight: 6,
            backgroundColor: AppColors.borderDark,
            valueColor: AlwaysStoppedAnimation<Color>(
              state.subIssuesProgress == 1.0 ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Subtask List
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
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isDone,
                      activeColor: AppColors.success,
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
                          color: isDone ? AppColors.textMutedDark : AppColors.textPrimaryDark,
                          fontSize: 13,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (sub.estimate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Text(
                          '${sub.estimate!.toInt()} pts',
                          style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 10),

        // Quick Add Sub-task field
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _subTaskController,
                  style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a subtask...',
                    hintStyle: const TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.cardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.primary),
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
                  backgroundColor: AppColors.primary,
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

  Widget _buildActivitySection(IssueDetailState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity History',
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        if (state.activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                'No activity history yet.',
                style: TextStyle(color: AppColors.textMutedDark, fontSize: 12, fontStyle: FontStyle.italic),
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
              return _buildActivityItem(act);
            },
          ),
      ],
    );
  }

  Widget _buildActivityItem(IssueActivityModel act) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primaryLight,
            child: Icon(Icons.history_rounded, size: 14, color: Colors.white),
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
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      act.timeAgo,
                      style: const TextStyle(color: AppColors.textMutedDark, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  act.actionLabel,
                  style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                ),
                if (act.transitionText != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      act.transitionText!,
                      style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontFamily: 'monospace'),
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
