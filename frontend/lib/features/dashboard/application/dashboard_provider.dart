import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/enums/app_enums.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_progress_model.dart';

/// State of the Project Progress Dashboard.
class DashboardState extends Equatable {
  final bool isLoading;
  final String? errorMessage;
  final ProjectModel? project;
  final List<SprintModel> sprints;
  final SprintModel? selectedSprint;
  final SprintProgressModel? progress;
  final List<IssueModel> issues;

  const DashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.project,
    this.sprints = const [],
    this.selectedSprint,
    this.progress,
    this.issues = const [],
  });

  bool get hasActiveSprint =>
      selectedSprint != null && selectedSprint!.status == SprintStatus.active;

  /// Issues that are Urgent/High priority and not yet Done.
  List<IssueModel> get blockerIssues {
    return issues.where((issue) {
      final isHighPriority =
          issue.priority == IssuePriority.urgent || issue.priority == IssuePriority.high;
      return isHighPriority && issue.status != IssueStatus.done;
    }).toList();
  }

  /// Issues currently In Progress that haven't moved in 3+ days.
  List<IssueModel> get lingeringIssues {
    final now = DateTime.now();
    return issues.where((issue) {
      if (issue.status != IssueStatus.inProgress) return false;
      final refDate = issue.updatedAt ?? issue.createdAt;
      if (refDate == null) return false;
      return now.difference(refDate).inDays >= 3;
    }).toList();
  }

  /// Combined risk issues list (blockers + lingering issues, deduplicated).
  List<IssueModel> get riskIssues {
    final Map<String, IssueModel> map = {};
    for (final issue in blockerIssues) {
      map[issue.id] = issue;
    }
    for (final issue in lingeringIssues) {
      map[issue.id] = issue;
    }
    return map.values.toList();
  }

  /// Daily velocity in Story Points burned per elapsed day.
  double get burnVelocityPerDay {
    if (selectedSprint == null || selectedSprint!.startDate == null || progress == null) {
      return 0.0;
    }
    final now = DateTime.now();
    final start = selectedSprint!.startDate!;
    final elapsedDays = max(1, now.difference(start).inDays);
    final completedPoints = progress!.completedStoryPoints;
    if (completedPoints <= 0) return 0.0;
    return completedPoints / elapsedDays;
  }

  /// Estimated days remaining to complete remaining points based on velocity.
  int? get projectedDaysToCompletion {
    final velocity = burnVelocityPerDay;
    if (velocity <= 0 || progress == null) return null;
    final remainingPoints = progress!.remainingStoryPoints;
    if (remainingPoints <= 0) return 0;
    return (remainingPoints / velocity).ceil();
  }

  /// Whether the sprint is currently on schedule.
  bool get isOnTrack {
    if (selectedSprint == null || selectedSprint!.daysRemaining == null || progress == null) {
      return true;
    }
    final daysRemaining = selectedSprint!.daysRemaining!;
    final projected = projectedDaysToCompletion;
    if (projected == null) {
      // If no points completed yet but sprint has elapsed > 50%, at risk
      return daysRemaining > 3;
    }
    return projected <= daysRemaining;
  }

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    ProjectModel? project,
    List<SprintModel>? sprints,
    SprintModel? selectedSprint,
    bool clearSelectedSprint = false,
    SprintProgressModel? progress,
    bool clearProgress = false,
    List<IssueModel>? issues,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      project: project ?? this.project,
      sprints: sprints ?? this.sprints,
      selectedSprint: clearSelectedSprint ? null : (selectedSprint ?? this.selectedSprint),
      progress: clearProgress ? null : (progress ?? this.progress),
      issues: issues ?? this.issues,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        errorMessage,
        project,
        sprints,
        selectedSprint,
        progress,
        issues,
      ];
}

/// Notifier handling dashboard state, sprint progress loading and burndown calculations.
class DashboardNotifier extends StateNotifier<DashboardState> {
  final SprintRepository _sprintRepository;
  final ProjectRepository _projectRepository;
  final String _projectId;

  DashboardNotifier({
    required SprintRepository sprintRepository,
    required ProjectRepository projectRepository,
    required String projectId,
  })  : _sprintRepository = sprintRepository,
        _projectRepository = projectRepository,
        _projectId = projectId,
        super(const DashboardState()) {
    loadDashboard();
  }

  /// Loads project information, all sprints, selects the active or primary sprint, and fetches its progress & issues.
  Future<void> loadDashboard({String? targetSprintId}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _projectRepository.getProject(_projectId),
        _sprintRepository.listProjectSprints(_projectId),
      ]);

      final project = results[0] as ProjectModel;
      final sprints = results[1] as List<SprintModel>;

      SprintModel? selected;
      if (targetSprintId != null) {
        try {
          selected = sprints.firstWhere((s) => s.id == targetSprintId);
        } catch (_) {
          selected = null;
        }
      }

      // If no target specified or not found, prefer ACTIVE sprint, then PLANNED, then first available
      if (selected == null && sprints.isNotEmpty) {
        try {
          selected = sprints.firstWhere((s) => s.status == SprintStatus.active);
        } catch (_) {
          try {
            selected = sprints.firstWhere((s) => s.status == SprintStatus.planned);
          } catch (_) {
            selected = sprints.first;
          }
        }
      }

      SprintProgressModel? progress;
      List<IssueModel> issues = [];

      if (selected != null) {
        final sprintData = await Future.wait([
          _sprintRepository.getSprintProgress(selected.id).catchError((_) => SprintProgressModel(
                sprintId: selected!.id,
                sprintName: selected.name,
                status: selected.status,
                totalIssues: 0,
                completedIssues: 0,
                remainingIssues: 0,
                issueProgressPercentage: 0.0,
                totalStoryPoints: 0.0,
                completedStoryPoints: 0.0,
                remainingStoryPoints: 0.0,
                storyPointProgressPercentage: 0.0,
              )),
          _sprintRepository.getSprintIssues(selected.id).catchError((_) => <IssueModel>[]),
        ]);

        progress = sprintData[0] as SprintProgressModel;
        issues = sprintData[1] as List<IssueModel>;
      }

      state = state.copyWith(
        isLoading: false,
        project: project,
        sprints: sprints,
        selectedSprint: selected,
        clearSelectedSprint: selected == null,
        progress: progress,
        clearProgress: progress == null,
        issues: issues,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  /// Switches selected sprint and refreshes burndown and issue data.
  Future<void> selectSprint(String sprintId) async {
    await loadDashboard(targetSprintId: sprintId);
  }

  /// Refreshes dashboard data for the currently selected sprint.
  Future<void> refresh() async {
    await loadDashboard(targetSprintId: state.selectedSprint?.id);
  }

  void clearErrorMessage() {
    state = state.copyWith(clearError: true);
  }
}

/// Riverpod family provider for `DashboardNotifier`.
final dashboardProvider = StateNotifierProvider.autoDispose
    .family<DashboardNotifier, DashboardState, String>((ref, projectId) {
  final sprintRepo = ref.watch(sprintRepositoryProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);

  return DashboardNotifier(
    sprintRepository: sprintRepo,
    projectRepository: projectRepo,
    projectId: projectId,
  );
});
