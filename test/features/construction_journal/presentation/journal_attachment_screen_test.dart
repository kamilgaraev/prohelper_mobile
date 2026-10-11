import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/journal_photo_picker.dart';
import 'package:prohelpers_mobile/features/construction_journal/domain/construction_journal_provider.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/journal_entry_detail_screen.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_file_service.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  testWidgets('organization change hides metadata from the old file context', (
    tester,
  ) async {
    final repository = _Repository(canUpload: false, withPhoto: true);
    final auth = _AuthNotifier();
    await _pump(tester, repository, auth: auth);
    expect(find.text('site.png'), findsOneWidget);
    auth.changeOrganization(11);
    await tester.pumpAndSettle();
    expect(find.text('site.png'), findsNothing);
    expect(
      find.text('Объект или организация изменились. Откройте запись заново.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'ancestor can open a photo with a fresh grant but cannot upload',
    (tester) async {
      final repository = _Repository(canUpload: false, withPhoto: true);
      final files = _FileService();
      await _pump(tester, repository, files: files);
      expect(find.text('site.png'), findsOneWidget);
      expect(find.text('Добавить фото'), findsNothing);
      await tester.tap(find.text('site.png'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('site.png'));
      await tester.pumpAndSettle();
      expect(repository.grants, 2);
      expect(files.opened, 2);
      expect(files.uris.map((uri) => uri.queryParameters['signature']), [
        '1',
        '2',
      ]);
    },
  );

  testWidgets(
    'server upload action enables online photo selection and refreshes metadata',
    (tester) async {
      final repository = _Repository(canUpload: true);
      await _pump(tester, repository);
      expect(find.text('Фото пока нет.'), findsOneWidget);
      await tester.tap(find.text('Добавить фото'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выбрать фото'));
      await tester.pumpAndSettle();
      expect(repository.uploads, 1);
      expect(find.text('site.png'), findsOneWidget);
    },
  );

  testWidgets(
    'switching organization during photo selection cancels the upload',
    (tester) async {
      final repository = _Repository(canUpload: true);
      final picker = _Picker(Completer<String?>());
      final auth = _AuthNotifier();
      await _pump(tester, repository, picker: picker, auth: auth);
      await tester.tap(find.text('Добавить фото'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выбрать фото'));
      await tester.pump();
      auth.changeOrganization(11);
      await tester.pump();
      picker.pending!.complete('/picked/site.png');
      await tester.pumpAndSettle();
      expect(repository.uploads, 0);
    },
  );

  testWidgets(
    'a cached capability cannot upload photos until network refresh',
    (tester) async {
      final repository = _Repository(canUpload: true);
      await _pump(tester, repository, cached: true);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Добавить фото'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Для загрузки фото обновите запись при подключении к интернету.',
        ),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  _FileService? files,
  _Picker? picker,
  _AuthNotifier? auth,
  bool cached = false,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final notifier = _Notifier(repository);
  await notifier.load();
  if (cached) notifier.markCached();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        constructionJournalRepositoryProvider.overrideWithValue(repository),
        projectsProvider.overrideWith((ref) => _Projects()),
        authProvider.overrideWith((ref) => auth ?? _AuthNotifier()),
        constructionJournalEntryDetailProvider((
          entryId: 84,
          projectId: 52,
        )).overrideWith((ref) => notifier),
        journalPhotoPickerProvider.overrideWithValue(picker ?? _Picker()),
        designPackageFileServiceProvider.overrideWithValue(
          files ?? _FileService(),
        ),
      ],
      child: const MaterialApp(
        home: JournalEntryDetailScreen(
          journalId: 17,
          entryId: 84,
          projectId: 52,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _AuthNotifier extends TestAuthNotifier {
  _AuthNotifier()
    : super(
        user: MostTestData.user(),
        storage: MemorySecureStorageService(),
        authenticated: true,
      );
  void changeOrganization(int organizationId) {
    final user = MostTestData.user()..currentOrganizationId = organizationId;
    state = AuthAuthenticated(user);
  }
}

class _Projects extends ProjectsNotifier {
  _Projects() : super(ProjectsRepository(Dio())) {
    state = state.copyWith(
      selectedProject:
          Project()
            ..serverId = 52
            ..name = 'Объект'
            ..address = 'Площадка',
    );
  }
}

class _Notifier extends ConstructionJournalEntryDetailNotifier {
  _Notifier(ConstructionJournalRepository repository)
    : super(repository, 84, projectId: 52);
  void markCached() {
    state = state.copyWith(fromCache: true);
  }
}

class _Picker extends JournalPhotoPicker {
  _Picker([this.pending]);
  final Completer<String?>? pending;
  @override
  Future<String?> pick({required bool camera}) async =>
      pending == null ? '/picked/site.png' : pending!.future;
}

class _Repository extends ConstructionJournalRepository {
  _Repository({required this.canUpload, this.withPhoto = false}) : super(Dio());
  final bool canUpload;
  bool withPhoto;
  int uploads = 0;
  int grants = 0;
  @override
  Future<ConstructionJournalEntryModel> fetchEntryDetail(int id) async =>
      ConstructionJournalEntryModel(
        id: 84,
        journalId: 17,
        entryDate: '2026-10-11',
        entryNumber: 1,
        workDescription: 'Монтаж',
        status: 'draft',
        statusLabel: 'Черновик',
        workflowState: 'ready',
        workVolumes: [],
        blockers: [],
        attachments:
            withPhoto
                ? [
                  const ConstructionJournalAttachment(
                    id: 'photo-uuid',
                    fileName: 'site.png',
                  ),
                ]
                : [],
        availableActions: [
          const ConstructionJournalActionModel(
            action: 'view',
            label: 'Открыть',
          ),
          if (canUpload)
            const ConstructionJournalActionModel(
              action: 'upload_attachment',
              label: 'Добавить фото',
            ),
        ],
      );
  @override
  Future<void> uploadAttachment(int entryId, String path) async {
    expect(entryId, 84);
    uploads++;
    withPhoto = true;
  }

  @override
  Future<ConstructionJournalAttachmentDownload> attachmentDownload(
    int entryId,
    String attachmentId,
  ) async {
    expect(entryId, 84);
    expect(attachmentId, 'photo-uuid');
    grants++;
    return ConstructionJournalAttachmentDownload(
      url: Uri.parse('https://storage.example.test/photo?signature=$grants'),
    );
  }
}

class _FileService extends DesignPackageFileService {
  int opened = 0;
  final uris = <Uri>[];
  @override
  Future<String> download(Uri uri, String fileName) async {
    uris.add(uri);
    return '/temporary/site.png';
  }

  @override
  Future<bool> openLocalFile(String path) async {
    opened++;
    return true;
  }

  @override
  void scheduleCleanup(String path) {}
  @override
  Future<void> deleteDownloaded(String path) async {}
}
