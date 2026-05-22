import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

void main() {
  test(
    'no project selected state stays explicit for multiple projects',
    () async {
      final notifier = ProjectsNotifier(
        _ProjectsRepository([_project(1), _project(2)]),
        storage: _MemorySecureStorage(),
      );

      await notifier.loadProjects();

      expect(notifier.state.projects, hasLength(2));
      expect(notifier.state.selectedProject, isNull);
    },
  );

  test('project selection persists and restores by server id', () async {
    final storage = _MemorySecureStorage();
    final projects = [_project(1), _project(2)];
    final notifier = ProjectsNotifier(
      _ProjectsRepository(projects),
      storage: storage,
    );

    notifier.selectProject(projects.last);
    await Future<void>.delayed(Duration.zero);

    final restored = ProjectsNotifier(
      _ProjectsRepository(projects),
      storage: storage,
    );
    await restored.loadProjects();

    expect(await storage.getSelectedProjectId(), 2);
    expect(restored.state.selectedProject?.serverId, 2);
  });
}

Project _project(int id) {
  return Project()
    ..serverId = id
    ..name = 'Объект $id';
}

class _ProjectsRepository extends ProjectsRepository {
  _ProjectsRepository(this.projects) : super(Dio());

  final List<Project> projects;

  @override
  Future<List<Project>> fetchProjects() async => projects;
}

class _MemorySecureStorage extends SecureStorageService {
  int? selectedProjectId;

  @override
  Future<void> saveSelectedProjectId(int projectId) async {
    selectedProjectId = projectId;
  }

  @override
  Future<int?> getSelectedProjectId() async => selectedProjectId;

  @override
  Future<void> clearSelectedProjectId() async {
    selectedProjectId = null;
  }
}
