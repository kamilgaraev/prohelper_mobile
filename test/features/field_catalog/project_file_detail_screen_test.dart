import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/field_catalog_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/project_files_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/presentation/field_catalog_screen.dart';

void main() {
  testWidgets('project file detail shows user metadata and hides API fields', (
    tester,
  ) async {
    final entry = FieldCatalogEntry.fromJson({
      'id': 320,
      'project_id': 52,
      'record_type': 'project',
      'record_id': 52,
      'name': 'QA_MOST_20260928.pdf',
      'mime_type': 'application/pdf',
      'size': 1234567,
      'description': 'Документ для проверки',
      'created_at': '2026-09-28T10:15:00',
      'download_url': 'https://files.example.test/signed/320',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldCatalogRepositoryProvider.overrideWithValue(_Repository(entry)),
        ],
        child: const MaterialApp(
          home: FieldCatalogDetailScreen(
            title: 'Файлы объекта',
            catalog: 'project-files',
            uuid: '320',
            projectId: 52,
            icon: Icons.folder_outlined,
            detailFieldLabels: {
              'description': 'Описание',
              'size': 'Размер',
              'mime_type': 'Формат',
              'created_at': 'Дата загрузки',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QA_MOST_20260928.pdf'), findsOneWidget);
    expect(find.text('Описание'), findsOneWidget);
    expect(find.text('Документ для проверки'), findsOneWidget);
    expect(find.text('Размер'), findsOneWidget);
    expect(find.text('1.2 МБ'), findsOneWidget);
    expect(find.text('Формат'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Дата загрузки'), findsOneWidget);
    expect(find.text('28.09.2026 10:15'), findsOneWidget);
    expect(find.text('Скачать файл'), findsOneWidget);

    for (final technicalValue in const [
      'Id',
      'Project id',
      'Record type',
      'Record id',
      'Mime type',
      'Download url',
      '320',
      '52',
      'project',
      'application/pdf',
    ]) {
      expect(find.text(technicalValue), findsNothing);
    }
  });

  testWidgets('project file download fetches a fresh URL before launch', (
    tester,
  ) async {
    const expiredUrl = 'https://files.example.test/expired/320';
    const freshUrl = 'https://files.example.test/fresh/320';
    final files = _ProjectFilesRepository([
      FieldCatalogEntry.fromJson({
        'id': 320,
        'name': 'file.pdf',
        'download_url': freshUrl,
      }),
    ]);
    final launcher = _FakeUrlLauncher();
    addTearDown(launcher.dispose);

    await _pumpProjectFile(tester, expiredUrl, files);
    await tester.tap(find.text('Скачать файл'));
    await tester.pumpAndSettle();

    expect(files.calls, 1);
    expect(files.projectIds, [52]);
    expect(files.fileIds, ['320']);
    expect(launcher.urls, [freshUrl]);
    expect(launcher.urls, isNot(contains(expiredUrl)));
  });

  testWidgets('failed fresh URL request shows error and can be retried', (
    tester,
  ) async {
    const expiredUrl = 'https://files.example.test/expired/320';
    const freshUrl = 'https://files.example.test/fresh/320';
    final files = _ProjectFilesRepository([
      StateError('network unavailable'),
      FieldCatalogEntry.fromJson({
        'id': 320,
        'name': 'file.pdf',
        'download_url': freshUrl,
      }),
    ]);
    final launcher = _FakeUrlLauncher();
    addTearDown(launcher.dispose);

    await _pumpProjectFile(tester, expiredUrl, files);
    await tester.tap(find.text('Скачать файл'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось получить ссылку на файл. Повторите попытку.'),
      findsOneWidget,
    );
    expect(launcher.urls, isEmpty);

    await tester.tap(find.text('Скачать файл'));
    await tester.pumpAndSettle();
    expect(files.calls, 2);
    expect(launcher.urls, [freshUrl]);
    expect(launcher.urls, isNot(contains(expiredUrl)));
  });

  testWidgets('download prevents duplicate requests and tolerates dismissal', (
    tester,
  ) async {
    final files = _DelayedProjectFilesRepository();
    final launcher = _FakeUrlLauncher();
    addTearDown(launcher.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldCatalogRepositoryProvider.overrideWithValue(
            _Repository(_fileEntry('https://files.example.test/expired/320')),
          ),
          projectFilesRepositoryProvider.overrideWithValue(files),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed:
                        () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => const FieldCatalogDetailScreen(
                                  title: 'Файлы объекта',
                                  catalog: 'project-files',
                                  uuid: '320',
                                  projectId: 52,
                                  icon: Icons.folder_outlined,
                                ),
                          ),
                        ),
                    child: const Text('Открыть файл'),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть файл'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Скачать файл'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    expect(files.calls, 1);
    expect(find.text('Получаем ссылку'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    files.result.complete(
      FieldCatalogEntry.fromJson({
        'id': 320,
        'download_url': 'https://files.example.test/fresh/320',
      }),
    );
    await tester.pumpAndSettle();
    expect(launcher.urls, isEmpty);
  });
}

Future<void> _pumpProjectFile(
  WidgetTester tester,
  String expiredUrl,
  _ProjectFilesRepository files,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fieldCatalogRepositoryProvider.overrideWithValue(
          _Repository(_fileEntry(expiredUrl)),
        ),
        projectFilesRepositoryProvider.overrideWithValue(files),
      ],
      child: const MaterialApp(
        home: FieldCatalogDetailScreen(
          title: 'Файлы объекта',
          catalog: 'project-files',
          uuid: '320',
          projectId: 52,
          icon: Icons.folder_outlined,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FieldCatalogEntry _fileEntry(String downloadUrl) => FieldCatalogEntry.fromJson({
  'id': 320,
  'project_id': 52,
  'name': 'QA_MOST_20260928.pdf',
  'download_url': downloadUrl,
});

class _Repository extends FieldCatalogRepository {
  _Repository(this.entry) : super(Dio());

  final FieldCatalogEntry entry;

  @override
  Future<FieldCatalogEntry> fetchDetail({
    required String catalog,
    String? apiPrefix,
    String? entity,
    required String uuid,
    int? projectId,
  }) async => entry;
}

class _ProjectFilesRepository extends ProjectFilesRepository {
  _ProjectFilesRepository(this.responses) : super(Dio());

  final List<Object> responses;
  final List<int> projectIds = [];
  final List<String> fileIds = [];
  int calls = 0;

  @override
  Future<FieldCatalogEntry> fetchDetail({
    required int projectId,
    required String fileId,
  }) async {
    calls++;
    projectIds.add(projectId);
    fileIds.add(fileId);
    final response = responses.removeAt(0);
    if (response is Error) throw response;
    return response as FieldCatalogEntry;
  }
}

class _FakeUrlLauncher {
  static const _channel = MethodChannel('plugins.flutter.io/url_launcher');

  final List<String> urls = [];

  _FakeUrlLauncher() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'launch') {
            urls.add((call.arguments as Map)['url'] as String);
            return true;
          }
          return null;
        });
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

class _DelayedProjectFilesRepository extends ProjectFilesRepository {
  _DelayedProjectFilesRepository() : super(Dio());

  final Completer<FieldCatalogEntry> result = Completer<FieldCatalogEntry>();
  int calls = 0;

  @override
  Future<FieldCatalogEntry> fetchDetail({
    required int projectId,
    required String fileId,
  }) {
    calls++;
    return result.future;
  }
}
