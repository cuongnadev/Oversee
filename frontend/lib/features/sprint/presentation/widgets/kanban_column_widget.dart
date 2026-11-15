import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/presentation/widgets/kanban_issue_card.dart';

/// Callback when an issue is dropped or moved into this column.
typedef IssueDropCallback = void Function(IssueModel issue);

/// Represents a single status column on the Kanban board (TODO, IN_PROGRESS, IN_REVIEW, DONE).
class KanbanColumnWidget extends StatefulWidget {
  final IssueStatus status;
  final List<IssueModel> issues;
  final double totalStoryPoints;
  final String projectKey;
  final IssueDropCallback? onIssueDropped;
  final VoidCallback? onCardUpdated;

  const KanbanColumnWidget({
    super.key,
    required this.status,
    required this.issues,
    required this.totalStoryPoints,
    required this.projectKey,
    this.onIssueDropped,
    this.onCardUpdated,
  });

  @override
  State<KanbanColumnWidget> createState() => _KanbanColumnWidgetState();
}

class _KanbanColumnWidgetState extends State<KanbanColumnWidget> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final columnBg = isDark
        ? (_isDragOver ? AppColors.surfaceDark.withAlpha(220) : const Color(0xFF131B2E))
        : (_isDragOver ? Colors.indigo.shade50 : const Color(0xFFF1F5F9));
    final borderColor = _isDragOver
        ? widget.status.color
        : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0));

    return DragTarget<IssueModel>(
      onWillAcceptWithDetails: (details) {
        final willAccept = details.data.status != widget.status;
        setState(() => _isDragOver = willAccept);
        return willAccept;
      },
      onLeave: (_) {
        setState(() => _isDragOver = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        if (widget.onIssueDropped != null) {
          widget.onIssueDropped!(details.data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: columnBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: _isDragOver ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column Header
              _buildColumnHeader(context, isDark),
              const Divider(height: 1, thickness: 1),

              // Scrollable Column Cards
              Expanded(
                child: widget.issues.isEmpty
                    ? _buildEmptyColumnPlaceholder(context, isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        itemCount: widget.issues.length,
                        itemBuilder: (context, index) {
                          final issue = widget.issues[index];
                          return LongPressDraggable<IssueModel>(
                            data: issue,
                            feedback: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 280,
                                child: KanbanIssueCard(
                                  issue: issue,
                                  projectKey: widget.projectKey,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: KanbanIssueCard(
                                issue: issue,
                                projectKey: widget.projectKey,
                              ),
                            ),
                            child: KanbanIssueCard(
                              issue: issue,
                              projectKey: widget.projectKey,
                              onUpdated: widget.onCardUpdated,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColumnHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Status Icon Indicator
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: widget.status.color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.status.icon,
              size: 14,
              color: widget.status.color,
            ),
          ),
          const SizedBox(width: 8),

          // Column Name
          Expanded(
            child: Text(
              widget.status.label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Card Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.issues.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),

          // Story Points Badge
          if (widget.totalStoryPoints > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.totalStoryPoints % 1 == 0
                    ? '${widget.totalStoryPoints.toInt()} pts'
                    : '${widget.totalStoryPoints} pts',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.secondaryLight : AppColors.secondaryDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyColumnPlaceholder(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 32,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              'No issues in ${widget.status.label}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
