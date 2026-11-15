import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/project/application/project_list_state.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';

/// Provider for workspace project list family parameterized by workspaceId.
final AutoDisposeStateNotifierProviderFamily<ProjectListNotifier, ProjectListState, String>
    projectListNotifierProvider =
    StateNotifierProvider.autoDispose.family<ProjectListNotifier, ProjectListState, String>((ref, workspaceId) {
  final repository = ref.watch(projectRepositoryProvider);
  final notifier = ProjectListNotifier(workspaceId: workspaceId, repository: repository);
  notifier.loadProjects();
  return notifier;
});

class ProjectListNotifier extends StateNotifier<ProjectListState> {
  final String workspaceId;
  final ProjectRepository _repository;

  ProjectListNotifier({
    required this.workspaceId,
    required ProjectRepository repository,
    ProjectListState? initialState,
  })  : _repository = repository,
        super(initialState ?? const ProjectListState(isLoading: true));

  /// Loads projects for the current workspace with pagination.
  Future<void> loadProjects({int page = 1}) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final pageModel = await _repository.listWorkspaceProjects(
        workspaceId,
        page: page,
        pageSize: state.pageSize,
      );

      state = state.copyWith(
        isLoading: false,
        projects: pageModel.items,
        total: pageModel.total,
        page: pageModel.page,
        pageSize: pageModel.pageSize,
        totalPages: pageModel.totalPages,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => _formatError(e),
      );
    }
  }

  /// Creates a new project in the workspace and immediately updates list.
  Future<ProjectModel?> createProject({
    required String name,
    required String key,
    String? description,
  }) async {
    state = state.copyWith(isCreating: true, errorMessage: () => null);
    try {
      final created = await _repository.createProject(
        workspaceId,
        name: name,
        key: key,
        description: description,
      );

      final updatedProjects = [created, ...state.projects];
      state = state.copyWith(
        isCreating: false,
        projects: updatedProjects,
        total: state.total + 1,
      );
      return created;
    } catch (e) {
      final msg = _formatError(e);
      state = state.copyWith(
        isCreating: false,
        errorMessage: () => msg,
      );
      return null;
    }
  }

  /// Updates local filter search query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  String _formatError(dynamic error) {
    if (error is ConflictException) {
      return error.message;
    }
    if (error is AppException) {
      return error.message;
    }
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
