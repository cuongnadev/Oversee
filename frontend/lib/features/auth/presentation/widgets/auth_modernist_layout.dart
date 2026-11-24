import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/shared/layout/sidebar_icons.dart';

/// Shared Oversee wordmark matching the renovated Figma sidebar brand lockup.
class AuthBrandMark extends StatelessWidget {
  final Color foregroundColor;
  final Color accentColor;
  final double iconSize;
  final double fontSize;

  const AuthBrandMark({
    super.key,
    required this.foregroundColor,
    required this.accentColor,
    this.iconSize = 20.0,
    this.fontSize = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: FigmaSidebarIcon(
              FigmaIconType.layers3,
              size: iconSize,
              color: accentColor,
              strokeWidth: 1.75,
            ),
          ),
          const SizedBox(width: 9.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Oversee',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: AppTypography.fontFallback,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.9,
                  height: 1.0,
                  color: foregroundColor,
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  '.',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: AppTypography.fontFallback,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Smoothly expanding inline error banner with full 1px border, live-region
/// semantics, and an accessible dismiss control.
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  final VoidCallback onDismiss;

  const AuthErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorColor = AppColors.errorFor(isDark);
    final dangerSoft = AppColors.dangerSoftFor(isDark);
    final hasMessage = message != null && message!.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: hasMessage
          ? Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18.0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13.0, 6.0, 4.0, 6.0),
                  decoration: BoxDecoration(
                    color: dangerSoft,
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(
                      color: errorColor.withValues(alpha: isDark ? 0.45 : 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: errorColor,
                        size: 18.0,
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: Text(
                            message!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: errorColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16.0,
                          color: errorColor,
                        ),
                        tooltip: 'Dismiss error',
                        constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
                        padding: EdgeInsets.zero,
                        splashRadius: 18.0,
                        onPressed: onDismiss,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Modernist asymmetric split-canvas layout shared by Login and Register routes.
///
/// Desktop & wide tablet (`>= 780px`): Full-bleed architectural modernist hero pane
/// on the left paired with an open, hairline-separated form workspace on the right.
/// Compact & mobile (`< 780px`): Slim editorial hero header stacked above a crisp form pane.
class AuthModernistLayout extends ConsumerWidget {
  final String heroHeadline;
  final String heroSubtitle;
  final String formTitle;
  final String formSubtitle;
  final Widget formChild;
  final Widget footerChild;

  const AuthModernistLayout({
    super.key,
    required this.heroHeadline,
    required this.heroSubtitle,
    required this.formTitle,
    required this.formSubtitle,
    required this.formChild,
    required this.footerChild,
  });

  static const String _darkHeroAsset = 'assets/images/auth_hero_dark.jpg';
  static const String _lightHeroAsset = 'assets/images/auth_hero_light.jpg';
  static const double _splitBreakpoint = 780.0;

  void _toggleBrightness(WidgetRef ref, bool isDark) {
    ref.read(themeModeProvider.notifier).setThemeMode(
          isDark ? ThemeMode.light : ThemeMode.dark,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = isDark ? AppColors.bgDark : AppColors.surfaceLight;

    return Scaffold(
      backgroundColor: surfaceBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isSplit = width >= _splitBreakpoint;

          if (isSplit) {
            final isWide = width >= 1120.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: isWide ? 11 : 9,
                  child: _DesktopHeroPane(
                    isDark: isDark,
                    isWide: isWide,
                    headline: heroHeadline,
                    subtitle: heroSubtitle,
                  ),
                ),
                Container(
                  width: 1.0,
                  color: AppColors.borderFor(isDark),
                ),
                Expanded(
                  flex: isWide ? 10 : 11,
                  child: _FormWorkspacePane(
                    isDark: isDark,
                    isCompactHeight: constraints.maxHeight < 660.0,
                    formTitle: formTitle,
                    formSubtitle: formSubtitle,
                    formChild: formChild,
                    footerChild: footerChild,
                    onToggleTheme: () => _toggleBrightness(ref, isDark),
                  ),
                ),
              ],
            );
          }

          return _CompactAuthLayout(
            isDark: isDark,
            heroHeadline: heroHeadline,
            formTitle: formTitle,
            formSubtitle: formSubtitle,
            formChild: formChild,
            footerChild: footerChild,
            onToggleTheme: () => _toggleBrightness(ref, isDark),
          );
        },
      ),
    );
  }
}

class _DesktopHeroPane extends StatelessWidget {
  final bool isDark;
  final bool isWide;
  final String headline;
  final String subtitle;

