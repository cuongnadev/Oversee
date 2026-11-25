import 'package:flutter/material.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';

/// Error categories classified for user-friendly UI presentation.
enum ErrorCategory {
  network,
  server,
  forbidden,
  notFound,
  unauthorized,
  validation,
  general,
}

/// Helper class to resolve an error object/message to human-friendly title, message, and icon.
class ErrorPresentation {
  final ErrorCategory category;
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const ErrorPresentation({
    required this.category,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  factory ErrorPresentation.resolve(dynamic error) {
    if (error is NetworkException) {
      return const ErrorPresentation(
        category: ErrorCategory.network,
        title: 'Network Connection Lost',
        message:
            'Unable to reach Oversee servers. Please check your internet or Wi-Fi connection and try again.',
        icon: Icons.wifi_off_rounded,
        color: AppColors.warning,
      );
    }

    if (error is ServerException) {
      return ErrorPresentation(
        category: ErrorCategory.server,
        title: 'Server Error (500)',
        message: error.message.isNotEmpty
            ? error.message
            : 'Our servers encountered an internal error. Please try again in a few moments.',
        icon: Icons.dns_rounded,
        color: AppColors.error,
      );
    }

    if (error is ForbiddenException) {
      return ErrorPresentation(
        category: ErrorCategory.forbidden,
        title: 'Access Restricted (403)',
        message: error.message.isNotEmpty
            ? error.message
            : 'You do not have administrative permissions or privileges to access this resource.',
        icon: Icons.lock_person_rounded,
        color: AppColors.warning,
      );
    }

    if (error is NotFoundException) {
      return ErrorPresentation(
        category: ErrorCategory.notFound,
        title: 'Not Found (404)',
        message: error.message.isNotEmpty
            ? error.message
            : 'The requested sprint, project, or task could not be found or has been deleted.',
        icon: Icons.search_off_rounded,
        color: const Color(0xFF64748B),
      );
    }

    if (error is UnauthorizedException) {
      return ErrorPresentation(
        category: ErrorCategory.unauthorized,
        title: 'Session Expired',
        message: error.message.isNotEmpty
            ? error.message
            : 'Your credentials or authentication token have expired. Please log in again.',
        icon: Icons.vpn_key_off_rounded,
        color: AppColors.error,
      );
    }

    if (error is ValidationException) {
      return ErrorPresentation(
        category: ErrorCategory.validation,
        title: 'Invalid Request',
        message: error.message.isNotEmpty ? error.message : 'Please check your inputs and try again.',
        icon: Icons.report_problem_rounded,
        color: AppColors.warning,
      );
    }

    final String raw = (error?.toString() ?? '').toLowerCase();

    if (raw.contains('network') ||
        raw.contains('connection') ||
        raw.contains('offline') ||
        raw.contains('socket') ||
        raw.contains('timeout')) {
      return const ErrorPresentation(
        category: ErrorCategory.network,
        title: 'Network Connection Lost',
        message:
            'Unable to reach Oversee servers. Please check your internet or Wi-Fi connection and try again.',
        icon: Icons.wifi_off_rounded,
        color: AppColors.warning,
      );
    }

    if (raw.contains('500') || raw.contains('server') || raw.contains('internal')) {
      return ErrorPresentation(
        category: ErrorCategory.server,
        title: 'Server Error',
        message: error is String && error.isNotEmpty
            ? error
            : 'Our servers encountered an internal error. Please try again in a few moments.',
        icon: Icons.dns_rounded,
        color: AppColors.error,
      );
    }

    if (raw.contains('403') || raw.contains('forbidden') || raw.contains('permission')) {
      return ErrorPresentation(
        category: ErrorCategory.forbidden,
        title: 'Access Restricted',
        message: error is String && error.isNotEmpty
            ? error
            : 'You do not have administrative permissions or privileges to access this resource.',
        icon: Icons.lock_person_rounded,
        color: AppColors.warning,
      );
    }

    if (raw.contains('404') || raw.contains('not found')) {
      return ErrorPresentation(
        category: ErrorCategory.notFound,
        title: 'Not Found',
        message: error is String && error.isNotEmpty
            ? error
            : 'The requested resource could not be found or has been deleted.',
        icon: Icons.search_off_rounded,
        color: const Color(0xFF64748B),
      );
    }

    // General fallback
    return ErrorPresentation(
      category: ErrorCategory.general,
      title: 'Something Went Wrong',
      message: (error is String && error.isNotEmpty)
          ? error
          : (error is AppException ? error.message : 'An unexpected error occurred while processing your request.'),
      icon: Icons.error_outline_rounded,
      color: AppColors.error,
    );
  }
}

/// Comprehensive full-page or card-level error state widget with icon, classification, and retry action.
class AppErrorView extends StatelessWidget {
  final dynamic error;
  final String? customTitle;
  final String? customMessage;
  final VoidCallback? onRetry;
  final String retryLabel;
  final double iconSize;

  const AppErrorView({
    super.key,
    this.error,
    this.customTitle,
    this.customMessage,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.iconSize = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final presentation = ErrorPresentation.resolve(error);

    final title = customTitle ?? presentation.title;
    final message = customMessage ?? presentation.message;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Circle with soft halo
              Container(
                width: iconSize * 1.8,
                height: iconSize * 1.8,
                decoration: BoxDecoration(
                  color: presentation.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: presentation.color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    presentation.icon,
                    size: iconSize,
                    color: presentation.color,
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18.0,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 10.0),

              // Description
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.45,
                ),
              ),

              // Action button (Retry)
              if (onRetry != null) ...[
                const SizedBox(height: 22.0),
                AppPrimaryButton(
                  icon: Icons.refresh_rounded,
                  label: retryLabel,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline banner for error notifications inside cards or toolbars.
class AppErrorBanner extends StatelessWidget {
  final dynamic error;
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorBanner({
    super.key,
    this.error,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final presentation = ErrorPresentation.resolve(error);
    final displayMessage = message ?? presentation.message;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: presentation.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(presentation.icon, color: presentation.color, size: 20.0),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              displayMessage,
              style: TextStyle(
                fontSize: 13.0,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8.0),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16.0),
              label: Text(l10n.retry),
              style: TextButton.styleFrom(
                foregroundColor: presentation.color,
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              ),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
