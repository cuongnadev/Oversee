import 'package:flutter/material.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';

class ProjectSettingsScreen extends StatelessWidget {
  final String workspaceId;
  final String projectId;

  const ProjectSettingsScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return ProjectScreenScaffold(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: 'settings',
      title: 'Project Settings',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.settings_outlined, size: 48, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                'Project Settings ($projectId)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Update project details, members, and archive options'),
            ],
          ),
        ),
      ),
    );
  }
}
