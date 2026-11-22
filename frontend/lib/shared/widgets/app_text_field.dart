import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Form text field aligned with Figma .field / .input styling.
class AppTextFormField extends StatefulWidget {
  final String? label;
  final bool isRequired;
  final String? hintText;
  final String? initialValue;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool isPassword;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? helperText;
  final String? errorText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool showClearButton;
  final EdgeInsetsGeometry? contentPadding;

  const AppTextFormField({
    super.key,
    this.label,
    this.isRequired = false,
    this.hintText,
    this.initialValue,
    this.controller,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.isPassword = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.helperText,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.inputFormatters,
    this.focusNode,
    this.showClearButton = false,
    this.contentPadding,
  });

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormFieldState extends State<AppTextFormField> {
  late bool _obscureText;
  late TextEditingController _effectiveController;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _effectiveController = widget.controller ?? TextEditingController(text: widget.initialValue);
    _hasText = _effectiveController.text.isNotEmpty;
    _effectiveController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant AppTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _effectiveController = widget.controller ?? TextEditingController(text: widget.initialValue);
      _hasText = _effectiveController.text.isNotEmpty;
      _effectiveController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _effectiveController.removeListener(_onTextChanged);
      _effectiveController.dispose();
    } else {
      widget.controller!.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final bool currentHasText = _effectiveController.text.isNotEmpty;
    if (_hasText != currentHasText) {
      setState(() {
        _hasText = currentHasText;
      });
    }
  }

  void _toggleObscure() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  void _clearText() {
    _effectiveController.clear();
    widget.onChanged?.call('');
  }

  Widget? _buildSuffixIcon(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.isPassword) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18.0,
          color: AppColors.textMutedFor(isDark),
        ),
        onPressed: _toggleObscure,
        splashRadius: 18.0,
        tooltip: _obscureText ? 'Show password' : 'Hide password',
      );
    }

    if (widget.showClearButton && _hasText && widget.enabled && !widget.readOnly) {
      return IconButton(
        icon: Icon(Icons.clear_rounded, size: 16.0, color: AppColors.textMutedFor(isDark)),
        onPressed: _clearText,
        splashRadius: 18.0,
        tooltip: 'Clear text',
      );
    }

    return widget.suffixIcon;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color fillColor = widget.enabled
        ? AppColors.bgFor(isDark)
        : AppColors.surface2For(isDark);

    final Color borderColor = AppColors.borderFor(isDark);
    final Color textColor = AppColors.textPrimaryFor(isDark);
    final Color labelColor = AppColors.textSecondaryFor(isDark);
    final Color hintColor = AppColors.textMutedFor(isDark);
    final Color accentColor = AppColors.accentFor(isDark);
    final Color errorColor = AppColors.errorFor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
              if (widget.isRequired) ...[
                const SizedBox(width: 4.0),
                Text(
                  '*',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: errorColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6.0),
        ],
        TextFormField(
          controller: _effectiveController,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          obscureText: _obscureText,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          focusNode: widget.focusNode,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w400,
            color: widget.enabled ? textColor : textColor.withValues(alpha: 0.5),
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              color: hintColor,
            ),
            helperText: widget.helperText,
            errorText: widget.errorText,
            filled: true,
            fillColor: fillColor,
            prefixIcon: widget.prefixIcon,
            suffixIcon: _buildSuffixIcon(context),
            contentPadding: widget.contentPadding ??
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(color: errorColor, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(color: errorColor, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 1.0),
            ),
          ),
        ),
      ],
    );
  }
}
