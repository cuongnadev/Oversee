import 'package:flutter/material.dart';
import 'package:frontend/shared/layout/layout.dart';

/// Marks subtrees already wrapped in the persistent GoRouter [ResponsiveAppShell]
/// so inner screens do not duplicate the sidebar and top header on route switches.
class ProjectShellScope extends InheritedWidget {
  const ProjectShellScope({
    super.key,
    required super.child,
  });

  static bool isInsideShell(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProjectShellScope>() != null;
  }

  @override
  bool updateShouldNotify(covariant ProjectShellScope oldWidget) => false;
}

/// Responsive wrapper around all project views (Overview, Backlog, Board, Sprints, Timeline, Calendar, Issues, Dashboard, Settings).
/// When rendered inside GoRouter's persistent [ShellRoute], yields only [body] so
/// the outer sidebar and header stay static without full-page navigation animation.
class ProjectScreenScaffold extends StatelessWidget {
  final String workspaceId;
  final String projectId;
  final String currentRoute;
  final String title;
  final Widget body;

  const ProjectScreenScaffold({
    super.key,
    required this.workspaceId,
    required this.projectId,
    required this.currentRoute,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    if (ProjectShellScope.isInsideShell(context)) {
      return body;
    }
    return ResponsiveAppShell(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: currentRoute,
      title: title,
      body: body,
    );
  }
}
