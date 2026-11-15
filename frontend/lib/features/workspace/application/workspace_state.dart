import 'package:equatable/equatable.dart';
import 'package:frontend/features/workspace/domain/workspace_model.dart';

/// State representation for workspace list and active selection.
class WorkspaceState extends Equatable {
  final bool isLoading;
  final bool isCreating;
  final List<WorkspaceModel> workspaces;
  final WorkspaceModel? selectedWorkspace;
  final String? errorMessage;

  const WorkspaceState({
    this.isLoading = false,
    this.isCreating = false,
    this.workspaces = const [],
    this.selectedWorkspace,
    this.errorMessage,
  });

  WorkspaceState copyWith({
    bool? isLoading,
    bool? isCreating,
    List<WorkspaceModel>? workspaces,
    WorkspaceModel? Function()? selectedWorkspace,
    String? Function()? errorMessage,
  }) {
    return WorkspaceState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      workspaces: workspaces ?? this.workspaces,
      selectedWorkspace: selectedWorkspace != null ? selectedWorkspace() : this.selectedWorkspace,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, isCreating, workspaces, selectedWorkspace, errorMessage];
}
