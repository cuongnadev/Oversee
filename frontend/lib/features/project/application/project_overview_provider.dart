import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/application/project_overview_state.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_member_model.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';
import 'package:frontend/features/workspace/application/workspace_provider.dart';

/// Provider for project overview parameterized by projectId.
final AutoDisposeStateNotifierProviderFamily<ProjectOverviewNotifier, ProjectOverviewState, String>
    projectOverviewNotifierProvider =
    StateNotifierProvider.autoDispose.family<ProjectOverviewNotifier, ProjectOverviewState, String>(
        (ref, projectId) {
  final repository = ref.watch(projectRepositoryProvider);
  final sprintRepository = ref.watch(sprintRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  final currentWorkspace = ref.watch(currentWorkspaceProvider);

  final notifier = ProjectOverviewNotifier(
    projectId: projectId,
    repository: repository,
    sprintRepository: sprintRepository,
    currentUserId: authState.user?.id,
    workspaceRole: currentWorkspace?.userRole,
  );

  notifier.loadProject();
  return notifier;
});

class ProjectOverviewNotifier extends StateNotifier<ProjectOverviewState> {
  final String projectId;
  final ProjectRepository _repository;
  final SprintRepository? _sprintRepository;
  final String? _currentUserId;
  final RoleType? _workspaceRole;

  ProjectOverviewNotifier({
    required this.projectId,
    required ProjectRepository repository,
    SprintRepository? sprintRepository,
    String? currentUserId,
    RoleType? workspaceRole,
    ProjectOverviewState? initialState,
  })  : _repository = repository,
        _sprintRepository = sprintRepository,
        _currentUserId = currentUserId,
        _workspaceRole = workspaceRole,
        super(initialState ?? const ProjectOverviewState(isLoading: true));

  Future<void> loadProject() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final projectFuture = _repository.getProject(projectId);
      final membersFuture = _repository.listProjectMembers(projectId);
      final sprintsFuture = _sprintRepository != null
          ? _sprintRepository
              .listProjectSprints(projectId)
              .catchError((_) => <SprintModel>[])
          : Future.value(<SprintModel>[]);

      final results = await Future.wait([projectFuture, membersFuture, sprintsFuture]);
      final project = results[0] as ProjectModel;
      final members = results[1] as List<ProjectMemberModel>;
      final sprints = results[2] as List<SprintModel>;

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

      SprintModel? selectedSprint;
      if (sprints.isNotEmpty) {
        selectedSprint = sprints.where((s) => s.status == SprintStatus.active).firstOrNull ??
            sprints.where((s) => s.status == SprintStatus.planned).firstOrNull ??
            sprints.first;
      }

      SprintProgressModel? sprintProgress;
      List<IssueModel> sprintIssues = const [];

      if (selectedSprint != null && _sprintRepository != null) {
        final sprintDetails = await Future.wait([
          _sprintRepository
              .getSprintProgress(selectedSprint.id)
              .then<SprintProgressModel?>((p) => p)
              .catchError((_) => null),
          _sprintRepository
              .getSprintIssues(selectedSprint.id)
              .catchError((_) => <IssueModel>[]),
        ]);
        sprintProgress = sprintDetails[0] as SprintProgressModel?;
        sprintIssues = sprintDetails[1] as List<IssueModel>;
      }

      state = state.copyWith(
        project: project,
        members: members,
        currentUserRole: detectedRole,
        sprints: sprints,
        activeSprint: selectedSprint,
        clearActiveSprint: selectedSprint == null,
        sprintProgress: sprintProgress,
        clearSprintProgress: sprintProgress == null,
        sprintIssues: sprintIssues,
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
