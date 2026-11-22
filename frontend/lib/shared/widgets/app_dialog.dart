import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';

/// Confirmation Dialog aligned with Figma Modal styling.
class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final Widget? content;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final bool isLoading;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.content,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
    this.isLoading = false,
    this.onConfirm,
    this.onCancel,
  });

  /// Shows the confirmation dialog and returns true if confirmed.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    Widget? content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AppConfirmationDialog(
        title: title,
        message: message,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(dialogContext).pop(true),
        onCancel: () => Navigator.of(dialogContext).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color borderColor = AppColors.borderFor(isDark);
    final Color dangerColor = AppColors.errorFor(isDark);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        side: BorderSide(color: borderColor),
      ),
      backgroundColor: AppColors.surfaceFor(isDark),
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  if (isDestructive) ...[
                    Container(
                      padding: const EdgeInsets.all(7.0),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSoftFor(isDark),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: dangerColor,
                        size: 18.0,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryFor(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Modal body
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryFor(isDark),
                      height: 1.5,
                    ),
                  ),
                  if (content != null) ...[
                    const SizedBox(height: 16.0),
                    content!,
                  ],
                ],
              ),
            ),

            // Modal footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppOutlinedButton(
                    label: cancelText,
                    onPressed: isLoading ? null : (onCancel ?? () => Navigator.of(context).pop(false)),
                  ),
                  const SizedBox(width: 10.0),
                  if (isDestructive)
                    AppDestructiveButton(
                      label: confirmText,
                      isLoading: isLoading,
                      onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                    )
                  else
                    AppPrimaryButton(
                      label: confirmText,
                      isLoading: isLoading,
                      onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adaptive modal wrapper: Dialog on wide screens, BottomSheet on phones.
class AppAdaptiveDialog extends StatelessWidget {
  final String? title;
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AppAdaptiveDialog({
    super.key,
    this.title,
    required this.child,
    this.maxWidth = 540.0,
    this.padding = const EdgeInsets.all(20.0),
  });

  /// Displays the child inside an adaptive modal container.
  static Future<T?> show<T extends Object?>(
    BuildContext context, {
    String? title,
    required Widget child,
    double maxWidth = 540.0,
    bool isDismissible = true,
  }) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isMobile = screenWidth < AppConstants.mobileBreakpoint;

    if (isMobile) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        isDismissible: isDismissible,
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheetContext) {
          final ThemeData theme = Theme.of(sheetContext);
          final bool isDark = theme.brightness == Brightness.dark;
          final Color borderColor = AppColors.borderFor(isDark);

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(isDark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 36.0,
                          height: 4.0,
                          margin: const EdgeInsets.only(bottom: 14.0),
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                        ),
                      ),
                      if (title != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 19.0, color: AppColors.textMutedFor(isDark)),
                              onPressed: () => Navigator.of(sheetContext).pop(),
                            ),
                          ],
                        ),
                        Divider(height: 16.0, color: borderColor),
                      ],
                      child,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        final bool isDark = theme.brightness == Brightness.dark;
        final Color borderColor = AppColors.borderFor(isDark);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusXl),
            side: BorderSide(color: borderColor),
          ),
          backgroundColor: AppColors.surfaceFor(isDark),
          elevation: 0,
          insetPadding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryFor(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 18.0, color: AppColors.textMutedFor(isDark)),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          splashRadius: 18.0,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
