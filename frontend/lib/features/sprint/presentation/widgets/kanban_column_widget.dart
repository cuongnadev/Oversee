import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/presentation/widgets/kanban_issue_card.dart';

/// Callback when an issue is dropped or moved into this column.
typedef IssueDropCallback = void Function(IssueModel issue);

/// Single workflow column on the Kanban board aligned with Figma Section/Header (node 6:568).
class KanbanColumnWidget extends StatefulWidget {
  final IssueStatus status;
  final List<IssueModel> issues;
  final double totalStoryPoints;
  final String projectKey;
  final double width;
  final IssueDropCallback? onIssueDropped;
  final VoidCallback? onCardUpdated;
  final VoidCallback? onAddIssue;

  const KanbanColumnWidget({
    super.key,
    required this.status,
    required this.issues,
    required this.totalStoryPoints,
    required this.projectKey,
    this.width = 304,
    this.onIssueDropped,
    this.onCardUpdated,
    this.onAddIssue,
  });

  @override
  State<KanbanColumnWidget> createState() => _KanbanColumnWidgetState();
}

class _KanbanColumnWidgetState extends State<KanbanColumnWidget> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final isMouseDevice = kIsWeb ||
        theme.platform == TargetPlatform.windows ||
        theme.platform == TargetPlatform.macOS ||
        theme.platform == TargetPlatform.linux;

    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final statusColor = widget.status.colorFor(brightness);

    final columnBg = _isDragOver
        ? accentSoft.withValues(alpha: isDark ? 0.65 : 0.85)
        : Colors.transparent;
    final borderColor = _isDragOver ? accentColor : Colors.transparent;

    return RepaintBoundary(
      child: DragTarget<IssueModel>(
        onWillAcceptWithDetails: (details) {
          final willAccept = details.data.status != widget.status;
          if (_isDragOver != willAccept) {
            setState(() => _isDragOver = willAccept);
          }
          return willAccept;
        },
        onLeave: (_) {
          if (_isDragOver) {
            setState(() => _isDragOver = false);
          }
        },
        onAcceptWithDetails: (details) {
          setState(() => _isDragOver = false);
          if (widget.onIssueDropped != null) {
            widget.onIssueDropped!(details.data);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: widget.width,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: columnBg,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(
                color: borderColor,
                width: _isDragOver ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Column Header (Figma 6:569)
                _buildColumnHeader(context, isDark, statusColor),
                Divider(height: 1, thickness: 1, color: AppColors.borderSoftFor(isDark)),

                // Animated Drop Preview Banner when dragging over this column
                AnimatedSize(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  child: _isDragOver
                      ? Container(
                          margin: const EdgeInsets.fromLTRB(2, 8, 2, 2),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: isDark ? 0.16 : 0.12),
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            border: Border.all(color: accentColor, width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 15, color: accentColor),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Drop to move to ${widget.status.label}',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Scrollable Column Cards
                Expanded(
                  child: widget.issues.isEmpty && !_isDragOver
                      ? _buildEmptyColumnPlaceholder(context, isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 10, bottom: 8),
                          addAutomaticKeepAlives: false,
                          itemCount: widget.issues.length + (widget.onAddIssue != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == widget.issues.length) {
                              return _buildBottomAddButton(isDark);
                            }

                            final issue = widget.issues[index];
                            final card = KanbanIssueCard(
                              key: ValueKey(issue.id),
                              issue: issue,
                              projectKey: widget.projectKey,
                              onUpdated: widget.onCardUpdated,
                            );

                            final feedback = Material(
                              elevation: 10,
                              shadowColor: Colors.black38,
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(AppColors.radiusMd),
                              child: Transform.rotate(
                                angle: 0.02,
                                child: SizedBox(
                                  width: (widget.width - 14).clamp(240.0, 340.0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withValues(alpha: 0.22),
                                          blurRadius: 14,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Opacity(
                                      opacity: 0.96,
                                      child: KanbanIssueCard(
                                        issue: issue,
                                        projectKey: widget.projectKey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );

                            final childWhenDragging = Container(
                              margin: const EdgeInsets.only(bottom: 9),
                              height: 92,
                              decoration: BoxDecoration(
                                color: accentSoft.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.45),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 18,
                                  color: accentColor.withValues(alpha: 0.6),
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
                                    delay: const Duration(milliseconds: 220),
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
      ),
    );
  }

  Widget _buildColumnHeader(BuildContext context, bool isDark, Color statusColor) {
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 2, 10),
      child: Row(
        children: [
          Icon(widget.status.icon, size: 15, color: statusColor),
          const SizedBox(width: 7),

          // Column Title
          Flexible(
            child: Text(
              widget.status.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 7),

          // Issue Count (Figma 6:584)
          Text(
            '${widget.issues.length}',
            style: AppTypography.mono(
              isDark,
              fontSize: 11,
              color: textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Story Points Pill
          if (widget.totalStoryPoints > 0) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Text(
                widget.totalStoryPoints % 1 == 0
                    ? '${widget.totalStoryPoints.toInt()} pts'
                    : '${widget.totalStoryPoints} pts',
                style: AppTypography.mono(
                  isDark,
                  fontSize: 10,
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const Spacer(),

          if (widget.onAddIssue != null)
            IconButton(
              icon: Icon(Icons.add_rounded, size: 16, color: textMuted),
              tooltip: 'Add issue to ${widget.status.label}',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: widget.onAddIssue,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomAddButton(bool isDark) {
    final textMuted = AppColors.textMutedFor(isDark);
    return InkWell(
      onTap: widget.onAddIssue,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.add_rounded, size: 14, color: textMuted),
            const SizedBox(width: 6),
            Text(
              'Add issue',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyColumnPlaceholder(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface2For(isDark),
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                border: Border.all(color: AppColors.borderSoftFor(isDark)),
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 20,
                color: AppColors.textMutedFor(isDark).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No issues in ${widget.status.label}',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMutedFor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.onAddIssue != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.onAddIssue,
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Add issue', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
