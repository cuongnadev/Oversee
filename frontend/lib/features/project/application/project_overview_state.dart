import 'package:equatable/equatable.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';

class ProjectOverviewState extends Equatable {
  final ProjectModel? project;
  final List<ProjectMemberModel> members;
  final RoleType currentUserRole;
  final bool isLoading;
  final String? errorMessage;

  const ProjectOverviewState({
    this.project,
    this.members = const [],
    this.currentUserRole = RoleType.viewer,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isOwner => currentUserRole == RoleType.owner;
  bool get isAdmin => currentUserRole == RoleType.admin || isOwner;
  bool get canEdit => isAdmin;

  ProjectOverviewState copyWith({
    ProjectModel? project,
    List<ProjectMemberModel>? members,
    RoleType? currentUserRole,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProjectOverviewState(
      project: project ?? this.project,
      members: members ?? this.members,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [project, members, currentUserRole, isLoading, errorMessage];
}
