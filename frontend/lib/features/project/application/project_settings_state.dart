import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';

class ProjectSettingsState extends Equatable {
  final ProjectModel? project;
  final List<ProjectMemberModel> members;
  final RoleType currentUserRole;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const ProjectSettingsState({
    this.project,
    this.members = const [],
    this.currentUserRole = RoleType.viewer,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  bool get isOwner => currentUserRole == RoleType.owner;
  bool get isAdmin => currentUserRole == RoleType.admin || isOwner;
  bool get canManageMembers => isAdmin;
  bool get canEditSettings => isAdmin;
  bool get canDeleteProject => isOwner;

  ProjectSettingsState copyWith({
    ProjectModel? project,
    List<ProjectMemberModel>? members,
    RoleType? currentUserRole,
    bool? isLoading,
    bool? isSaving,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return ProjectSettingsState(
      project: project ?? this.project,
      members: members ?? this.members,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage: successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        project,
        members,
        currentUserRole,
        isLoading,
        isSaving,
        errorMessage,
        successMessage,
      ];
}
