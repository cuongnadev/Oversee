import 'package:flutter/material.dart';
import 'package:frontend/shared/layout/layout.dart';

/// Responsive wrapper around all project views (Overview, Backlog, Board, Sprints, Dashboard, Settings).
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
    return ResponsiveAppShell(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: currentRoute,
      title: title,
      body: body,
    );
  }
}