  const _DesktopHeroPane({
    required this.isDark,
    required this.isWide,
    required this.headline,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath =
        isDark ? AuthModernistLayout._darkHeroAsset : AuthModernistLayout._lightHeroAsset;
    final accentColor = AppColors.accentFor(isDark);
    final padH = isWide ? 48.0 : 32.0;
    final padV = isWide ? 40.0 : 28.0;

    // On the light architectural gallery plate, the upper-left wall is luminous cool plaster
    // while the lower-left plinth sits in deep charcoal shadow.
    final topForeground = isDark ? const Color(0xFFF3F3F7) : AppColors.textPrimaryLight;
    final topAccent = isDark ? AppColors.primaryLight : AppColors.primaryDark;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ModernistArchitecturalFallback(isDark: isDark),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Image.asset(
              assetPath,
              key: ValueKey(assetPath),
              fit: BoxFit.cover,
              alignment: isDark ? const Alignment(0.15, 0.0) : const Alignment(0.0, 0.0),
              gaplessPlayback: true,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

          // Restrained bottom scrim ensuring AAA legibility for editorial copy on any crop
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.48, 0.78, 1.0],
                colors: isDark
                    ? const [
                        Color(0x380B0C10),
                        Color(0x000B0C10),
                        Color(0x780B0C10),
                        Color(0xCC0B0C10),
                      ]
                    : const [
                        Color(0x18F7F7FA),
                        Color(0x001B2026),
                        Color(0x66181D23),
                        Color(0xC814181E),
                      ],
              ),
            ),
          ),

          // Scroll-safe editorial layout so short windows or landscape keyboards never overflow
          SafeArea(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AuthBrandMark(
                          foregroundColor: topForeground,
                          accentColor: topAccent,
                          iconSize: 20.0,
                          fontSize: 22.0,
                        ),
                        const Spacer(),
                        const SizedBox(height: 24.0),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32.0,
                                height: 2.0,
                                color: isDark ? accentColor : AppColors.primaryLight,
                              ),
                              const SizedBox(height: 18.0),
                              Text(
                                headline,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontFamilyFallback: AppTypography.fontFallback,
                                  fontSize: isWide ? 34.0 : 26.0,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1.0,
                                  height: 1.12,
                                  color: const Color(0xFFF6F6FA),
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontFamilyFallback: AppTypography.fontFallback,
                                  fontSize: isWide ? 14.0 : 13.0,
                                  fontWeight: FontWeight.w400,
                                  height: 1.55,
                                  color: const Color(0xFFD2D5E0),
                                ),
                              ),
                              const SizedBox(height: 24.0),
                              Container(
                                height: 1.0,
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              const SizedBox(height: 14.0),
                              const Wrap(
                                spacing: 10.0,
                                runSpacing: 6.0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _HeroCapabilityLabel('Boards'),
                                  _HeroDotSeparator(),
                                  _HeroCapabilityLabel('Backlog'),
                                  _HeroDotSeparator(),
                                  _HeroCapabilityLabel('Timeline'),
                                  _HeroDotSeparator(),
                                  _HeroCapabilityLabel('Calendar'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCapabilityLabel extends StatelessWidget {
  final String label;

  const _HeroCapabilityLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: AppTypography.fontFallback,
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: Colors.white.withValues(alpha: 0.78),
      ),
    );
  }
}

