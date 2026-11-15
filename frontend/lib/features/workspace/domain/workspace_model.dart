import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';

/// Workspace entity mapped to backend `WorkspaceResponse`.
class WorkspaceModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String ownerId;
  final RoleType userRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkspaceModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.ownerId,
    this.userRole = RoleType.member,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkspaceModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final ownerId = (json['owner_id'] as String?) ?? '';
    RoleType resolvedRole = RoleType.member;

    if (json['role'] != null) {
      resolvedRole = RoleType.fromString(json['role'] as String?);
    } else if (currentUserId != null && ownerId == currentUserId) {
      resolvedRole = RoleType.owner;
    }

    return WorkspaceModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      description: json['description'] as String?,
      ownerId: ownerId,
      userRole: resolvedRole,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'owner_id': ownerId,
      'role': userRole.value,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  WorkspaceModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? ownerId,
    RoleType? userRole,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkspaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      userRole: userRole ?? this.userRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, slug, description, ownerId, userRole, createdAt, updatedAt];
}
