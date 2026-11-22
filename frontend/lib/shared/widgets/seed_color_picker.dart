import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/shared/widgets/app_buttons.dart';
import 'package:frontend/shared/widgets/app_dialog.dart';

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
      setState(() => _hexError = 'Enter a valid 6-digit hex color (e.g. #2563EB)');
      return;
    }
    setState(() => _hexError = null);
    ref.read(seedColorProvider.notifier).setSeedColor(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final activeSeed = ref.watch(seedColorProvider);
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
        // Curated Preset Swatches
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
            'Custom Hex Color',
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
                label: 'Apply',
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
                'Reset to Default Violet',
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

/// Modal dialog for picking the global App Seed Color and Theme Mode.
class SeedColorPickerDialog extends ConsumerWidget {
  const SeedColorPickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return AppAdaptiveDialog.show<void>(
      context,
      title: 'Appearance & Accent Color',
      maxWidth: 460,
      child: const SeedColorPickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final accentColor = AppColors.accentFor(isDark);
    final accentSoft = AppColors.accentSoftFor(isDark);
    final borderColor = AppColors.borderFor(isDark);

    Widget modeChip(String label, IconData icon, ThemeMode mode) {
      final selected = themeMode == mode;
      return Expanded(
        child: InkWell(
          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(mode),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? accentSoft : AppColors.surface2For(isDark),
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
                    color: selected ? accentColor : AppColors.textPrimaryFor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme Mode',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            modeChip('Light', Icons.light_mode_outlined, ThemeMode.light),
            const SizedBox(width: 8),
            modeChip('Dark', Icons.dark_mode_outlined, ThemeMode.dark),
            const SizedBox(width: 8),
            modeChip('System', Icons.brightness_auto_outlined, ThemeMode.system),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Seed Color',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          'Applies synchronously across buttons, badges, charts, and active indicators.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMutedFor(isDark)),
        ),
        const SizedBox(height: 12),
        const SeedColorSelector(),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AppOutlinedButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
