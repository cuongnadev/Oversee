import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';
import 'package:frontend/features/workspace/application/workspace_settings_state.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';

/// Provider for workspace settings parameterized by workspaceId.
final AutoDisposeStateNotifierProviderFamily<WorkspaceSettingsNotifier, WorkspaceSettingsState, String>
    workspaceSettingsNotifierProvider =
    StateNotifierProvider.autoDispose.family<WorkspaceSettingsNotifier, WorkspaceSettingsState, String>(
        (ref, workspaceId) {
  final repository = ref.watch(workspaceRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  final workspaceNotifier = ref.read(workspaceNotifierProvider.notifier);

  final notifier = WorkspaceSettingsNotifier(
    workspaceId: workspaceId,
    repository: repository,
    currentUserId: authState.user?.id,
    workspaceNotifier: workspaceNotifier,
  );

  notifier.loadSettings();
  return notifier;
});

class WorkspaceSettingsNotifier extends StateNotifier<WorkspaceSettingsState> {
  final String workspaceId;
  final WorkspaceRepository _repository;
  final String? _currentUserId;
  final WorkspaceNotifier? _workspaceNotifier;

  WorkspaceSettingsNotifier({
    required this.workspaceId,
    required WorkspaceRepository repository,
    String? currentUserId,
    WorkspaceNotifier? workspaceNotifier,
    WorkspaceSettingsState? initialState,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        _workspaceNotifier = workspaceNotifier,
        super(initialState ?? const WorkspaceSettingsState(isLoading: true));

  /// Loads workspace info and members list in parallel.
  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null, successMessage: () => null);
    try {
      final workspace = await _repository.getWorkspace(workspaceId, currentUserId: _currentUserId);
      final members = await _repository.getWorkspaceMembers(workspaceId);

      RoleType detectedRole = RoleType.viewer;
      if (_currentUserId != null) {
        if (workspace.ownerId == _currentUserId) {
          detectedRole = RoleType.owner;
        } else {
          final currentMember = members.where((m) => m.userId == _currentUserId).firstOrNull;
          if (currentMember != null) {
            detectedRole = currentMember.role;
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        workspace: () => workspace,
        members: members,
        currentUserRole: detectedRole,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => _formatError(e),
      );
    }
  }

  /// Updates workspace name, slug, or description.
  Future<bool> updateWorkspace({
    required String name,
    required String slug,
    String? description,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: () => null, successMessage: () => null);
    try {
      final updated = await _repository.updateWorkspace(
        workspaceId,
        name: name,
        slug: slug,
        description: description,
        currentUserId: _currentUserId,
      );

      state = state.copyWith(
        isSaving: false,
        workspace: () => updated,
        successMessage: () => 'Workspace updated successfully.',
      );

      // Refresh global workspace list
      await _workspaceNotifier?.loadWorkspaces(preferredWorkspaceId: workspaceId);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => _formatError(e),
      );
      return false;
    }
  }

  /// Adds a new member to the workspace by email or user ID with assigned role.
  Future<bool> addMember({
    String? userId,
    String? email,
    required RoleType role,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: () => null, successMessage: () => null);
    try {
      await _repository.addWorkspaceMember(
        workspaceId,
        userId: userId,
        email: email,
        role: role,
      );

      // Reload members list
      final members = await _repository.getWorkspaceMembers(workspaceId);
      state = state.copyWith(
        isSaving: false,
        members: members,
        successMessage: () => 'Member added successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => _formatError(e),
      );
      return false;
    }
  }

  /// Updates an existing member's role.
  Future<bool> updateMemberRole(String userId, RoleType role) async {
    state = state.copyWith(isSaving: true, errorMessage: () => null, successMessage: () => null);
    try {
      await _repository.updateWorkspaceMemberRole(workspaceId, userId, role);

      // Reload members
      final members = await _repository.getWorkspaceMembers(workspaceId);
      state = state.copyWith(
        isSaving: false,
        members: members,
        successMessage: () => 'Member role updated.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => _formatError(e),
      );
      return false;
    }
  }

  /// Removes a member from the workspace (or leaves workspace).
  Future<bool> removeMember(String userId) async {
    state = state.copyWith(isSaving: true, errorMessage: () => null, successMessage: () => null);
    try {
      await _repository.removeWorkspaceMember(workspaceId, userId);

      final members = await _repository.getWorkspaceMembers(workspaceId);
      state = state.copyWith(
        isSaving: false,
        members: members,
        successMessage: () => 'Member removed successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => _formatError(e),
      );
      return false;
    }
  }

  /// Soft deletes the workspace organization (Owner only).
  Future<bool> deleteWorkspace() async {
    state = state.copyWith(isDeleting: true, errorMessage: () => null, successMessage: () => null);
    try {
      await _repository.deleteWorkspace(workspaceId);
      state = state.copyWith(isDeleting: false);
      await _workspaceNotifier?.loadWorkspaces();
      return true;
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: () => _formatError(e),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(
      errorMessage: () => null,
      successMessage: () => null,
    );
  }

  String _formatError(dynamic error) {
    if (error is AppException) return error.message;
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
