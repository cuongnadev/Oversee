import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/utils/responsive_breakpoints.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/issue/presentation/widgets/issue_detail_panel.dart';

/// Modal / Side drawer for viewing and editing issue details.
/// Wraps [IssueDetailPanel] for responsive desktop drawer / mobile bottom sheet.
class IssueDetailDialog extends StatelessWidget {
  final String projectId;
  final String projectKey;
  final IssueModel issue;
  final VoidCallback? onIssueUpdated;

  const IssueDetailDialog({
    super.key,
    required this.projectId,
    required this.projectKey,
    required this.issue,
    this.onIssueUpdated,
  });

  /// Opens the responsive detail panel (drawer on desktop, bottom sheet on mobile).
  static Future<void> show(
    BuildContext context, {
    required String projectId,
    required String projectKey,
    required IssueModel issue,
    VoidCallback? onIssueUpdated,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (isMobile) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.9,
          child: IssueDetailDialog(
            projectId: projectId,
            projectKey: projectKey,
            issue: issue,
            onIssueUpdated: onIssueUpdated,
          ),
        ),
      );
    } else {
      return showGeneralDialog<void>(
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
                child: IssueDetailDialog(
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
  Widget build(BuildContext context) {
    return IssueDetailPanel(
      projectId: projectId,
      projectKey: projectKey,
      issue: issue,
      onIssueUpdated: onIssueUpdated,
    );
  }
}
