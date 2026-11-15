import 'package:flutter/foundation.dart';
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
    final isMouseDevice = kIsWeb ||
        theme.platform == TargetPlatform.windows ||
        theme.platform == TargetPlatform.macOS ||
        theme.platform == TargetPlatform.linux;

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

              // Visual Drop Preview Banner when dragging over this column
              if (_isDragOver) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: widget.status.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.status.color,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_downward_rounded, size: 16, color: widget.status.color),
                      const SizedBox(width: 6),
                      Text(
                        'Drop to move to ${widget.status.label}',
                        style: TextStyle(
                          color: widget.status.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Scrollable Column Cards
              Expanded(
                child: widget.issues.isEmpty && !_isDragOver
                    ? _buildEmptyColumnPlaceholder(context, isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        itemCount: widget.issues.length,
                        itemBuilder: (context, index) {
                          final issue = widget.issues[index];
                          final card = KanbanIssueCard(
                            issue: issue,
                            projectKey: widget.projectKey,
                            onUpdated: widget.onCardUpdated,
                          );

                          final feedback = Material(
                            elevation: 8,
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: Transform.rotate(
                              angle: 0.03,
                              child: SizedBox(
                                width: 280,
                                child: Opacity(
                                  opacity: 0.95,
                                  child: KanbanIssueCard(
                                    issue: issue,
                                    projectKey: widget.projectKey,
                                  ),
                                ),
                              ),
                            ),
                          );

                          final childWhenDragging = Opacity(
                            opacity: 0.3,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              height: 75,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? Colors.white24 : Colors.black12,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 20,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                              ),
                            ),
                          );

                          return isMouseDevice
                              ? Draggable<IssueModel>(
                                  data: issue,
                                  feedback: feedback,
                                  childWhenDragging: childWhenDragging,
                                  child: card,
                                )
                              : LongPressDraggable<IssueModel>(
                                  data: issue,
                                  delay: const Duration(milliseconds: 250),
                                  hapticFeedbackOnStart: true,
                                  feedback: feedback,
                                  childWhenDragging: childWhenDragging,
                                  child: card,
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
