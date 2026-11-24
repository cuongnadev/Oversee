import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/auth/domain/user_model.dart';

/// Issue domain entity mapped 100% to Oversee backend `IssueResponse`.
class IssueModel extends Equatable {
  final String id;
  final String projectId;
  final int issueNumber;
  final String title;
  final String? description;
  final IssueType type;
  final IssueStatus status;
  final IssuePriority priority;
  final double? estimate;
  final double backlogRank;
  final String reporterId;
  final String? assigneeId;
  final String? parentId;
  final String? sprintId;
  final bool isBacklog;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final UserModel? assignee;
  final int subIssueCount;
  final int completedSubIssueCount;

  const IssueModel({
    required this.id,
    required this.projectId,
    required this.issueNumber,
    required this.title,
    this.description,
    this.type = IssueType.task,
    this.status = IssueStatus.backlog,
    this.priority = IssuePriority.medium,
    this.estimate,
    this.backlogRank = 0.0,
    required this.reporterId,
    this.assigneeId,
    this.parentId,
    this.sprintId,
    this.isBacklog = true,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.assignee,
    this.subIssueCount = 0,
    this.completedSubIssueCount = 0,
  });

  String formattedKey(String projectKey) => '${projectKey.toUpperCase()}-$issueNumber';

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    int subCount = 0;
    int doneSubCount = 0;
    if (json['sub_issues'] is List) {
      final list = json['sub_issues'] as List;
      subCount = list.length;
      doneSubCount = list.where((sub) {
        if (sub is Map<String, dynamic>) {
          final s = sub['status'] as String?;
          return s == 'done';
        }
        return false;
      }).length;
    }

    return IssueModel(
      id: json['id'] as String,
      projectId: (json['project_id'] as String?) ?? '',
      issueNumber: (json['issue_number'] as int?) ?? 0,
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      type: IssueType.fromString(json['type'] as String?),
      status: IssueStatus.fromString(json['status'] as String?),
      priority: IssuePriority.fromString(json['priority'] as String?),
      estimate: json['estimate'] != null ? (json['estimate'] as num).toDouble() : null,
      backlogRank: json['backlog_rank'] != null ? (json['backlog_rank'] as num).toDouble() : 0.0,
      reporterId: (json['reporter_id'] as String?) ?? '',
      assigneeId: json['assignee_id'] as String?,
      parentId: json['parent_id'] as String?,
      sprintId: json['sprint_id'] as String?,
      isBacklog: (json['is_backlog'] as bool?) ?? true,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
      assignee: json['assignee'] != null ? UserModel.fromJson(json['assignee'] as Map<String, dynamic>) : null,
      subIssueCount: subCount,
      completedSubIssueCount: doneSubCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'issue_number': issueNumber,
      'title': title,
      'description': description,
      'type': type.value,
      'status': status.value,
      'priority': priority.value,
      'estimate': estimate,
      'backlog_rank': backlogRank,
      'reporter_id': reporterId,
      'assignee_id': assigneeId,
      'parent_id': parentId,
      'sprint_id': sprintId,
      'is_backlog': isBacklog,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'assignee': assignee?.toJson(),
    };
  }

  IssueModel copyWith({
    String? id,
    String? projectId,
    int? issueNumber,
    String? title,
    String? description,
    IssueType? type,
    IssueStatus? status,
    IssuePriority? priority,
    double? estimate,
    double? backlogRank,
    String? reporterId,
    String? assigneeId,
    bool clearAssignee = false,
    String? parentId,
    String? sprintId,
    bool clearSprint = false,
    bool? isBacklog,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    UserModel? assignee,
    int? subIssueCount,
    int? completedSubIssueCount,
  }) {
    return IssueModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      issueNumber: issueNumber ?? this.issueNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      estimate: estimate ?? this.estimate,
      backlogRank: backlogRank ?? this.backlogRank,
      reporterId: reporterId ?? this.reporterId,
      assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
      parentId: parentId ?? this.parentId,
      sprintId: clearSprint ? null : (sprintId ?? this.sprintId),
      isBacklog: clearSprint ? true : (isBacklog ?? this.isBacklog),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      assignee: clearAssignee ? null : (assignee ?? this.assignee),
      subIssueCount: subIssueCount ?? this.subIssueCount,
      completedSubIssueCount: completedSubIssueCount ?? this.completedSubIssueCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        issueNumber,
        title,
        description,
        type,
        status,
        priority,
        estimate,
        backlogRank,
        reporterId,
        assigneeId,
        parentId,
        sprintId,
        isBacklog,
        startDate,
        endDate,
        createdAt,
        updatedAt,
        deletedAt,
        assignee,
        subIssueCount,
        completedSubIssueCount,
      ];
}

/// Paginated issue response mapped to Oversee backend `IssuePageResponse`.
class IssuePageModel extends Equatable {
  final List<IssueModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasMore;

  const IssuePageModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    this.hasMore = false,
  });

  factory IssuePageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((item) => IssueModel.fromJson(item as Map<String, dynamic>)).toList();

    return IssuePageModel(
      items: items,
      total: (json['total'] as int?) ?? items.length,
      page: (json['page'] as int?) ?? 1,
      pageSize: (json['page_size'] as int?) ?? 20,
      totalPages: (json['total_pages'] as int?) ?? (items.isNotEmpty ? 1 : 0),
      hasMore: (json['has_more'] as bool?) ?? false,
    );
  }

  @override
  List<Object?> get props => [items, total, page, pageSize, totalPages, hasMore];
}
