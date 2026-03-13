import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/project_model.dart';
import '../data/projects_repository.dart';

const _projectsSentinel = Object();

// State
class ProjectsState {
  final bool isLoading;
  final List<Project> projects;
  final Project? selectedProject;
  final String? error;

  ProjectsState({
    this.isLoading = false,
    this.projects = const [],
    this.selectedProject,
    this.error,
  });

  ProjectsState copyWith({
    bool? isLoading,
    List<Project>? projects,
    Object? selectedProject = _projectsSentinel,
    Object? error = _projectsSentinel,
  }) {
    return ProjectsState(
      isLoading: isLoading ?? this.isLoading,
      projects: projects ?? this.projects,
      selectedProject: identical(selectedProject, _projectsSentinel)
          ? this.selectedProject
          : selectedProject as Project?,
      error: identical(error, _projectsSentinel) ? this.error : error as String?,
    );
  }
}

// Provider
final projectsProvider = StateNotifierProvider<ProjectsNotifier, ProjectsState>((ref) {
  ref.watch(authProvider);
  return ProjectsNotifier(ref.read(projectsRepositoryProvider));
});

class ProjectsNotifier extends StateNotifier<ProjectsState> {
  final ProjectsRepository _repository;

  ProjectsNotifier(this._repository) : super(ProjectsState());

  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final projects = await _repository.fetchProjects();
      
      Project? selected;
      if (projects.length == 1) {
        selected = projects.first;
      } else if (state.selectedProject != null) {
        final selectedServerId = state.selectedProject!.serverId;
        for (final project in projects) {
          if (project.serverId == selectedServerId) {
            selected = project;
            break;
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        projects: projects,
        selectedProject: selected,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectProject(Project project) {
    state = state.copyWith(selectedProject: project);
  }

  void clearSelection() {
    state = state.copyWith(selectedProject: null);
  }
}
