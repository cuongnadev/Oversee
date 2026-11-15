import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/auth/domain/user_model.dart';

/// Project member entity mapped to Oversee backend `ProjectMemberResponse`.
class ProjectMemberModel extends Equatable {
  final String id;
  final String projectId;
  final String userId;
  final RoleType role;
  final UserModel? user;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProjectMemberModel({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.role,
    this.user,
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      id: json['id'] as String,
      projectId: (json['project_id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      role: RoleType.fromString(json['role'] as String?),
      user: json['user'] != null ? UserModel.fromJson(json['user'] as Map<String, dynamic>) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'user_id': userId,
      'role': role.value,
      'user': user?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ProjectMemberModel copyWith({
    String? id,
    String? projectId,
    String? userId,
    RoleType? role,
    UserModel? user,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectMemberModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      user: user ?? this.user,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, projectId, userId, role, user, createdAt, updatedAt];
}
