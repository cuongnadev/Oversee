import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';

/// Confirmation Dialog with optional destructive styling.
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      elevation: 6.0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440.0),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isDestructive) ...[
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight.withValues(alpha: isDark ? 0.2 : 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 22.0,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
              if (content != null) ...[
                const SizedBox(height: 16.0),
                content!,
              ],
              const SizedBox(height: 24.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppOutlinedButton(
                    label: cancelText,
                    onPressed: isLoading ? null : (onCancel ?? () => Navigator.of(context).pop(false)),
                  ),
                  const SizedBox(width: 12.0),
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
            ],
          ),
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
    this.padding = const EdgeInsets.all(24.0),
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

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
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
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36.0,
                          height: 4.0,
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
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
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.of(sheetContext).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
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

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
          elevation: 6.0,
          insetPadding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          splashRadius: 20.0,
                        ),
                      ],
                    ),
                    const Divider(height: 24.0),
                  ],
                  child,
                ],
              ),
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
