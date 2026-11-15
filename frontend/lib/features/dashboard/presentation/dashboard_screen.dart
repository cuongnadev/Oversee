import 'package:flutter/material.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';

class DashboardScreen extends StatelessWidget {
  final String workspaceId;
  final String projectId;

  const DashboardScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return ProjectScreenScaffold(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: 'dashboard',
      title: 'Project Dashboard',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 48, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                'Dashboard & Burndown Chart ($projectId)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Sprint progress metrics, completion percentages and issue statistics'),
            ],
          ),
        ),
      ),
    );
  }
}
