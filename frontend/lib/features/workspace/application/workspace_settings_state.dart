import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/workspace/domain/workspace_member_model.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

/// State representation for Workspace Settings and Member Management.
class WorkspaceSettingsState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final bool isDeleting;
  final WorkspaceModel? workspace;
  final List<WorkspaceMemberModel> members;
  final RoleType currentUserRole;
  final String? errorMessage;
  final String? successMessage;

  const WorkspaceSettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.isDeleting = false,
    this.workspace,
    this.members = const [],
    this.currentUserRole = RoleType.viewer,
    this.errorMessage,
    this.successMessage,
  });

  bool get isOwner => currentUserRole == RoleType.owner;
  bool get isAdmin => currentUserRole == RoleType.admin || isOwner;
  bool get canManageMembers => isAdmin;
  bool get canEditWorkspace => isAdmin;
  bool get canDeleteWorkspace => isOwner;

  WorkspaceSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isDeleting,
    WorkspaceModel? Function()? workspace,
    List<WorkspaceMemberModel>? members,
    RoleType? currentUserRole,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return WorkspaceSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDeleting: isDeleting ?? this.isDeleting,
      workspace: workspace != null ? workspace() : this.workspace,
      members: members ?? this.members,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage: successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        isDeleting,
        workspace,
        members,
        currentUserRole,
        errorMessage,
        successMessage,
      ];
}
