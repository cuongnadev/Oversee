import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/application/backlog_provider.dart';
import 'package:frontend/features/sprint/application/kanban_board_provider.dart';
import 'package:frontend/features/sprint/application/sprint_planning_provider.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_complete_model.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';

/// State for the Sprint Overview Screen.
class SprintOverviewState extends Equatable {
  final bool isLoading;
  final bool isActionInProgress;
  final String? errorMessage;
  final String? successMessage;
  final List<SprintModel> sprints;
  final SprintProgressModel? activeSprintProgress;
  final SprintStatus? statusFilter;

  const SprintOverviewState({
    this.isLoading = false,
    this.isActionInProgress = false,
    this.errorMessage,
    this.successMessage,
    this.sprints = const [],
    this.activeSprintProgress,
    this.statusFilter,
  });

  SprintModel? get activeSprint {
    try {
      return sprints.firstWhere((s) => s.status == SprintStatus.active);
    } catch (_) {
      return null;
    }
  }

  bool get hasActiveSprint => activeSprint != null;

  List<SprintModel> get plannedSprints =>
      sprints.where((s) => s.status == SprintStatus.planned).toList();

  List<SprintModel> get completedSprints =>
      sprints.where((s) => s.status == SprintStatus.completed || s.status == SprintStatus.closed).toList();

  List<SprintModel> get filteredSprints {
    if (statusFilter == null) return sprints;
    return sprints.where((s) => s.status == statusFilter).toList();
  }

  SprintOverviewState copyWith({
    bool? isLoading,
    bool? isActionInProgress,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    List<SprintModel>? sprints,
    SprintProgressModel? activeSprintProgress,
    bool clearProgress = false,
    SprintStatus? statusFilter,
    bool clearFilter = false,
  }) {
    return SprintOverviewState(
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      sprints: sprints ?? this.sprints,
      activeSprintProgress:
          clearProgress ? null : (activeSprintProgress ?? this.activeSprintProgress),
      statusFilter: clearFilter ? null : (statusFilter ?? this.statusFilter),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isActionInProgress,
        errorMessage,
        successMessage,
        sprints,
        activeSprintProgress,
        statusFilter,
      ];
}

/// Notifier managing sprint lifecycle operations and overview metrics.
class SprintOverviewNotifier extends StateNotifier<SprintOverviewState> {
  final SprintRepository _sprintRepository;
  final Ref _ref;
  final String _projectId;

  SprintOverviewNotifier({
    required SprintRepository sprintRepository,
    required Ref ref,
    required String projectId,
  })  : _sprintRepository = sprintRepository,
        _ref = ref,
        _projectId = projectId,
        super(const SprintOverviewState()) {
    loadOverview();
  }

  /// Loads all project sprints and fetches active sprint progress if present.
  Future<void> loadOverview() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sprints = await _sprintRepository.listProjectSprints(_projectId);

      SprintModel? active;
      try {
        active = sprints.firstWhere((s) => s.status == SprintStatus.active);
      } catch (_) {
        active = null;
      }

      SprintProgressModel? progress;
      if (active != null) {
        try {
          progress = await _sprintRepository.getSprintProgress(active.id);
        } catch (_) {
          progress = null;
        }
      }

      state = state.copyWith(
        isLoading: false,
        sprints: sprints,
        activeSprintProgress: progress,
        clearProgress: progress == null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load sprints: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  void setStatusFilter(SprintStatus? filter) {
    if (state.statusFilter == filter) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(statusFilter: filter);
    }
  }

  /// Starts a planned sprint and refreshes project sprint views.
  Future<bool> startSprint(
    String sprintId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(isActionInProgress: true, clearError: true, clearSuccess: true);
    try {
      await _sprintRepository.startSprint(
        sprintId,
        startDate: startDate,
        endDate: endDate,
      );

      // Invalidate related caches
      _invalidateCaches();

      await loadOverview();
      state = state.copyWith(
        isActionInProgress: false,
        successMessage: 'Sprint started successfully! Issues are now active on your board.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionInProgress: false,
        errorMessage: 'Failed to start sprint: ${e.toString().replaceAll('Exception: ', '')}',
      );
      return false;
    }
  }

  /// Completes an active sprint with optional rollover target and returns completion metrics.
  Future<SprintCompleteModel?> completeSprint(
    String sprintId, {
    String? targetSprintId,
  }) async {
    state = state.copyWith(isActionInProgress: true, clearError: true, clearSuccess: true);
    try {
      final result = await _sprintRepository.completeSprint(
        sprintId,
        targetSprintId: targetSprintId,
      );

      // Invalidate related caches
      _invalidateCaches();

      await loadOverview();

      final rolloverNote = result.movedToBacklog
          ? '${result.incompleteIssuesCount} issue(s) moved to Backlog'
          : (result.movedToSprintId != null
              ? '${result.incompleteIssuesCount} issue(s) moved to next sprint'
              : 'All issues completed!');

      state = state.copyWith(
        isActionInProgress: false,
        successMessage:
            'Sprint "${result.sprint.name}" completed! $rolloverNote.',
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isActionInProgress: false,
        errorMessage: 'Failed to complete sprint: ${e.toString().replaceAll('Exception: ', '')}',
      );
      return null;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  void _invalidateCaches() {
    try {
      if (_ref.exists(kanbanBoardProvider(_projectId))) {
        _ref.read(kanbanBoardProvider(_projectId).notifier).refresh();
      }
      if (_ref.exists(backlogNotifierProvider(_projectId))) {
        _ref.read(backlogNotifierProvider(_projectId).notifier).refresh();
      }
      if (_ref.exists(sprintPlanningProvider(_projectId))) {
        _ref.read(sprintPlanningProvider(_projectId).notifier).refresh();
      }
    } catch (_) {
      // Safe no-op if providers are unmounted or not initialized
    }
  }
}

/// Family provider for `SprintOverviewNotifier`.
final sprintOverviewProvider = StateNotifierProvider.autoDispose
    .family<SprintOverviewNotifier, SprintOverviewState, String>((ref, projectId) {
  final sprintRepo = ref.watch(sprintRepositoryProvider);
  return SprintOverviewNotifier(
    sprintRepository: sprintRepo,
    ref: ref,
    projectId: projectId,
  );
});
