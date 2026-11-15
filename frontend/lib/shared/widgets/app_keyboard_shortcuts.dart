import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/theme/app_colors.dart';

/// Intent for triggering a data refresh via keyboard.
class RefreshIntent extends Intent {
  const RefreshIntent();
}

/// Intent for creating a new issue/task via keyboard shortcut.
class NewIssueIntent extends Intent {
  const NewIssueIntent();
}

/// Intent for opening the keyboard shortcuts cheatsheet dialog.
class HelpShortcutsIntent extends Intent {
  const HelpShortcutsIntent();
}

/// Intent for closing or canceling via Escape.
class EscapeIntent extends Intent {
  const EscapeIntent();
}

/// Reusable keyboard navigation wrapper for Oversee screens (Web & Desktop).
/// Supports shortcuts:
/// - 'r' or 'Ctrl+R' / 'Cmd+R': Refresh
/// - 'c' or 'Ctrl+N' / 'Cmd+N': Create new issue
/// - '?' (Shift+/): Show shortcuts cheatsheet
/// - 'Esc': Close active overlay or unfocus
class AppKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;
  final VoidCallback? onNewIssue;
  final VoidCallback? onEscape;
  final bool enableShortcuts;

  const AppKeyboardShortcuts({
    super.key,
    required this.child,
    this.onRefresh,
    this.onNewIssue,
    this.onEscape,
    this.enableShortcuts = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableShortcuts) return child;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        // Refresh: 'r' or Ctrl/Cmd + R
        SingleActivator(LogicalKeyboardKey.keyR): RefreshIntent(),
        SingleActivator(LogicalKeyboardKey.keyR, control: true): RefreshIntent(),
        SingleActivator(LogicalKeyboardKey.keyR, meta: true): RefreshIntent(),

        // New Issue: 'c' or Ctrl/Cmd + N
        SingleActivator(LogicalKeyboardKey.keyC): NewIssueIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true): NewIssueIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true): NewIssueIntent(),

        // Help: '?' (Shift + Slash) or F1
        SingleActivator(LogicalKeyboardKey.slash, shift: true): HelpShortcutsIntent(),
        SingleActivator(LogicalKeyboardKey.f1): HelpShortcutsIntent(),

        // Escape: Esc
        SingleActivator(LogicalKeyboardKey.escape): EscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (intent) {
              onRefresh?.call();
              return null;
            },
          ),
          NewIssueIntent: CallbackAction<NewIssueIntent>(
            onInvoke: (intent) {
              onNewIssue?.call();
              return null;
            },
          ),
          HelpShortcutsIntent: CallbackAction<HelpShortcutsIntent>(
            onInvoke: (intent) {
              KeyboardShortcutsDialog.show(context);
              return null;
            },
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (intent) {
              if (onEscape != null) {
                onEscape!();
              } else {
                FocusScope.of(context).unfocus();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

/// Accessible Keyboard Shortcuts Cheatsheet Dialog.
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const KeyboardShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final shortcuts = [
      {'keys': 'R / Ctrl+R', 'desc': 'Refresh dashboard and screen metrics'},
      {'keys': 'C / Ctrl+N', 'desc': 'Quickly create a new issue or task'},
      {'keys': '?', 'desc': 'Open this keyboard shortcuts dialog'},
      {'keys': 'Esc', 'desc': 'Close modal dialog, drawer, or unfocus'},
      {'keys': 'Tab / Shift+Tab', 'desc': 'Navigate between interactive controls'},
      {'keys': 'Space / Enter', 'desc': 'Activate focused button or toggle control'},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.keyboard_outlined, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Keyboard Shortcuts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close (Esc)',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Speed up your navigation across Oversee using these hotkeys:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),

              // Shortcuts table / list
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: shortcuts.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  itemBuilder: (context, index) {
                    final item = shortcuts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['desc']!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Text(
                              item['keys']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
