import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/issue/domain/backlog_grouped_model.dart';
import 'package:frontend/features/issue/domain/issue_activity_model.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';

final Provider<IssueRepository> issueRepositoryProvider = Provider<IssueRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return IssueRepository(client);
});

/// Repository for Issue and Backlog operations against Oversee API backend.
class IssueRepository {
  final ApiClient _client;

  IssueRepository(this._client);

  /// Lists all non-deleted issues for a project (`GET /api/v1/projects/{project_id}/issues`).
  Future<IssuePageModel> listProjectIssues(
    String projectId, {
    int page = 1,
    int pageSize = 100,
    String? search,
    IssuePriority? priority,
    IssueType? type,
    IssueStatus? status,
    String? sort,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (priority != null) 'priority': priority.value,
      if (type != null) 'type': type.value,
      if (status != null) 'status': status.value,
    };

    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/issues',
      queryParameters: queryParams,
    );
    return IssuePageModel.fromJson(response.data!);
  }

  /// Retrieves sprint-grouped backlog overview (`GET /api/v1/projects/{project_id}/backlog/grouped`).
  Future<BacklogOverviewModel> getGroupedBacklog(
    String projectId, {
    String? search,
    IssuePriority? priority,
    IssueType? type,
  }) async {
    final queryParams = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (priority != null) 'priority': priority.value,
      if (type != null) 'type': type.value,
    };

    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/backlog/grouped',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return BacklogOverviewModel.fromJson(response.data!);
  }

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
      'sort': 'backlog_rank:asc,issue_number:asc',
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
    IssueStatus? status,
    IssuePriority priority = IssuePriority.medium,
    double? estimate,
    String? assigneeId,
    String? sprintId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'type': type.value,
      'priority': priority.value,
      if (status != null) 'status': status.value,
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (estimate != null) 'estimate': estimate,
      if (assigneeId != null && assigneeId.isNotEmpty) 'assignee_id': assigneeId,
      if (sprintId != null && sprintId.isNotEmpty) 'sprint_id': sprintId,
      if (startDate != null) 'start_date': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
    };

    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/issues',
      data: payload,
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Reorders an issue in the product backlog (`PATCH /api/v1/projects/{project_id}/backlog/reorder`).
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

    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/backlog/reorder',
      data: payload,
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Adds/moves an existing issue to the product backlog (`POST /api/v1/projects/{project_id}/backlog/issues`).
  Future<void> addIssueToBacklog(String projectId, {required String issueId}) async {
    await _client.post<dynamic>(
      '${ApiConstants.projects}/$projectId/backlog/issues',
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
    String? sprintId,
    bool clearSprint = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (type != null) 'type': type.value,
      if (status != null) 'status': status.value,
      if (priority != null) 'priority': priority.value,
      if (estimate != null) 'estimate': estimate,
      if (assigneeId != null) 'assignee_id': assigneeId,
      if (clearSprint)
        'sprint_id': null
      else if (sprintId != null)
        'sprint_id': sprintId,
      if (clearStartDate)
        'start_date': null
      else if (startDate != null)
        'start_date': startDate.toUtc().toIso8601String(),
      if (clearEndDate)
        'end_date': null
      else if (endDate != null)
        'end_date': endDate.toUtc().toIso8601String(),
    };

    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.issues}/$issueId',
      data: payload,
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Updates issue workflow status (`PATCH /api/v1/issues/{issue_id}/status`).
  Future<IssueModel> updateIssueStatus(
    String issueId, {
    required IssueStatus status,
    bool? allowOpenSubissues,
  }) async {
    final payload = <String, dynamic>{
      'status': status.value,
      if (allowOpenSubissues != null) 'allow_open_subissues': allowOpenSubissues,
    };
    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.issues}/$issueId/status',
      data: payload,
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Updates issue assignee (`PATCH /api/v1/issues/{issue_id}/assignee`).
  Future<IssueModel> updateIssueAssignee(String issueId, String? assigneeId) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.issues}/$issueId/assignee',
      data: {'assignee_id': assigneeId},
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Updates issue priority (`PATCH /api/v1/issues/{issue_id}/priority`).
  Future<IssueModel> updateIssuePriority(String issueId, IssuePriority priority) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.issues}/$issueId/priority',
      data: {'priority': priority.value},
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Lists all sub-issues of a parent issue (`GET /api/v1/issues/{issue_id}/sub-issues`).
  Future<List<IssueModel>> listSubIssues(String issueId) async {
    final response = await _client.get<List<dynamic>>(
      '${ApiConstants.issues}/$issueId/sub-issues',
    );
    return (response.data ?? [])
        .map((item) => IssueModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Creates a sub-task for a parent issue (`POST /api/v1/projects/{project_id}/issues`).
  Future<IssueModel> createSubIssue(
    String projectId,
    String parentIssueId, {
    required String title,
    IssuePriority priority = IssuePriority.medium,
    double? estimate,
    String? assigneeId,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'type': IssueType.subtask.value,
      'priority': priority.value,
      'parent_id': parentIssueId,
      if (estimate != null) 'estimate': estimate,
      if (assigneeId != null) 'assignee_id': assigneeId,
    };

    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/issues',
      data: payload,
    );
    return IssueModel.fromJson(response.data!);
  }

  /// Lists activity logs for an issue (`GET /api/v1/issues/{issue_id}/activities`).
  Future<List<IssueActivityModel>> listIssueActivities(String issueId) async {
    final response = await _client.get<List<dynamic>>(
      '${ApiConstants.issues}/$issueId/activities',
    );
    return (response.data ?? [])
        .map((item) => IssueActivityModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Soft deletes an issue (`DELETE /api/v1/issues/{issue_id}`).
  Future<void> deleteIssue(String issueId) async {
    await _client.delete<void>('${ApiConstants.issues}/$issueId');
  }
}
