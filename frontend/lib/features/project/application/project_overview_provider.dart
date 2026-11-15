import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';

/// Provider for project overview parameterized by projectId.
final AutoDisposeStateNotifierProviderFamily<ProjectOverviewNotifier, ProjectOverviewState, String>
    projectOverviewNotifierProvider =
    StateNotifierProvider.autoDispose.family<ProjectOverviewNotifier, ProjectOverviewState, String>(
        (ref, projectId) {
  final repository = ref.watch(projectRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  final currentWorkspace = ref.watch(currentWorkspaceProvider);

  final notifier = ProjectOverviewNotifier(
    projectId: projectId,
    repository: repository,
    currentUserId: authState.user?.id,
    workspaceRole: currentWorkspace?.userRole,
  );

  notifier.loadProject();
  return notifier;
});

class ProjectOverviewNotifier extends StateNotifier<ProjectOverviewState> {
  final String projectId;
  final ProjectRepository _repository;
  final String? _currentUserId;
  final RoleType? _workspaceRole;

  ProjectOverviewNotifier({
    required this.projectId,
    required ProjectRepository repository,
    String? currentUserId,
    RoleType? workspaceRole,
    ProjectOverviewState? initialState,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        _workspaceRole = workspaceRole,
        super(initialState ?? const ProjectOverviewState(isLoading: true));

  Future<void> loadProject() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final projectFuture = _repository.getProject(projectId);
      final membersFuture = _repository.listProjectMembers(projectId);

      final results = await Future.wait([projectFuture, membersFuture]);
      final project = results[0] as ProjectModel;
      final members = results[1] as List<ProjectMemberModel>;

      RoleType detectedRole = RoleType.viewer;
      // Inherit workspace owner/admin privileges if applicable
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
        clearError: true,
      );
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to load project details: $e';
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  Future<void> refresh() async {
    await loadProject();
  }
}
