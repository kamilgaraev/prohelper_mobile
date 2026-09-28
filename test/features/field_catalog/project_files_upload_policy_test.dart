import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/field_catalog_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/presentation/project_files_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

void main() {
  testWidgets('project file document picker sends only backend formats', (
    tester,
  ) async {
    final originalPlatform = FilePickerPlatform.instance;
    final fakePicker = _FakeFilePickerPlatform();
    FilePickerPlatform.instance = fakePicker;
    addTearDown(() => FilePickerPlatform.instance = originalPlatform);

    final project =
        Project()
          ..serverId = 52
          ..name = 'Тестовый';
    final notifier = ProjectsNotifier(ProjectsRepository(Dio()));
    notifier.selectProject(project);
    final container = ProviderContainer(
      overrides: [
        projectsProvider.overrideWith((ref) => notifier),
        fieldCatalogRepositoryProvider.overrideWithValue(_CatalogRepository()),
        permissionServiceProvider.overrideWithValue(
          PermissionService(
            context: UserContext.office,
            activeModules: const {},
            grantedPermissions: const {'projects.upload_photos'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProjectFilesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Загрузить фото или документ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Объект: Тестовый'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать документ'));
    await tester.pumpAndSettle();

    expect(fakePicker.type, FileType.custom);
    expect(fakePicker.allowedExtensions, ['pdf', 'doc', 'docx', 'xls', 'xlsx']);
  });
}

class _FakeFilePickerPlatform extends FilePickerPlatform {
  FileType? type;
  List<String>? allowedExtensions;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    return null;
  }
}

class _CatalogRepository extends FieldCatalogRepository {
  _CatalogRepository() : super(Dio());

  @override
  Future<FieldCatalogPage> fetchPage({
    required String catalog,
    String? apiPrefix,
    String? entity,
    String? query,
    String queryParameter = 'q',
    int? projectId,
    int page = 1,
    int perPage = 20,
    Map<String, Object?> extraQueryParameters = const {},
  }) async =>
      const FieldCatalogPage(items: [], currentPage: 1, lastPage: 1, total: 0);
}
