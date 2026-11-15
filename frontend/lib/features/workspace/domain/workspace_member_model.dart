import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/auth/domain/user_model.dart';

/// Workspace member representation mapped to backend `WorkspaceMemberResponse`.
class WorkspaceMemberModel extends Equatable {
  final String id;
  final String workspaceId;
  final String userId;
  final RoleType role;
  final UserModel? user;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkspaceMemberModel({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.role,
    this.user,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkspaceMemberModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceMemberModel(
      id: json['id'] as String,
      workspaceId: (json['workspace_id'] as String?) ?? '',
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
      'workspace_id': workspaceId,
      'user_id': userId,
      'role': role.value,
      'user': user?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, workspaceId, userId, role, user, createdAt, updatedAt];
}
