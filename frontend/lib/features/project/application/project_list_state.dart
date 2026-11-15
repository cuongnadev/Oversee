import 'package:equatable/equatable.dart';
import 'package:frontend/features/project/domain/project_model.dart';

/// State representation for projects listing in a workspace.
class ProjectListState extends Equatable {
  final bool isLoading;
  final bool isCreating;
  final List<ProjectModel> projects;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final String searchQuery;
  final String? errorMessage;

  const ProjectListState({
    this.isLoading = false,
    this.isCreating = false,
    this.projects = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.totalPages = 0,
    this.searchQuery = '',
    this.errorMessage,
  });

  List<ProjectModel> get filteredProjects {
    if (searchQuery.trim().isEmpty) return projects;
    final q = searchQuery.trim().toLowerCase();
    return projects.where((p) => p.name.toLowerCase().contains(q) || p.key.toLowerCase().contains(q)).toList();
  }

  ProjectListState copyWith({
    bool? isLoading,
    bool? isCreating,
    List<ProjectModel>? projects,
    int? total,
    int? page,
    int? pageSize,
    int? totalPages,
    String? searchQuery,
    String? Function()? errorMessage,
  }) {
    return ProjectListState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      projects: projects ?? this.projects,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isCreating,
        projects,
        total,
        page,
        pageSize,
        totalPages,
        searchQuery,
        errorMessage,
      ];
}
