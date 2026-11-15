import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/storage/preferences_service.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/application/auth_state.dart';
import 'package:frontend/features/workspace/application/workspace_state.dart';
import 'package:frontend/features/workspace/data/workspace_repository.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

/// Active selected workspace provider for consumption across all screens and widgets.
final Provider<WorkspaceModel?> currentWorkspaceProvider = Provider<WorkspaceModel?>((ref) {
  return ref.watch(workspaceNotifierProvider.select((s) => s.selectedWorkspace));
});

/// List of all workspaces the authenticated user belongs to.
final Provider<List<WorkspaceModel>> workspaceListProvider = Provider<List<WorkspaceModel>>((ref) {
  return ref.watch(workspaceNotifierProvider.select((s) => s.workspaces));
});

/// Workspace StateNotifier managing workspace fetching, switching, creation, and persistent caching.
final StateNotifierProvider<WorkspaceNotifier, WorkspaceState> workspaceNotifierProvider =
    StateNotifierProvider<WorkspaceNotifier, WorkspaceState>((ref) {
  final repository = ref.watch(workspaceRepositoryProvider);
  final prefsService = ref.watch(preferencesServiceProvider);
  final authState = ref.watch(authNotifierProvider);

  final notifier = WorkspaceNotifier(
    repository: repository,
    prefsService: prefsService,
    currentUserId: authState.user?.id,
  );

  // Auto-load workspaces if authenticated
  if (authState.status == AuthStatus.authenticated) {
    notifier.loadWorkspaces();
  }

  return notifier;
});

class WorkspaceNotifier extends StateNotifier<WorkspaceState> {
  final WorkspaceRepository _repository;
  final PreferencesService _prefsService;
  final String? _currentUserId;

  WorkspaceNotifier({
    required WorkspaceRepository repository,
    required PreferencesService prefsService,
    String? currentUserId,
    WorkspaceState? initialState,
  })  : _repository = repository,
        _prefsService = prefsService,
        _currentUserId = currentUserId,
        super(initialState ?? const WorkspaceState());

  /// Loads workspaces from backend, restores last workspace preference, and sets active selection.
  Future<void> loadWorkspaces({String? preferredWorkspaceId}) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final workspaces = await _repository.getWorkspaces(currentUserId: _currentUserId);

      WorkspaceModel? activeWorkspace;

      if (workspaces.isNotEmpty) {
        // Priority 1: explicitly passed preferredWorkspaceId
        if (preferredWorkspaceId != null) {
          activeWorkspace = workspaces.where((w) => w.id == preferredWorkspaceId).firstOrNull;
        }

        // Priority 2: previously saved workspace ID from SharedPreferences
        if (activeWorkspace == null) {
          final lastId = await _prefsService.getLastWorkspaceId();
          if (lastId != null) {
            activeWorkspace = workspaces.where((w) => w.id == lastId).firstOrNull;
          }
        }

        // Priority 3: first available workspace
        activeWorkspace ??= workspaces.first;

        // Persist the active workspace ID
        await _prefsService.saveLastWorkspaceId(activeWorkspace.id);
      }

      state = state.copyWith(
        isLoading: false,
        workspaces: workspaces,
        selectedWorkspace: () => activeWorkspace,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString(),
      );
    }
  }

  /// Switches active workspace, updates state, and stores the new ID in SharedPreferences.
  Future<void> selectWorkspace(String workspaceId) async {
    final match = state.workspaces.where((w) => w.id == workspaceId).firstOrNull;
    if (match != null) {
      state = state.copyWith(selectedWorkspace: () => match);
      await _prefsService.saveLastWorkspaceId(workspaceId);
    }
  }

  /// Creates a new workspace organization, selects it as active, and adds it to list.
  Future<WorkspaceModel?> createWorkspace({
    required String name,
    required String slug,
    String? description,
  }) async {
    state = state.copyWith(isCreating: true, errorMessage: () => null);
    try {
      final created = await _repository.createWorkspace(
        name: name,
        slug: slug,
        description: description,
        currentUserId: _currentUserId,
      );

      final updatedList = [created, ...state.workspaces];
      state = state.copyWith(
        isCreating: false,
        workspaces: updatedList,
        selectedWorkspace: () => created,
      );

      await _prefsService.saveLastWorkspaceId(created.id);
      return created;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: () => e.toString(),
      );
      return null;
    }
  }
}
