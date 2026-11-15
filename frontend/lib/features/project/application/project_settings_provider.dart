import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/project/application/project_settings_state.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';

/// Provider for project settings parameterized by projectId.
final AutoDisposeStateNotifierProviderFamily<ProjectSettingsNotifier, ProjectSettingsState, String>
    projectSettingsNotifierProvider =
    StateNotifierProvider.autoDispose.family<ProjectSettingsNotifier, ProjectSettingsState, String>(
        (ref, projectId) {
  final repository = ref.watch(projectRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  final currentWorkspace = ref.watch(currentWorkspaceProvider);

  final notifier = ProjectSettingsNotifier(
    projectId: projectId,
    repository: repository,
    currentUserId: authState.user?.id,
    workspaceRole: currentWorkspace?.userRole,
  );

  notifier.loadSettings();
  return notifier;
});

class ProjectSettingsNotifier extends StateNotifier<ProjectSettingsState> {
  final String projectId;
  final ProjectRepository _repository;
  final String? _currentUserId;
  final RoleType? _workspaceRole;

  ProjectSettingsNotifier({
    required this.projectId,
    required ProjectRepository repository,
    String? currentUserId,
    RoleType? workspaceRole,
    ProjectSettingsState? initialState,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        _workspaceRole = workspaceRole,
        super(initialState ?? const ProjectSettingsState(isLoading: true));

  Future<void> loadSettings() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: () => null,
      successMessage: () => null,
    );
    try {
      final projectFuture = _repository.getProject(projectId);
      final membersFuture = _repository.listProjectMembers(projectId);

      final results = await Future.wait([projectFuture, membersFuture]);
      final project = results[0] as ProjectModel;
      final members = results[1] as List<ProjectMemberModel>;

      RoleType detectedRole = RoleType.viewer;
      if (_workspaceRole == RoleType.owner || _workspaceRole == RoleType.admin) {
        detectedRole = _workspaceRole!;
      }

      if (_currentUserId != null) {
        final currentMember = members.where((m) => m.userId == _currentUserId).firstOrNull;
        if (currentMember != null) {
          detectedRole = currentMember.role;
        }
      }

      state = state.copyWith(
        project: project,
        members: members,
        currentUserRole: detectedRole,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to load project settings: $e';
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => message,
      );
    }
  }

  Future<bool> updateProject({
    String? name,
    String? key,
    String? description,
  }) async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: () => null,
      successMessage: () => null,
    );
    try {
      final updatedProject = await _repository.updateProject(
        projectId,
        name: name,
        key: key,
        description: description,
      );

      state = state.copyWith(
        project: updatedProject,
        isSaving: false,
        successMessage: () => 'Project updated successfully.',
      );
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to update project: $e';
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => message,
      );
      return false;
    }
  }

  Future<bool> addMember({
    String? userId,
    String? email,
    required RoleType role,
  }) async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: () => null,
      successMessage: () => null,
    );
    try {
      final newMember = await _repository.addProjectMember(
        projectId,
        userId: userId,
        email: email,
        role: role,
      );

      final updatedList = List<ProjectMemberModel>.from(state.members)..add(newMember);
      state = state.copyWith(
        members: updatedList,
        isSaving: false,
        successMessage: () => 'Member added successfully.',
      );
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to add project member: $e';
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => message,
      );
      return false;
    }
  }

  Future<bool> updateMemberRole(String userId, RoleType newRole) async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: () => null,
      successMessage: () => null,
    );
    try {
      final updatedMember = await _repository.updateProjectMemberRole(
        projectId,
        userId,
        role: newRole,
      );

      final updatedMembers = state.members.map((m) {
        return m.userId == userId ? updatedMember : m;
      }).toList();

      state = state.copyWith(
        members: updatedMembers,
        isSaving: false,
        successMessage: () => 'Member role updated successfully.',
      );
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to update role: $e';
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => message,
      );
      return false;
    }
  }

  Future<bool> removeMember(String userId) async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: () => null,
      successMessage: () => null,
    );
    try {
      await _repository.removeProjectMember(projectId, userId);

      final updatedMembers = state.members.where((m) => m.userId != userId).toList();
      state = state.copyWith(
        members: updatedMembers,
        isSaving: false,
        successMessage: () => 'Member removed successfully.',
      );
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to remove member: $e';
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => message,
      );
      return false;
    }
  }

  Future<bool> archiveProject() async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: () => null,
      successMessage: () => null,
    );
    try {
      await _repository.archiveProject(projectId);
      final current = state.project;
      if (current != null) {
        state = state.copyWith(
          project: current.copyWith(deletedAt: DateTime.now()),
          isSaving: false,
          successMessage: () => 'Project archived successfully.',
        );
      } else {
        state = state.copyWith(isSaving: false);
      }
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to archive project: $e';
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => message,
      );
      return false;
    }
  }

  Future<bool> restoreProject() async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: () => null,
      successMessage: () => null,
    );
    try {
      final restored = await _repository.restoreProject(projectId);
      state = state.copyWith(
        project: restored,
        isSaving: false,
        successMessage: () => 'Project restored successfully.',
      );
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to restore project: $e';
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => message,
      );
      return false;
    }
  }

  Future<bool> deleteProject() async {
    state = state.copyWith(
      isSaving: true,
      errorMessage: () => null,
      successMessage: () => null,
    );
    try {
      await _repository.deleteProject(projectId);
      state = state.copyWith(
        isSaving: false,
        successMessage: () => 'Project deleted permanently.',
      );
      return true;
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to delete project: $e';
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => message,
      );
      return false;
    }
  }
}