class _HeroDotSeparator extends StatelessWidget {
  const _HeroDotSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3.0,
      height: 3.0,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FormWorkspacePane extends StatelessWidget {
  final bool isDark;
  final bool isCompactHeight;
  final String formTitle;
  final String formSubtitle;
  final Widget formChild;
  final Widget footerChild;
  final VoidCallback onToggleTheme;

  const _FormWorkspacePane({
    required this.isDark,
    required this.isCompactHeight,
    required this.formTitle,
    required this.formSubtitle,
    required this.formChild,
    required this.footerChild,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quiet top utility row
          Padding(
            padding: EdgeInsets.fromLTRB(32.0, isCompactHeight ? 10.0 : 18.0, 24.0, 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _AuthThemeToggleButton(
                  isDark: isDark,
                  onPressed: onToggleTheme,
                ),
              ],
            ),
          ),

          // Centered scrollable modernist form plane (no card wrapper)
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewport) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 36.0,
                    vertical: isCompactHeight ? 12.0 : 28.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (viewport.maxHeight - (isCompactHeight ? 24.0 : 56.0))
                          .clamp(0.0, double.infinity),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 384.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              formTitle,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontFamilyFallback: AppTypography.fontFallback,
                                fontSize: isCompactHeight ? 24.0 : 28.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.8,
                                height: 1.18,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              formSubtitle,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontFamilyFallback: AppTypography.fontFallback,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                                color: textSecondary,
                              ),
                            ),
                            SizedBox(height: isCompactHeight ? 20.0 : 28.0),
                            formChild,
                            SizedBox(height: isCompactHeight ? 16.0 : 24.0),
                            Container(height: 1.0, color: borderSoft),
                            SizedBox(height: isCompactHeight ? 10.0 : 14.0),
                            footerChild,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAuthLayout extends StatelessWidget {
  final bool isDark;
  final String heroHeadline;
  final String formTitle;
  final String formSubtitle;
  final Widget formChild;
  final Widget footerChild;
  final VoidCallback onToggleTheme;

  const _CompactAuthLayout({
    required this.isDark,
    required this.heroHeadline,
    required this.formTitle,
    required this.formSubtitle,
    required this.formChild,
    required this.footerChild,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath =
        isDark ? AuthModernistLayout._darkHeroAsset : AuthModernistLayout._lightHeroAsset;
    final textPrimary = AppColors.textPrimaryFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);
    final borderColor = AppColors.borderFor(isDark);
    final borderSoft = AppColors.borderSoftFor(isDark);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flexible architectural banner strip (expands safely with notch insets & text scaling)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 156.0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _ModernistArchitecturalFallback(isDark: isDark),
                ),
                Positioned.fill(
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    alignment: isDark ? const Alignment(0.35, -0.05) : const Alignment(0.0, 0.2),
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xA6101016),
                          Color(0xDC101016),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 12.0, 16.0, 20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AuthBrandMark(
                              foregroundColor: const Color(0xFFF6F6FA),
                              accentColor: AppColors.primaryLight,
                              iconSize: 18.0,
                              fontSize: 20.0,
                            ),
                            _AuthThemeToggleButton(
                              isDark: isDark,
                              onDarkOverlay: true,
                              onPressed: onToggleTheme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28.0),
                        Text(
                          heroHeadline,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontFamilyFallback: AppTypography.fontFallback,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            height: 1.2,
                            color: Color(0xFFF6F6FA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1.0, color: borderColor),

          // Open form workspace
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 28.0, 24.0, 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      formTitle,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontFamilyFallback: AppTypography.fontFallback,
                        fontSize: 24.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.7,
                        height: 1.2,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      formSubtitle,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontFamilyFallback: AppTypography.fontFallback,
                        fontSize: 13.0,
                        height: 1.5,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22.0),
                    formChild,
                    const SizedBox(height: 20.0),
                    Container(height: 1.0, color: borderSoft),
                    const SizedBox(height: 12.0),
                    footerChild,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final bool onDarkOverlay;
  final VoidCallback onPressed;

  const _AuthThemeToggleButton({
    required this.isDark,
    required this.onPressed,
    this.onDarkOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = onDarkOverlay
        ? const Color(0x8A101016)
        : AppColors.surface2For(isDark);
    final border = onDarkOverlay
        ? Colors.white.withValues(alpha: 0.26)
        : AppColors.borderFor(isDark);
    final iconColor = onDarkOverlay
        ? const Color(0xFFF6F6FA)
        : AppColors.textSecondaryFor(isDark);
    final tooltipText = isDark ? 'Switch to light mode' : 'Switch to dark mode';

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltipText,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
      ),
      icon: Container(
        width: 34.0,
        height: 34.0,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: border, width: 1.0),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          size: 17.0,
          color: iconColor,
        ),
      ),
    );
  }
}

/// Clean geometric fallback rendered behind/if the raster asset is loading or unavailable.
class _ModernistArchitecturalFallback extends StatelessWidget {
  final bool isDark;

  const _ModernistArchitecturalFallback({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArchitecturalGridPainter(
        isDark: isDark,
        upperSurface: isDark ? const Color(0xFF14151B) : const Color(0xFFE6E9F0),
        lowerPlinth: isDark ? const Color(0xFF101116) : const Color(0xFF1F242C),
        lineColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFF262333).withValues(alpha: 0.10),
        accentColor: isDark
            ? AppColors.primaryLight.withValues(alpha: 0.28)
            : AppColors.primaryDark.withValues(alpha: 0.28),
      ),
    );
  }
}

class _ArchitecturalGridPainter extends CustomPainter {
  final bool isDark;
  final Color upperSurface;
  final Color lowerPlinth;
  final Color lineColor;
  final Color accentColor;

  const _ArchitecturalGridPainter({
    required this.isDark,
    required this.upperSurface,
    required this.lowerPlinth,
    required this.lineColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = upperSurface);

    // Lower architectural shadow plinth ensures light-mode bottom headline contrast
    final plinthTop = size.height * 0.62;
    canvas.drawRect(
      Rect.fromLTRB(0, plinthTop, size.width, size.height),
      Paint()..color = lowerPlinth,
    );

    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    // Swiss asymmetric rule grid
    canvas.drawLine(
      Offset(size.width * 0.52, 0),
      Offset(size.width * 0.52, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, plinthTop),
      Offset(size.width, plinthTop),
      gridPaint,
    );

    final accentPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(size.width * 0.52, plinthTop),
      Offset(size.width, size.height * 0.22),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchitecturalGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.upperSurface != upperSurface ||
      oldDelegate.lowerPlinth != lowerPlinth ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.accentColor != accentColor;
}
