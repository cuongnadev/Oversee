import 'package:flutter/material.dart';
import 'package:frontend/features/project/presentation/widgets/project_screen_scaffold.dart';

class KanbanBoardScreen extends StatelessWidget {
  final String workspaceId;
  final String projectId;

  const KanbanBoardScreen({
    super.key,
    required this.workspaceId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return ProjectScreenScaffold(
      workspaceId: workspaceId,
      projectId: projectId,
      currentRoute: 'board',
      title: 'Kanban Board',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.view_kanban_outlined, size: 48, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                'Kanban Board ($projectId)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Active Sprint task columns: TODO, IN_PROGRESS, IN_REVIEW, DONE'),
            ],
          ),
        ),
      ),
    );
  }
}
