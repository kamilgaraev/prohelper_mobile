import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/error/user_message.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/domain/auth_provider.dart';
import '../../auth/data/auth_session_identity.dart';
import '../data/project_model.dart';
import '../data/projects_repository.dart';

const _projectsSentinel = Object();

// State
class ProjectsState {
  final bool isLoading;
  final bool hasLoaded;
  final List<Project> projects;
  final Project? selectedProject;
  final String? error;
  final bool fromCache;

  ProjectsState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.projects = const [],
    this.selectedProject,
    this.error,
    this.fromCache = false,
  });

  ProjectsState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    List<Project>? projects,
    Object? selectedProject = _projectsSentinel,
    Object? error = _projectsSentinel,
    bool? fromCache,
  }) {
    return ProjectsState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      projects: projects ?? this.projects,
      selectedProject:
          identical(selectedProject, _projectsSentinel)
              ? this.selectedProject
              : selectedProject as Project?,
      error:
          identical(error, _projectsSentinel) ? this.error : error as String?,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

// Provider
final projectsProvider = StateNotifierProvider<ProjectsNotifier, ProjectsState>(
  (ref) {
    ref.watch(
      authProvider.select(
        (state) => state is AuthAuthenticated ? state.sessionIdentity : null,
      ),
    );
    final auth = ref.read(authProvider);
    return ProjectsNotifier(
      ref.read(projectsRepositoryProvider),
      storage: ref.read(secureStorageProvider),
      identity: auth is AuthAuthenticated ? auth.sessionIdentity : null,
    );
  },
);

class ProjectsNotifier extends StateNotifier<ProjectsState> {
  final ProjectsRepository _repository;
  final SecureStorageService? _storage;
  final AuthSessionIdentity? _identity;
  int _loadRevision = 0;

  ProjectsNotifier(
    this._repository, {
    SecureStorageService? storage,
    AuthSessionIdentity? identity,
  }) : _storage = storage,
       _identity = identity,
       super(ProjectsState());

  Future<void> loadProjects() async {
    final revision = ++_loadRevision;
    state = state.copyWith(isLoading: true, error: null);
    int? persistedProjectId;
    try {
      persistedProjectId = await _storage?.getSelectedProjectId();
      final cached = await _storage?.getOfflineProjects();
      if (!_isCurrent(revision)) return;
      if (cached != null && cached['owner'] == _ownerKey) {
        final rows = cached['projects'];
        if (rows is List) {
          final projects = <Project>[];
          for (final row in rows) {
            if (row is! Map) continue;
            try {
              projects.add(Project.fromJson(Map<String, dynamic>.from(row)));
            } catch (_) {
              continue;
            }
          }
          state = state.copyWith(
            hasLoaded: true,
            projects: projects,
            selectedProject: _selectedFrom(projects, persistedProjectId),
            fromCache: true,
          );
        }
      }
    } catch (_) {
      if (!_isCurrent(revision)) return;
    }
    try {
      final projects = await _repository.fetchProjects();
      if (!_isCurrent(revision)) return;
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        projects: projects,
        selectedProject: _selectedFrom(projects, persistedProjectId),
        fromCache: false,
        error: null,
      );
      if (_ownerKey != null) {
        try {
          await _storage?.saveOfflineProjects({
            'owner': _ownerKey,
            'projects': [
              for (final project in projects)
                {
                  'id': project.serverId,
                  'name': project.name,
                  'address': project.address,
                  'my_role': project.myRole,
                },
            ],
          });
        } catch (_) {
          return;
        }
      }
    } catch (e) {
      if (!_isCurrent(revision)) return;
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        error:
            state.fromCache
                ? 'Нет связи. Показаны сохранённые объекты.'
                : UserMessage.fromError(e),
      );
    }
  }

  String? get _ownerKey {
    final identity = _identity;
    if (identity == null || identity.organizationId == null) return null;
    return '${identity.userId}:${identity.organizationId}:${identity.sessionId}';
  }

  bool _isCurrent(int revision) => mounted && revision == _loadRevision;

  Project? _selectedFrom(List<Project> projects, int? persistedProjectId) {
    if (projects.length == 1) return projects.first;
    final selectedId = state.selectedProject?.serverId ?? persistedProjectId;
    for (final project in projects) {
      if (project.serverId == selectedId) return project;
    }
    return null;
  }

  void selectProject(Project project) {
    state = state.copyWith(selectedProject: project);
    _storage?.saveSelectedProjectId(project.serverId);
  }

  void clearSelection() {
    state = state.copyWith(selectedProject: null);
    _storage?.clearSelectedProjectId();
  }
}
