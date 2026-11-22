import 'package:equatable/equatable.dart';

/// Domain model representing a project Document mapped to Oversee backend `DocumentResponse`.
class DocumentModel extends Equatable {
  final String id;
  final String projectId;
  final String title;
  final String? content;
  final String authorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const DocumentModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.content,
    required this.authorId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      authorId: json['author_id'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'content': content,
      'author_id': authorId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        title,
        content,
        authorId,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
