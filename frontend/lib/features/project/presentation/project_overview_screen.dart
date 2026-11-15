import 'package:flutter/material.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';

class ProjectOverviewScreen extends StatelessWidget {
  final String workspaceId;
  final String projectId;

  const ProjectOverviewScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return ProjectScreenScaffold(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: 'overview',
      title: 'Project Overview',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.rocket_launch_outlined, size: 48, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                'Project: $projectId',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Workspace ID: $workspaceId'),
            ],
          ),
        ),
      ),
    );
  }
}
