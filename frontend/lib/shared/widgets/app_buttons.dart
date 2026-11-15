import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Base button config and styling constants.
abstract class _AppButtonBase extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final IconData? icon;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final double borderRadius;

  const _AppButtonBase({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = 44.0,
    this.icon,
    this.leadingIcon,
    this.trailingIcon,
    this.borderRadius = 8.0,
  });

  Widget _buildContent(BuildContext context, Color contentColor) {
    if (isLoading) {
      return SizedBox(
        width: 20.0,
        height: 20.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(contentColor),
        ),
      );
    }

    final Widget? lead = leadingIcon ?? (icon != null ? Icon(icon, size: 18.0, color: contentColor) : null);
    final Widget? trail = trailingIcon;

    if (lead == null && trail == null) {
      return Text(
        label,
        style: TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          color: contentColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (lead != null) ...[
          lead,
          const SizedBox(width: 8.0),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trail != null) ...[
          const SizedBox(width: 8.0),
          trail,
        ],
      ],
    );
  }

  Widget _wrapDimensions(Widget child) {
    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: child,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 88.0,
        minHeight: height,
        maxHeight: height,
      ),
      child: child,
    );
  }
}

/// Primary brand filled button (Indigo).
class AppPrimaryButton extends _AppButtonBase {
  const AppPrimaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.isLoading,
    super.isFullWidth,
    super.height,
    super.icon,
    super.leadingIcon,
    super.trailingIcon,
    super.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;
    final Color contentColor = isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.6);

    return _wrapDimensions(
      ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(context, contentColor),
      ),
    );
  }
}

/// Secondary soft button (slate / sky tinted).
class AppSecondaryButton extends _AppButtonBase {
  const AppSecondaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.isLoading,
    super.isFullWidth,
    super.height,
    super.icon,
    super.leadingIcon,
    super.trailingIcon,
    super.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEnabled = onPressed != null && !isLoading;
    final Color bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color contentColor = isEnabled ? textColor : textColor.withValues(alpha: 0.4);

    return _wrapDimensions(
      FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.4),
          disabledForegroundColor: textColor.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(context, contentColor),
      ),
    );
  }
}

/// Outlined button with clean 1px border.
class AppOutlinedButton extends _AppButtonBase {
  final Color? borderColor;
  final Color? textColor;

  const AppOutlinedButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.isLoading,
    super.isFullWidth,
    super.height,
    super.icon,
    super.leadingIcon,
    super.trailingIcon,
    super.borderRadius,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEnabled = onPressed != null && !isLoading;
    final Color effectiveBorder = borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight);
    final Color effectiveText = textColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final Color contentColor = isEnabled ? effectiveText : effectiveText.withValues(alpha: 0.4);

    return _wrapDimensions(
      OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveText,
          disabledForegroundColor: effectiveText.withValues(alpha: 0.4),
          side: BorderSide(
            color: isEnabled ? effectiveBorder : effectiveBorder.withValues(alpha: 0.4),
            width: 1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(context, contentColor),
      ),
    );
  }
}

/// Destructive action button (Red / Danger) for delete/terminate operations.
class AppDestructiveButton extends _AppButtonBase {
  final bool isOutlined;

  const AppDestructiveButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.isLoading,
    super.isFullWidth,
    super.height,
    super.icon,
    super.leadingIcon,
    super.trailingIcon,
    super.borderRadius,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    if (isOutlined) {
      final Color contentColor = isEnabled ? AppColors.error : AppColors.error.withValues(alpha: 0.4);
      return _wrapDimensions(
        OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            disabledForegroundColor: AppColors.error.withValues(alpha: 0.4),
            side: BorderSide(
              color: isEnabled ? AppColors.error : AppColors.error.withValues(alpha: 0.4),
              width: 1.0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: _buildContent(context, contentColor),
        ),
      );
    }

    final Color contentColor = isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.6);
    return _wrapDimensions(
      ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.error.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(context, contentColor),
      ),
    );
  }
}

/// Compact Icon Button with hover and tooltip support.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final double borderRadius;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 36.0,
    this.color,
    this.backgroundColor,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.55,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
