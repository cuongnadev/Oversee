import 'package:flutter/material.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';

class SprintPlanningScreen extends StatelessWidget {
  final String workspaceId;
  final String projectId;

  const SprintPlanningScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return ProjectScreenScaffold(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: 'sprints',
      title: 'Sprint Planning',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.timer_outlined, size: 48, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                'Sprint Planning ($projectId)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Manage sprint capacity, planning summaries and backlog allocation'),
            ],
          ),
        ),
      ),
    );
  }
}
