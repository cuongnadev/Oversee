import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/l10n/locale_provider.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/font_scale_provider.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';
import 'package:frontend/shared/widgets/app_dialog.dart';
import 'package:frontend/shared/widgets/app_feedback.dart';

/// Reusable swatch grid + custom hex input for choosing the app-wide seed color.
class SeedColorSelector extends ConsumerStatefulWidget {
  final bool showCustomHexInput;
  final bool showResetButton;

  const SeedColorSelector({
    super.key,
    this.showCustomHexInput = true,
    this.showResetButton = true,
  });

  @override
  ConsumerState<SeedColorSelector> createState() => _SeedColorSelectorState();
}

class _SeedColorSelectorState extends ConsumerState<SeedColorSelector> {
  late final TextEditingController _hexController;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    final current = ref.read(seedColorProvider);
    _hexController = TextEditingController(text: _formatHex(current));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static String _formatHex(Color c) {
    final argb = c.toARGB32() & 0x00FFFFFF;
    return '#${argb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color? parseHexColor(String raw) {
    final cleaned = raw.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
      return null;
    }
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  void _applyHex() {
    final parsed = parseHexColor(_hexController.text);
    if (parsed == null) {
      setState(() => _hexError = context.l10n.invalidHexColor);
      return;
    }
    setState(() => _hexError = null);
    ref.read(seedColorProvider.notifier).setSeedColor(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final activeSeed = ref.watch(seedColorProvider);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = AppColors.borderFor(isDark);
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: appSeedColorPresets.map((preset) {
            final isSelected = activeSeed.toARGB32() == preset.color.toARGB32();
            return Tooltip(
              message: preset.name,
              child: InkWell(
                onTap: () {
                  _hexController.text = _formatHex(preset.color);
                  setState(() => _hexError = null);
                  ref.read(seedColorProvider.notifier).setSeedColor(preset.color);
                },
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? accentSoft : AppColors.surface2For(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(
                      color: isSelected ? accentColor : borderColor,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: preset.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? accentColor : textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.showCustomHexInput) ...[
          const SizedBox(height: 16),
          Text(
            l10n.customHexColor,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: activeSeed,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: borderColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _hexController,
                    style: AppTypography.mono(isDark, fontSize: 12.5, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: '#7253D5',
                      hintStyle: AppTypography.mono(isDark, fontSize: 12, color: textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onSubmitted: (_) => _applyHex(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppPrimaryButton(
                label: l10n.apply,
                height: 36,
                onPressed: _applyHex,
              ),
            ],
          ),
          if (_hexError != null) ...[
            const SizedBox(height: 5),
            Text(
              _hexError!,
              style: TextStyle(fontSize: 11.5, color: AppColors.errorFor(isDark)),
            ),
          ],
        ],
        if (widget.showResetButton &&
            activeSeed.toARGB32() != AppColors.defaultSeedColor.toARGB32()) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: Icon(Icons.restart_alt_rounded, size: 15, color: textSecondary),
              label: Text(
                l10n.resetToDefaultViolet,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              onPressed: () {
                _hexController.text = _formatHex(AppColors.defaultSeedColor);
                setState(() => _hexError = null);
                ref.read(seedColorProvider.notifier).resetToDefault();
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Modal dialog for picking global App Language, Theme Mode, Font Sizes (Whole App & Content Pane),
/// and Seed Color.
class SeedColorPickerDialog extends ConsumerStatefulWidget {
  const SeedColorPickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: context.l10n.appearanceAndSettings,
      maxWidth: 480,
      child: const SeedColorPickerDialog(),
    );
  }

  @override
  ConsumerState<SeedColorPickerDialog> createState() => _SeedColorPickerDialogState();
}

class _SeedColorPickerDialogState extends ConsumerState<SeedColorPickerDialog> {
  late int _draftAppPercent;
  late int _draftContentPercent;

  @override
  void initState() {
    super.initState();
    final current = ref.read(fontScaleProvider);
    _draftAppPercent = current.appPercent;
    _draftContentPercent = current.contentPercent;
  }

  Future<void> _confirmFontSize() async {
    await ref.read(fontScaleProvider.notifier).applyFontScales(
          appPercent: _draftAppPercent,
          contentPercent: _draftContentPercent,
        );
    if (mounted) {
      AppFeedback.showSuccess(
        context,
        '${context.l10n.fontSizeApplied} ($_draftAppPercent% / $_draftContentPercent%)',
      );
    }
  }

  Future<void> _resetFontSize() async {
    setState(() {
      _draftAppPercent = FontScaleState.defaultAppPercent;
      _draftContentPercent = FontScaleState.defaultContentPercent;
    });
    await ref.read(fontScaleProvider.notifier).resetToDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeProvider);
    final activeLocale = ref.watch(localeProvider);
    final currentFontScale = ref.watch(fontScaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final textMuted = AppColors.textMutedFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final surface2 = AppColors.surface2For(isDark);

    final hasPendingFontChange = _draftAppPercent != currentFontScale.appPercent ||
        _draftContentPercent != currentFontScale.contentPercent;

    Widget modeChip(String label, IconData icon, ThemeMode mode) {
      final selected = themeMode == mode;
      return Expanded(
        child: InkWell(
          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(mode),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? accentSoft : surface2,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: selected ? accentColor : borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: selected ? accentColor : textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? accentColor : textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget languageChip(String label, String code, Locale locale) {
      final selected = activeLocale.languageCode == locale.languageCode;
      return Expanded(
        child: InkWell(
          onTap: () => ref.read(localeProvider.notifier).setLocale(locale),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? accentSoft : surface2,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: selected ? accentColor : borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? accentColor.withValues(alpha: 0.16) : AppColors.surface3For(isDark),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Text(
                    code,
                    style: AppTypography.mono(
                      isDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? accentColor : textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? accentColor : textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget fontStepperRow({
      required Key decrementKey,
      required Key incrementKey,
      required Key valueKey,
      required String label,
      required int percent,
      required VoidCallback onDecrease,
      required VoidCallback onIncrease,
    }) {
      final canDecrease = percent > FontScaleState.minPercent;
      final canIncrease = percent < FontScaleState.maxPercent;

      return Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
          Tooltip(
            message: l10n.decreaseFontSizeTooltip,
            child: InkWell(
              key: decrementKey,
              onTap: canDecrease ? onDecrease : null,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '-10%',
                  style: AppTypography.mono(
                    isDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: canDecrease ? textPrimary : textMuted,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$percent%',
              key: valueKey,
              textAlign: TextAlign.center,
              style: AppTypography.mono(
                isDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          Tooltip(
            message: l10n.increaseFontSizeTooltip,
            child: InkWell(
              key: incrementKey,
              onTap: canIncrease ? onIncrease : null,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '+10%',
                  style: AppTypography.mono(
                    isDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: canIncrease ? textPrimary : textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language Selector
        Text(
          l10n.language,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            languageChip(l10n.english, 'EN', AppLocalizations.en),
            const SizedBox(width: 8),
            languageChip(l10n.vietnamese, 'VI', AppLocalizations.vi),
          ],
        ),
        const SizedBox(height: 16),

        // Theme Mode
        Text(
          l10n.themeMode,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            modeChip(l10n.light, Icons.light_mode_outlined, ThemeMode.light),
            const SizedBox(width: 8),
            modeChip(l10n.dark, Icons.dark_mode_outlined, ThemeMode.dark),
            const SizedBox(width: 8),
            modeChip(l10n.system, Icons.brightness_auto_outlined, ThemeMode.system),
          ],
        ),
        const SizedBox(height: 18),

        // Dual Font Size Controls (Whole App & Content Pane)
        Text(
          l10n.fontSize,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.fontSizeDescription,
          style: TextStyle(fontSize: 11.5, color: textMuted),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgFor(isDark),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              fontStepperRow(
                decrementKey: const Key('app_font_decrease_btn'),
                incrementKey: const Key('app_font_increase_btn'),
                valueKey: const Key('app_font_percent_value'),
                label: l10n.wholeAppFontSize,
                percent: _draftAppPercent,
                onDecrease: () => setState(
                  () => _draftAppPercent = FontScaleState.stepDown(_draftAppPercent),
                ),
                onIncrease: () => setState(
                  () => _draftAppPercent = FontScaleState.stepUp(_draftAppPercent),
                ),
              ),
              const SizedBox(height: 10),
              fontStepperRow(
                decrementKey: const Key('content_font_decrease_btn'),
                incrementKey: const Key('content_font_increase_btn'),
                valueKey: const Key('content_font_percent_value'),
                label: l10n.contentPaneFontSize,
                percent: _draftContentPercent,
                onDecrease: () => setState(
                  () => _draftContentPercent = FontScaleState.stepDown(_draftContentPercent),
                ),
                onIncrease: () => setState(
                  () => _draftContentPercent = FontScaleState.stepUp(_draftContentPercent),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('font_size_reset_btn'),
                    onPressed: _resetFontSize,
                    child: Text(l10n.reset, style: TextStyle(fontSize: 12, color: textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  AppPrimaryButton(
                    key: const Key('font_size_confirm_btn'),
                    label: l10n.confirm,
                    height: 32,
                    onPressed: hasPendingFontChange ? _confirmFontSize : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Seed Color
        Text(
          l10n.seedColor,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.seedColorDescription,
          style: TextStyle(fontSize: 11.5, color: textMuted),
        ),
        const SizedBox(height: 12),
        const SeedColorSelector(),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AppOutlinedButton(
            label: l10n.done,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
