import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';

class WorkspaceSettingsScreen extends StatelessWidget {
  final String workspaceId;

  const WorkspaceSettingsScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(AppRoutes.workspaces);
          },
        ),
        title: Text('Workspace Settings ($workspaceId)'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.corporate_fare_rounded, size: 48, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                'Settings for Workspace: $workspaceId',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Manage members, RBAC roles, and workspace properties'),
            ],
          ),
        ),
      ),
    );
  }
}
