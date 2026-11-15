import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/project/domain/project_model.dart';

final Provider<ProjectRepository> projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ProjectRepository(client);
});

/// Repository for project operations against Oversee API backend.
class ProjectRepository {
  final ApiClient _client;

  ProjectRepository(this._client);

  /// Lists paginated projects in a workspace (`GET /api/v1/workspaces/{workspace_id}/projects`).
  Future<ProjectPageModel> listWorkspaceProjects(
    String workspaceId, {
    int page = 1,
    int pageSize = 20,
    bool includeArchived = false,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.workspaces}/$workspaceId/projects',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'include_archived': includeArchived,
      },
    );
    return ProjectPageModel.fromJson(response.data!);
  }

  /// Creates a new project under the specified workspace (`POST /api/v1/workspaces/{workspace_id}/projects`).
  Future<ProjectModel> createProject(
    String workspaceId, {
    required String name,
    required String key,
    String? description,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.workspaces}/$workspaceId/projects',
      data: {
        'name': name.trim(),
        'key': key.trim().toUpperCase(),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      },
    );
    return ProjectModel.fromJson(response.data!);
  }

  /// Retrieves single project details (`GET /api/v1/projects/{project_id}`).
  Future<ProjectModel> getProject(String projectId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId',
    );
    return ProjectModel.fromJson(response.data!);
  }

  /// Updates project properties (`PATCH /api/v1/projects/{project_id}`).
  Future<ProjectModel> updateProject(
    String projectId, {
    String? name,
    String? key,
    String? description,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (key != null) payload['key'] = key.trim().toUpperCase();
    if (description != null) payload['description'] = description.trim();

    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId',
      data: payload,
    );
    return ProjectModel.fromJson(response.data!);
  }

  /// Archives a project (`POST /api/v1/projects/{project_id}/archive`).
  Future<ProjectModel> archiveProject(String projectId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/archive',
    );
    return ProjectModel.fromJson(response.data!);
  }

  /// Restores an archived project (`POST /api/v1/projects/{project_id}/restore`).
  Future<ProjectModel> restoreProject(String projectId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/restore',
    );
    return ProjectModel.fromJson(response.data!);
  }

  /// Soft deletes a project (`DELETE /api/v1/projects/{project_id}`).
  Future<void> deleteProject(String projectId) async {
    await _client.delete<void>('${ApiConstants.projects}/$projectId');
  }
}
