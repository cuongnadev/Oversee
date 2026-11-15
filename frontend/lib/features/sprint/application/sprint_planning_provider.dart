import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/errors/app_exception.dart';
import 'package:frontend/features/issue/data/issue_repository.dart';
import 'package:frontend/features/issue/domain/issue_model.dart';
import 'package:frontend/features/project/data/project_repository.dart';
import 'package:frontend/features/project/domain/project_model.dart';
import 'package:frontend/features/sprint/data/sprint_repository.dart';
import 'package:frontend/features/sprint/domain/sprint_model.dart';
import 'package:frontend/features/sprint/domain/sprint_planning_model.dart';

/// State object representing the Sprint Planning interface.
class SprintPlanningState extends Equatable {
  final ProjectModel? project;
  final List<IssueModel> backlogIssues;
  final List<SprintModel> sprints;
  final Map<String, SprintPlanningModel> planningSummaries;
  final bool isLoading;
  final bool isReallocating;
  final bool isCreatingSprint;
  final String? errorMessage;
  final String searchQuery;

  const SprintPlanningState({
    this.project,
    this.backlogIssues = const [],
    this.sprints = const [],
    this.planningSummaries = const {},
    this.isLoading = false,
    this.isReallocating = false,
    this.isCreatingSprint = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  /// Total story points in the backlog.
  double get totalBacklogStoryPoints =>
      backlogIssues.fold(0.0, (sum, i) => sum + (i.estimate ?? 0.0));

  /// Filtered backlog issues matching the search query.
  List<IssueModel> get filteredBacklogIssues {
    if (searchQuery.trim().isEmpty) return backlogIssues;
    final q = searchQuery.toLowerCase().trim();
    final pKey = (project?.key ?? '').toLowerCase();
    return backlogIssues.where((issue) {
      final keyMatch = '$pKey-${issue.issueNumber}'.toLowerCase().contains(q);
      final titleMatch = issue.title.toLowerCase().contains(q);
      return keyMatch || titleMatch;
    }).toList();
  }

  SprintPlanningState copyWith({
    ProjectModel? project,
    List<IssueModel>? backlogIssues,
    List<SprintModel>? sprints,
    Map<String, SprintPlanningModel>? planningSummaries,
    bool? isLoading,
    bool? isReallocating,
    bool? isCreatingSprint,
    String? Function()? errorMessage,
    String? searchQuery,
  }) {
    return SprintPlanningState(
      project: project ?? this.project,
      backlogIssues: backlogIssues ?? this.backlogIssues,
      sprints: sprints ?? this.sprints,
      planningSummaries: planningSummaries ?? this.planningSummaries,
      isLoading: isLoading ?? this.isLoading,
      isReallocating: isReallocating ?? this.isReallocating,
      isCreatingSprint: isCreatingSprint ?? this.isCreatingSprint,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        project,
        backlogIssues,
        sprints,
        planningSummaries,
        isLoading,
        isReallocating,
        isCreatingSprint,
        errorMessage,
        searchQuery,
      ];
}

class SprintPlanningNotifier extends StateNotifier<SprintPlanningState> {
  final String projectId;
  final SprintRepository _sprintRepository;
  final IssueRepository _issueRepository;
  final ProjectRepository _projectRepository;

  SprintPlanningNotifier({
    required this.projectId,
    required SprintRepository sprintRepository,
    required IssueRepository issueRepository,
    required ProjectRepository projectRepository,
    SprintPlanningState? initialState,
  })  : _sprintRepository = sprintRepository,
        _issueRepository = issueRepository,
        _projectRepository = projectRepository,
        super(initialState ?? const SprintPlanningState(isLoading: true));

  Future<void> loadPlanningData() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final projectFuture = _projectRepository.getProject(projectId);
      final backlogFuture = _issueRepository.listBacklogIssues(projectId, pageSize: 100);
      final sprintsFuture = _sprintRepository.listProjectSprints(projectId);

      final results = await Future.wait([projectFuture, backlogFuture, sprintsFuture]);
      final project = results[0] as ProjectModel;
      final backlogPage = results[1] as IssuePageModel;
      final allSprints = results[2] as List<SprintModel>;

      // Filter to planned and active sprints for planning view
      final relevantSprints = allSprints.where((s) => !s.isCompleted && !s.isClosed).toList();

      // Load planning summaries for each sprint concurrently
      final Map<String, SprintPlanningModel> summaries = {};
      final summaryFutures = relevantSprints.map((s) async {
        try {
          final summary = await _sprintRepository.getSprintPlanning(s.id);
          summaries[s.id] = summary;
        } catch (_) {
          // If summary fails, construct default summary from sprint
          summaries[s.id] = SprintPlanningModel(
            sprint: s,
            capacity: s.capacity,
          );
        }
      });
      await Future.wait(summaryFutures);

      state = state.copyWith(
        project: project,
        backlogIssues: List.from(backlogPage.items),
        sprints: relevantSprints,
        planningSummaries: summaries,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => msg,
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> assignIssueToSprint(String sprintId, IssueModel issue) async {
    final prevBacklog = List<IssueModel>.from(state.backlogIssues);
    final prevSummaries = Map<String, SprintPlanningModel>.from(state.planningSummaries);

    // Optimistic UI update
    final newBacklog = List<IssueModel>.from(state.backlogIssues)
      ..removeWhere((i) => i.id == issue.id);

    final currentSummary = state.planningSummaries[sprintId];
    if (currentSummary == null) return false;

    final updatedIssues = List<IssueModel>.from(currentSummary.issues)..add(issue.copyWith(sprintId: sprintId));
    final newTotalEstimate = updatedIssues.fold(0.0, (sum, i) => sum + (i.estimate ?? 0.0));
    final isOver = currentSummary.capacity != null && newTotalEstimate > currentSummary.capacity!;
    final warning = isOver
        ? 'Sprint estimate ($newTotalEstimate pts) exceeds planned capacity (${currentSummary.capacity} pts).'
        : null;

    final newSummary = currentSummary.copyWith(
      issues: updatedIssues,
      totalIssues: updatedIssues.length,
      totalEstimate: newTotalEstimate,
      isOverCapacity: isOver,
      warning: warning,
    );

    final newSummaries = Map<String, SprintPlanningModel>.from(state.planningSummaries);
    newSummaries[sprintId] = newSummary;

    state = state.copyWith(
      backlogIssues: newBacklog,
      planningSummaries: newSummaries,
      isReallocating: true,
      errorMessage: () => null,
    );

    try {
      await _sprintRepository.addIssueToSprint(sprintId, issue.id);
      state = state.copyWith(isReallocating: false);
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        backlogIssues: prevBacklog,
        planningSummaries: prevSummaries,
        isReallocating: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<bool> removeIssueFromSprint(String sprintId, IssueModel issue) async {
    final prevBacklog = List<IssueModel>.from(state.backlogIssues);
    final prevSummaries = Map<String, SprintPlanningModel>.from(state.planningSummaries);

    final currentSummary = state.planningSummaries[sprintId];
    if (currentSummary == null) return false;

    // Optimistic update
    final updatedSprintIssues = List<IssueModel>.from(currentSummary.issues)
      ..removeWhere((i) => i.id == issue.id);
    final newTotalEstimate = updatedSprintIssues.fold(0.0, (sum, i) => sum + (i.estimate ?? 0.0));
    final isOver = currentSummary.capacity != null && newTotalEstimate > currentSummary.capacity!;
    final warning = isOver
        ? 'Sprint estimate ($newTotalEstimate pts) exceeds planned capacity (${currentSummary.capacity} pts).'
        : null;

    final newSummary = currentSummary.copyWith(
      issues: updatedSprintIssues,
      totalIssues: updatedSprintIssues.length,
      totalEstimate: newTotalEstimate,
      isOverCapacity: isOver,
      warning: warning,
    );

    final newSummaries = Map<String, SprintPlanningModel>.from(state.planningSummaries);
    newSummaries[sprintId] = newSummary;

    final updatedBacklog = List<IssueModel>.from(state.backlogIssues)
      ..add(issue.copyWith(sprintId: null));

    state = state.copyWith(
      backlogIssues: updatedBacklog,
      planningSummaries: newSummaries,
      isReallocating: true,
      errorMessage: () => null,
    );

    try {
      await _sprintRepository.removeIssueFromSprint(sprintId, issue.id);
      state = state.copyWith(isReallocating: false);
      return true;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        backlogIssues: prevBacklog,
        planningSummaries: prevSummaries,
        isReallocating: false,
        errorMessage: () => msg,
      );
      return false;
    }
  }

  Future<SprintModel?> createSprint({
    required String name,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
    double? capacity,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    state = state.copyWith(isCreatingSprint: true, errorMessage: () => null);

    try {
      final createdSprint = await _sprintRepository.createSprint(
        projectId,
        name: trimmedName,
        goal: goal,
        startDate: startDate,
        endDate: endDate,
        capacity: capacity,
      );

      final updatedSprints = List<SprintModel>.from(state.sprints)..add(createdSprint);
      final updatedSummaries = Map<String, SprintPlanningModel>.from(state.planningSummaries);
      updatedSummaries[createdSprint.id] = SprintPlanningModel(
        sprint: createdSprint,
        capacity: capacity,
      );

      state = state.copyWith(
        sprints: updatedSprints,
        planningSummaries: updatedSummaries,
        isCreatingSprint: false,
        errorMessage: () => null,
      );
      return createdSprint;
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      state = state.copyWith(
        isCreatingSprint: false,
        errorMessage: () => msg,
      );
      return null;
    }
  }

  Future<void> refresh() async {
    await loadPlanningData();
  }
}

/// Family provider for sprint planning keyed by projectId.
final sprintPlanningProvider = StateNotifierProvider.autoDispose
    .family<SprintPlanningNotifier, SprintPlanningState, String>(
  (ref, projectId) {
    final sprintRepo = ref.watch(sprintRepositoryProvider);
    final issueRepo = ref.watch(issueRepositoryProvider);
    final projectRepo = ref.watch(projectRepositoryProvider);

    final notifier = SprintPlanningNotifier(
      projectId: projectId,
      sprintRepository: sprintRepo,
      issueRepository: issueRepo,
      projectRepository: projectRepo,
    );
    notifier.loadPlanningData();
    return notifier;
  },
);
