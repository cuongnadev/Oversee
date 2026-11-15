import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/workspace/domain/workspace_member_model.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

final Provider<WorkspaceRepository> workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return WorkspaceRepository(client);
});

/// Repository handling workspace CRUD and membership operations with Oversee backend.
class WorkspaceRepository {
  final ApiClient _client;

  WorkspaceRepository(this._client);

  /// Retrieves all workspaces where the current user is a member (`GET /api/v1/workspaces`).
  Future<List<WorkspaceModel>> getWorkspaces({String? currentUserId}) async {
    final response = await _client.get<List<dynamic>>(ApiConstants.workspaces);
    final data = response.data ?? [];
    return data
        .map((item) => WorkspaceModel.fromJson(item as Map<String, dynamic>, currentUserId: currentUserId))
        .toList();
  }

  /// Retrieves single workspace by its UUID (`GET /api/v1/workspaces/{id}`).
  Future<WorkspaceModel> getWorkspace(String workspaceId, {String? currentUserId}) async {
    final response = await _client.get<Map<String, dynamic>>('${ApiConstants.workspaces}/$workspaceId');
    return WorkspaceModel.fromJson(response.data!, currentUserId: currentUserId);
  }

  /// Creates a new workspace organization (`POST /api/v1/workspaces`).
  Future<WorkspaceModel> createWorkspace({
    required String name,
    required String slug,
    String? description,
    String? currentUserId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConstants.workspaces,
      data: {
        'name': name.trim(),
        'slug': slug.trim().toLowerCase(),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      },
    );
    return WorkspaceModel.fromJson(response.data!, currentUserId: currentUserId);
  }

  /// Updates workspace properties (`PATCH /api/v1/workspaces/{id}`).
  Future<WorkspaceModel> updateWorkspace(
    String workspaceId, {
    String? name,
    String? slug,
    String? description,
    String? currentUserId,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (slug != null) payload['slug'] = slug.trim().toLowerCase();
    if (description != null) payload['description'] = description.trim();

    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.workspaces}/$workspaceId',
      data: payload,
    );
    return WorkspaceModel.fromJson(response.data!, currentUserId: currentUserId);
  }

  /// Soft deletes a workspace (`DELETE /api/v1/workspaces/{id}`).
  Future<void> deleteWorkspace(String workspaceId) async {
    await _client.delete<void>('${ApiConstants.workspaces}/$workspaceId');
  }

  /// Retrieves members list for a workspace (`GET /api/v1/workspaces/{id}/members`).
  Future<List<WorkspaceMemberModel>> getWorkspaceMembers(String workspaceId) async {
    final response = await _client.get<List<dynamic>>('${ApiConstants.workspaces}/$workspaceId/members');
    final data = response.data ?? [];
    return data.map((item) => WorkspaceMemberModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Adds a new member to a workspace (`POST /api/v1/workspaces/{id}/members`).
  Future<WorkspaceMemberModel> addWorkspaceMember(
    String workspaceId, {
    String? userId,
    String? email,
    RoleType role = RoleType.member,
  }) async {
    final payload = <String, dynamic>{
      'role': role.value,
    };
    if (userId != null) payload['user_id'] = userId;
    if (email != null) payload['email'] = email.trim().toLowerCase();

    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.workspaces}/$workspaceId/members',
      data: payload,
    );
    return WorkspaceMemberModel.fromJson(response.data!);
  }

  /// Updates a member's role (`PATCH /api/v1/workspaces/{id}/members/{user_id}`).
  Future<WorkspaceMemberModel> updateWorkspaceMemberRole(
    String workspaceId,
    String userId,
    RoleType role,
  ) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.workspaces}/$workspaceId/members/$userId',
      data: {'role': role.value},
    );
    return WorkspaceMemberModel.fromJson(response.data!);
  }

  /// Removes a member from a workspace (`DELETE /api/v1/workspaces/{id}/members/{user_id}`).
  Future<void> removeWorkspaceMember(String workspaceId, String userId) async {
    await _client.delete<void>('${ApiConstants.workspaces}/$workspaceId/members/$userId');
  }
}
