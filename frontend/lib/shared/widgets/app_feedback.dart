import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Feedback toast and notification utilities for Oversee.
class AppFeedback {
  AppFeedback._();

  /// Displays a success snackbar banner.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppColors.success,
      duration: duration,
    );
  }

  /// Displays an error snackbar banner with optional detail.
  static void showError(
    BuildContext context,
    String message, {
    String? detail,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showSnackBar(
      context,
      message: detail != null ? '$message: $detail' : message,
      icon: Icons.error_outline_rounded,
      backgroundColor: AppColors.error,
      duration: duration,
    );
  }

  /// Displays a warning snackbar banner.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: AppColors.warning,
      textColor: Colors.black87,
      iconColor: Colors.black87,
      duration: duration,
    );
  }

  /// Displays an informational snackbar banner.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: AppColors.info,
      duration: duration,
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Color textColor = Colors.white,
    Color iconColor = Colors.white,
    required Duration duration,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWide = screenWidth > 600.0;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        width: isWide ? 460.0 : null,
        margin: isWide ? null : const EdgeInsets.all(16.0),
        backgroundColor: backgroundColor,
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20.0),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
