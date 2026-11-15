import 'package:equatable/equatable.dart';

/// Project domain entity mapped to Oversee backend `ProjectResponse`.
class ProjectModel extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String key;
  final String? description;
  final int memberCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const ProjectModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.key,
    this.description,
    this.memberCount = 1,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isArchived => deletedAt != null;

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      workspaceId: (json['workspace_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      description: json['description'] as String?,
      memberCount: (json['member_count'] as int?) ?? 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'name': name,
      'key': key,
      'description': description,
      'member_count': memberCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  ProjectModel copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? key,
    String? description,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      key: key ?? this.key,
      description: description ?? this.description,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [id, workspaceId, name, key, description, memberCount, createdAt, updatedAt, deletedAt];
}

/// Paginated project list mapped to backend `ProjectPageResponse`.
class ProjectPageModel extends Equatable {
  final List<ProjectModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const ProjectPageModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory ProjectPageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((item) => ProjectModel.fromJson(item as Map<String, dynamic>)).toList();

    return ProjectPageModel(
      items: items,
      total: (json['total'] as int?) ?? items.length,
      page: (json['page'] as int?) ?? 1,
      pageSize: (json['page_size'] as int?) ?? 20,
      totalPages: (json['total_pages'] as int?) ?? (items.isNotEmpty ? 1 : 0),
    );
  }

  @override
  List<Object?> get props => [items, total, page, pageSize, totalPages];
}
