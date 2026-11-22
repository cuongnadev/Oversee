import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Base button config and styling constants aligned with Figma .btn tokens.
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
    this.height = 38.0,
    this.icon,
    this.leadingIcon,
    this.trailingIcon,
    this.borderRadius = AppColors.radiusMd,
  });

  Widget _buildContent(BuildContext context, Color contentColor) {
    if (isLoading) {
      return SizedBox(
        width: 18.0,
        height: 18.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(contentColor),
        ),
      );
    }

    final Widget? lead = leadingIcon ?? (icon != null ? Icon(icon, size: 15.5, color: contentColor) : null);
    final Widget? trail = trailingIcon;

    if (lead == null && trail == null) {
      return Text(
        label,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
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
          const SizedBox(width: 6.0),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: contentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trail != null) ...[
          const SizedBox(width: 6.0),
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
        minWidth: 78.0,
        minHeight: height,
        maxHeight: height,
      ),
      child: child,
    );
  }
}

/// Primary brand filled button (Figma .btn-primary violet solid).
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEnabled = onPressed != null && !isLoading;
    final Color bg = AppColors.accentSolidFor(isDark);
    final Color contentColor = isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.6);

    return _wrapDimensions(
      ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: bg.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 13.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(context, contentColor),
      ),
    );
  }
}

/// Secondary soft button (Figma .btn surface-2 + border).
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
    final Color bgColor = AppColors.surface2For(isDark);
    final Color borderColor = AppColors.borderFor(isDark);
    final Color textColor = AppColors.textPrimaryFor(isDark);
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
          side: BorderSide(color: borderColor, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 13.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(context, contentColor),
      ),
    );
  }
}

/// Outlined button with clean 1px Figma border.
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
    final Color effectiveBorder = borderColor ?? AppColors.borderFor(isDark);
    final Color effectiveText = textColor ?? AppColors.textPrimaryFor(isDark);
    final Color contentColor = isEnabled ? effectiveText : effectiveText.withValues(alpha: 0.4);

    return _wrapDimensions(
      OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface2For(isDark),
          foregroundColor: effectiveText,
          disabledForegroundColor: effectiveText.withValues(alpha: 0.4),
          side: BorderSide(
            color: isEnabled ? effectiveBorder : effectiveBorder.withValues(alpha: 0.4),
            width: 1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(context, contentColor),
      ),
    );
  }
}

/// Destructive action button (Figma .btn-danger soft or solid).
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEnabled = onPressed != null && !isLoading;
    final Color dangerColor = AppColors.errorFor(isDark);
    final Color dangerSoft = AppColors.dangerSoftFor(isDark);

    if (isOutlined) {
      final Color contentColor = isEnabled ? dangerColor : dangerColor.withValues(alpha: 0.4);
      return _wrapDimensions(
        OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: dangerSoft.withValues(alpha: 0.5),
            foregroundColor: dangerColor,
            disabledForegroundColor: dangerColor.withValues(alpha: 0.4),
            side: BorderSide(
              color: isEnabled ? dangerColor.withValues(alpha: 0.45) : dangerColor.withValues(alpha: 0.2),
              width: 1.0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: _buildContent(context, contentColor),
        ),
      );
    }

    final Color contentColor = isEnabled ? dangerColor : dangerColor.withValues(alpha: 0.5);
    return _wrapDimensions(
      ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: dangerSoft,
          foregroundColor: dangerColor,
          disabledBackgroundColor: dangerSoft.withValues(alpha: 0.4),
          disabledForegroundColor: dangerColor.withValues(alpha: 0.5),
          elevation: 0,
          side: BorderSide(color: dangerColor.withValues(alpha: 0.28)),
          padding: const EdgeInsets.symmetric(horizontal: 13.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(context, contentColor),
      ),
    );
  }
}

/// Compact Icon Button aligned with Figma .icon-btn.
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
    this.size = 32.0,
    this.color,
    this.backgroundColor,
    this.borderRadius = AppColors.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Widget button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(borderRadius),
      hoverColor: AppColors.hoverFor(isDark),
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
            size: size * 0.54,
            color: color ?? AppColors.textSecondaryFor(isDark),
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
