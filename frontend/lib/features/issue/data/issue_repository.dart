import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';

final Provider<IssueRepository> issueRepositoryProvider = Provider<IssueRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return IssueRepository(client);
});

/// Repository for Issue and Backlog operations against Oversee API backend.
class IssueRepository {
  final ApiClient _client;

  IssueRepository(this._client);

  /// Lists active product backlog issues for a project (`GET /api/v1/projects/{project_id}/backlog`).
  Future<IssuePageModel> listBacklogIssues(
    String projectId, {
    int page = 1,
    int pageSize = 100,
    String? search,
    IssuePriority? priority,
    IssueType? type,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'sort_by': 'backlog_rank:asc,issue_number:asc',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (priority != null) 'priority': priority.value,
      if (type != null) 'type': type.value,
    };

    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/backlog',
      queryParameters: queryParams,
    );
    return IssuePageModel.fromJson(response.data!);
  }

  /// Creates a new issue in the project (`POST /api/v1/projects/{project_id}/issues`).
  Future<IssueModel> createIssue(
    String projectId, {
    required String title,
    String? description,
    IssueType type = IssueType.task,
    IssuePriority priority = IssuePriority.medium,
    double? estimate,
    String? assigneeId,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'type': type.value,
      'priority': priority.value,
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (estimate != null) 'estimate': estimate,
      if (assigneeId != null) 'assignee_id': assigneeId,
    };

    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/issues',
      data: payload,
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Reorders an issue in the product backlog (`POST /api/v1/projects/{project_id}/backlog/reorder`).
  Future<IssueModel> reorderBacklog(
    String projectId, {
    required String issueId,
    String? previousIssueId,
    String? nextIssueId,
    double? targetRank,
    String? position,
  }) async {
    final payload = <String, dynamic>{
      'issue_id': issueId,
      if (previousIssueId != null) 'previous_issue_id': previousIssueId,
      if (nextIssueId != null) 'next_issue_id': nextIssueId,
      if (targetRank != null) 'target_rank': targetRank,
      if (position != null) 'position': position,
    };

    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/backlog/reorder',
      data: payload,
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Adds/moves an existing issue to the product backlog (`POST /api/v1/projects/{project_id}/backlog/add`).
  Future<void> addIssueToBacklog(String projectId, {required String issueId}) async {
    await _client.post<dynamic>(
      '${ApiConstants.projects}/$projectId/backlog/add',
      data: {'issue_id': issueId},
    );
  }

  /// Retrieves single issue details (`GET /api/v1/issues/{issue_id}`).
  Future<IssueModel> getIssue(String issueId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.issues}/$issueId',
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Updates issue attributes (`PATCH /api/v1/issues/{issue_id}`).
  Future<IssueModel> updateIssue(
    String issueId, {
    String? title,
    String? description,
    IssueType? type,
    IssueStatus? status,
    IssuePriority? priority,
    double? estimate,
    String? assigneeId,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (type != null) 'type': type.value,
      if (status != null) 'status': status.value,
      if (priority != null) 'priority': priority.value,
      if (estimate != null) 'estimate': estimate,
      if (assigneeId != null) 'assignee_id': assigneeId,
    };

    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.issues}/$issueId',
      data: payload,
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Soft deletes an issue (`DELETE /api/v1/issues/{issue_id}`).
  Future<void> deleteIssue(String issueId) async {
    await _client.delete<void>('${ApiConstants.issues}/$issueId');
  }
}
