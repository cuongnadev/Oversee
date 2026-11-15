import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_planning_model.dart';

/// Sprint repository handling all HTTP interactions with Oversee Sprint API endpoints.
class SprintRepository {
  final ApiClient _client;

  SprintRepository({required ApiClient client}) : _client = client;

  /// Retrieves the currently active sprint for a project, if one exists (`GET /api/v1/projects/{project_id}/sprints?status=active`).
  Future<SprintModel?> getActiveSprint(String projectId) async {
    final response = await _client.get<List<dynamic>>(
      '${ApiConstants.projects}/$projectId/sprints',
      queryParameters: {'status': SprintStatus.active.value},
    );

    final list = response.data;
    if (list != null && list.isNotEmpty) {
      return SprintModel.fromJson(list.first as Map<String, dynamic>);
    }
    return null;
  }

  /// Lists all non-deleted sprints for a project (`GET /api/v1/projects/{project_id}/sprints`).
  Future<List<SprintModel>> listProjectSprints(
    String projectId, {
    SprintStatus? status,
  }) async {
    final queryParams = <String, dynamic>{
      if (status != null) 'status': status.value,
    };

    final response = await _client.get<List<dynamic>>(
      '${ApiConstants.projects}/$projectId/sprints',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final list = response.data;
    if (list == null) return [];
    return list.map((json) => SprintModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Retrieves all issues assigned to the specified sprint (`GET /api/v1/sprints/{sprint_id}/issues`).
  Future<List<IssueModel>> getSprintIssues(String sprintId) async {
    final response = await _client.get<List<dynamic>>(
      '${ApiConstants.sprints}/$sprintId/issues',
    );

    final list = response.data;
    if (list == null) return [];
    return list.map((json) => IssueModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Creates a new sprint under a project (`POST /api/v1/projects/{project_id}/sprints`).
  Future<SprintModel> createSprint(
    String projectId, {
    required String name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
    double? capacity,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      if (goal != null) 'goal': goal.trim(),
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
      if (capacity != null) 'capacity': capacity,
    };

    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/sprints',
      data: payload,
    );
    return SprintModel.fromJson(response.data!);
  }

  /// Starts a planned sprint (`POST /api/v1/sprints/{sprint_id}/start`).
  Future<SprintModel> startSprint(
    String sprintId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final payload = <String, dynamic>{
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
    };

    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.sprints}/$sprintId/start',
      data: payload.isNotEmpty ? payload : null,
    );
    return SprintModel.fromJson(response.data!);
  }

  /// Completes an active sprint (`POST /api/v1/sprints/{sprint_id}/complete`).
  Future<void> completeSprint(
    String sprintId, {
    String? targetSprintId,
  }) async {
    final payload = <String, dynamic>{
      if (targetSprintId != null) 'target_sprint_id': targetSprintId,
    };

    await _client.post<dynamic>(
      '${ApiConstants.sprints}/$sprintId/complete',
      data: payload.isNotEmpty ? payload : null,
    );
  }

  /// Adds issues to a sprint (`POST /api/v1/sprints/{sprint_id}/issues`).
  Future<void> addIssuesToSprint(
    String sprintId, {
    required List<String> issueIds,
  }) async {
    await _client.post<dynamic>(
      '${ApiConstants.sprints}/$sprintId/issues',
      data: {'issue_ids': issueIds},
    );
  }

  /// Assigns a single issue to a sprint (`POST /api/v1/sprints/{sprint_id}/issues/{issue_id}`).
  Future<void> addIssueToSprint(String sprintId, String issueId) async {
    await _client.post<dynamic>(
      '${ApiConstants.sprints}/$sprintId/issues/$issueId',
    );
  }

  /// Removes an issue from a sprint and returns it to backlog (`DELETE /api/v1/sprints/{sprint_id}/issues/{issue_id}`).
  Future<void> removeIssueFromSprint(String sprintId, String issueId) async {
    await _client.delete<void>(
      '${ApiConstants.sprints}/$sprintId/issues/$issueId',
    );
  }

  /// Retrieves sprint planning metrics, capacity, and warnings (`GET /api/v1/sprints/{sprint_id}/planning`).
  Future<SprintPlanningModel> getSprintPlanning(String sprintId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.sprints}/$sprintId/planning',
    );
    return SprintPlanningModel.fromJson(response.data!);
  }
}

/// Riverpod provider exposing `SprintRepository`.
final sprintRepositoryProvider = Provider<SprintRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return SprintRepository(client: client);
});
