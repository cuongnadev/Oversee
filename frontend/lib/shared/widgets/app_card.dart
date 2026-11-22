import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Card container aligned with Figma .panel / .issue-card tokens.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final bool showBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.backgroundColor,
    this.borderRadius = AppColors.radiusLg,
    this.showBorder = true,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color baseBg = widget.backgroundColor ?? AppColors.surfaceFor(isDark);
    final Color bgColor = _isHovered && widget.onTap != null && widget.backgroundColor == null
        ? AppColors.surface2For(isDark)
        : baseBg;
    final Color borderColor = AppColors.borderFor(isDark);
    final Color effectiveBorder = _isHovered && widget.onTap != null
        ? AppColors.textMutedFor(isDark)
        : borderColor;

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.onTap != null) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (widget.onTap != null) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.showBorder
              ? Border.all(
                  color: effectiveBorder,
                  width: 1.0,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _isHovered && widget.onTap != null
                    ? (isDark ? 0.25 : 0.06)
                    : (isDark ? 0.14 : 0.03),
              ),
              blurRadius: _isHovered && widget.onTap != null ? 8.0 : 3.0,
              offset: Offset(0, _isHovered && widget.onTap != null ? 3.0 : 1.5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
