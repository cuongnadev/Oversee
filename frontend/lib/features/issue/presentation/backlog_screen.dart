import 'package:flutter/material.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';

class BacklogScreen extends StatelessWidget {
  final String workspaceId;
  final String projectId;

  const BacklogScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return ProjectScreenScaffold(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: 'backlog',
      title: 'Product Backlog',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.format_list_bulleted_rounded, size: 48, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                'Product Backlog ($projectId)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Backlog issues and prioritization view'),
            ],
          ),
        ),
      ),
    );
  }
}
