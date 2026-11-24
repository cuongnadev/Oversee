import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/font_scale_provider.dart';
import 'package:frontend/shared/layout/app_header.dart';
import 'package:frontend/shared/layout/desktop_sidebar.dart';
import 'package:frontend/shared/layout/mobile_nav.dart';
import 'package:frontend/shared/layout/tablet_nav_rail.dart';

/// Responsive App Shell Scaffold adapting across Mobile, Tablet, and Desktop.
class ResponsiveAppShell extends ConsumerStatefulWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;
  final String title;
  final Widget body;

  const ResponsiveAppShell({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
    required this.title,
    required this.body,
  });

  @override
  ConsumerState<ResponsiveAppShell> createState() => _ResponsiveAppShellState();
}

class _ResponsiveAppShellState extends ConsumerState<ResponsiveAppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _scaledContent(BuildContext context, double effectiveContentScale) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(effectiveContentScale),
      ),
      child: widget.body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final fontScale = ref.watch(fontScaleProvider);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool isMobile = width < AppConstants.mobileBreakpoint;
        final bool isTablet = width >= AppConstants.mobileBreakpoint && width < AppConstants.tabletBreakpoint;
        final scaledBody = _scaledContent(context, fontScale.effectiveContentScale);

        // Mobile Layout (< 600px)
        if (isMobile) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: bgColor,
            drawer: MobileAppDrawer(
              workspaceId: widget.workspaceId,
              projectId: widget.projectId,
              currentRoute: widget.currentRoute,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  AppHeader(
                    workspaceId: widget.workspaceId,
                    projectId: widget.projectId,
                    currentViewTitle: widget.title,
                    onMenuToggle: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: scaledBody,
                  ),
                ],
              ),
            ),
            bottomNavigationBar: MobileBottomNav(
              workspaceId: widget.workspaceId,
              projectId: widget.projectId,
              currentRoute: widget.currentRoute,
              onOpenMore: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          );
        }

        // Tablet Layout (600px - 1024px)
        if (isTablet) {
          return Scaffold(
            backgroundColor: bgColor,
            body: Row(
              children: [
                TabletNavRail(
                  workspaceId: widget.workspaceId,
                  projectId: widget.projectId,
                  currentRoute: widget.currentRoute,
                ),
                Expanded(
                  child: Column(
                    children: [
                      AppHeader(
                        workspaceId: widget.workspaceId,
                        projectId: widget.projectId,
                        currentViewTitle: widget.title,
                      ),
                      Expanded(
                        child: scaledBody,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Desktop / Wide Web Layout (> 1024px)
        return Scaffold(
          backgroundColor: bgColor,
          body: Row(
            children: [
              DesktopSidebar(
                workspaceId: widget.workspaceId,
                projectId: widget.projectId,
                currentRoute: widget.currentRoute,
              ),
              Expanded(
                child: Column(
                  children: [
                    AppHeader(
                      workspaceId: widget.workspaceId,
                      projectId: widget.projectId,
                      currentViewTitle: widget.title,
                    ),
                    Expanded(
                      child: scaledBody,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
