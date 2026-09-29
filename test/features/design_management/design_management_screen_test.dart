import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_model.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_file_service.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_repository.dart';
import 'package:prohelpers_mobile/features/design_management/domain/design_package_provider.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/design_management_screen.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  _FakeProjectsNotifier() : super(_FakeProjectsRepository()) {
    final project =
        Project()
          ..serverId = 9
          ..name = 'Tower A'
          ..address = 'Site';
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

class _FakeDesignPackageRepository extends DesignPackageRepository {
  _FakeDesignPackageRepository() : super(Dio());
}

class _FakeDesignPackageNotifier extends DesignPackageNotifier {
  _FakeDesignPackageNotifier({
    String title = 'Рабочая документация',
    String? status,
    String? statusLabel,
  }) : super(_FakeDesignPackageRepository()) {
    state = DesignPackageState(
      projectId: 9,
      page: DesignPackagePage(
        items: [
          DesignPackageModel(
            id: 42,
            projectId: 9,
            title: title,
            status: status,
            statusLabel: statusLabel,
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      ),
    );
  }

  String? action;
  String? comment;
  int detailFetchCalls = 0;
  DesignPackageModel? detailOverride;
  Completer<DesignPackageModel>? detailGate;

  @override
  void syncProject(int? projectId) {
    state = state.copyWith(projectId: projectId);
  }

  @override
  Future<void> load() async {}

  @override
  Future<DesignPackageModel> fetchDetail(int id) async {
    detailFetchCalls++;
    final gate = detailGate;
    if (gate != null) return gate.future;
    return detailOverride ?? _detail();
  }

  @override
  Future<DesignPackageModel> executeAction({
    required int id,
    required DesignPackageAction action,
    String? comment,
  }) async {
    this.action = action.key;
    this.comment = comment;
    return _detail();
  }
}

class _RecordingFileService extends DesignPackageFileService {
  _RecordingFileService({
    this.downloadError,
    this.downloadGate,
    this.openResult = true,
  }) : super(
         launchPreview: (uri) async {
           _openedPreviews.add(uri);
           return true;
         },
         openLocalFile: (path) async {
           _openedPaths.add(path);
           return _openLocalResult;
         },
       ) {
    _openLocalResult = openResult;
  }

  static final _openedPreviews = <Uri>[];
  static final _openedPaths = <String>[];
  static bool _openLocalResult = true;

  final Object? downloadError;
  final Completer<String>? downloadGate;
  final bool openResult;
  final downloadedUris = <Uri>[];
  int downloadCalls = 0;
  int cleanupCalls = 0;

  void reset() {
    _openedPreviews.clear();
    _openedPaths.clear();
    downloadedUris.clear();
    downloadCalls = 0;
    cleanupCalls = 0;
  }

  List<Uri> get openedPreviews => List.unmodifiable(_openedPreviews);
  List<String> get openedPaths => List.unmodifiable(_openedPaths);

  @override
  Future<String> download(Uri uri, String fileName) async {
    downloadCalls++;
    downloadedUris.add(uri);
    final error = downloadError;
    if (error != null) throw error;
    final gate = downloadGate;
    if (gate != null) return gate.future;
    return '/tmp/$fileName';
  }

  @override
  Future<void> deleteDownloaded(String path) async {
    cleanupCalls++;
  }

  @override
  void scheduleCleanup(String path) {}
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Dio(), SecureStorageService());
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier()
    : super(
        _FakeAuthRepository(),
        SecureStorageService(),
        autoCheckAuth: false,
      ) {
    final user =
        User()
          ..serverId = 7
          ..email = 'test@example.test'
          ..name = 'Test'
          ..organizationsJson = '[]';
    state = AuthAuthenticated(
      user,
      sessionIdentity: const AuthSessionIdentity(
        userId: 7,
        organizationId: 9,
        sessionId: 'session-a',
      ),
    );
  }
}

void main() {
  late _RecordingFileService fileService;

  setUp(() {
    fileService = _RecordingFileService();
    fileService.reset();
  });

  testWidgets('package card fits long title and status on compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const title = 'РД_системы_вентиляции_секции_А_северного_корпуса';
    const status = 'Ожидает подтверждения проектировщика';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => _FakeProjectsNotifier()),
          designPackageProvider.overrideWith(
            (ref) => _FakeDesignPackageNotifier(title: title, status: status),
          ),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const DesignManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
    expect(find.text(status), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('package card shows localized status label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => _FakeProjectsNotifier()),
          designPackageProvider.overrideWith(
            (ref) => _FakeDesignPackageNotifier(
              status: 'draft',
              statusLabel: 'Черновик',
            ),
          ),
        ],
        child: const MaterialApp(home: DesignManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Черновик'), findsOneWidget);
    expect(find.text('draft'), findsNothing);
  });

  testWidgets('package detail shows localized fields and hides generic MIME', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier()),
          projectsProvider.overrideWith((ref) => _FakeProjectsNotifier()),
          designPackageProvider.overrideWith(
            (ref) => _FakeDesignPackageNotifier(),
          ),
          designPackageFileServiceProvider.overrideWithValue(fileService),
        ],
        child: const MaterialApp(home: DesignManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Рабочая документация'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Информационная модель'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Информационная модель'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Количество открытых блокирующих замечаний'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Черновик'), findsNWidgets(2));
    expect(find.text('Согласован'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('3D_IFC.ifc'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('application/octet-stream'), findsNothing);
  });

  testWidgets('uses only the freshly fetched preview URI', (tester) async {
    final notifier =
        _FakeDesignPackageNotifier()
          ..detailOverride = _detail(previewUrl: 'https://files.test/fresh');
    await _pumpPackageDetail(tester, notifier, fileService);
    await _tapPreview(tester);

    expect(fileService.openedPreviews, [Uri.parse('https://files.test/fresh')]);
    expect(notifier.detailFetchCalls, 1);
  });

  testWidgets('does not open a file when download fails', (tester) async {
    final failingService = _RecordingFileService(
      downloadError: const ApiException(
        'На сервере произошла ошибка. Попробуйте позже.',
        statusCode: 503,
      ),
    );
    final notifier =
        _FakeDesignPackageNotifier()
          ..detailOverride = _detail(downloadUrl: 'https://files.test/fresh');
    await _pumpPackageDetail(tester, notifier, failingService);
    await _tapDownload(tester);

    expect(failingService.downloadedUris, [
      Uri.parse('https://files.test/fresh'),
    ]);
    expect(failingService.openedPaths, isEmpty);
    expect(
      find.text('На сервере произошла ошибка. Попробуйте позже.'),
      findsOneWidget,
    );
  });

  testWidgets('explains when no local app can open the downloaded file', (
    tester,
  ) async {
    final noViewerService = _RecordingFileService(openResult: false);
    final notifier =
        _FakeDesignPackageNotifier()
          ..detailOverride = _detail(downloadUrl: 'https://files.test/fresh');
    await _pumpPackageDetail(tester, notifier, noViewerService);
    await _tapDownload(tester);

    expect(noViewerService.openedPaths, ['/tmp/Исполнительная схема.pdf']);
    expect(noViewerService.cleanupCalls, 1);
    expect(
      find.text(
        'Не удалось открыть файл. Проверьте, что на устройстве есть приложение для просмотра документов.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not open after project changes during detail fetch', (
    tester,
  ) async {
    final notifier = _FakeDesignPackageNotifier();
    final projects = _FakeProjectsNotifier();
    await _pumpPackageDetail(tester, notifier, fileService, projects: projects);
    final gate = Completer<DesignPackageModel>();
    notifier.detailGate = gate;
    await tester.scrollUntilVisible(
      find.text('Исполнительная схема.pdf'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Просмотреть'));
    await tester.pump();

    final otherProject =
        Project()
          ..serverId = 10
          ..name = 'Tower B'
          ..address = 'Other site';
    projects.state = ProjectsState(
      isLoading: false,
      projects: [otherProject],
      selectedProject: otherProject,
    );
    gate.complete(_detail());
    await tester.pumpAndSettle();

    expect(fileService.openedPreviews, isEmpty);
    expect(fileService.downloadCalls, 0);
  });

  testWidgets('disables file actions while one request is in flight', (
    tester,
  ) async {
    final gate = Completer<String>();
    final gatedService = _RecordingFileService(downloadGate: gate);
    final notifier =
        _FakeDesignPackageNotifier()
          ..detailOverride = _detail(downloadUrl: 'https://files.test/fresh');
    await _pumpPackageDetail(tester, notifier, gatedService);
    await _tapDownload(tester, wait: false);
    await tester.pump();
    expect(notifier.detailFetchCalls, 1);
    expect(find.byTooltip('Скачать и открыть'), findsNothing);
    expect(gatedService.downloadCalls, 1);
    gate.complete('/tmp/file.pdf');
    await tester.pumpAndSettle();
    expect(gatedService.openedPaths, ['/tmp/file.pdf']);
  });

  testWidgets('hides a late file error after selected project changes', (
    tester,
  ) async {
    final notifier = _FakeDesignPackageNotifier();
    final projects = _FakeProjectsNotifier();
    await _pumpPackageDetail(tester, notifier, fileService, projects: projects);
    final gate = Completer<DesignPackageModel>();
    notifier.detailGate = gate;
    await tester.scrollUntilVisible(
      find.text('Исполнительная схема.pdf'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Просмотреть'));
    await tester.pump();

    final otherProject =
        Project()
          ..serverId = 10
          ..name = 'Tower B'
          ..address = 'Other site';
    projects.state = ProjectsState(
      isLoading: false,
      projects: [otherProject],
      selectedProject: otherProject,
    );
    gate.completeError(const ApiException('Ошибка прежнего объекта'));
    await tester.pumpAndSettle();

    expect(find.text('Ошибка прежнего объекта'), findsNothing);
    expect(fileService.openedPreviews, isEmpty);
    expect(fileService.downloadCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cleans download and does not open after project changes', (
    tester,
  ) async {
    final gate = Completer<String>();
    final gatedService = _RecordingFileService(downloadGate: gate);
    final notifier =
        _FakeDesignPackageNotifier()
          ..detailOverride = _detail(downloadUrl: 'https://files.test/fresh');
    final projects = _FakeProjectsNotifier();
    await _pumpPackageDetail(
      tester,
      notifier,
      gatedService,
      projects: projects,
    );
    await _tapDownload(tester, wait: false);

    final otherProject =
        Project()
          ..serverId = 10
          ..name = 'Tower B'
          ..address = 'Other site';
    projects.state = ProjectsState(
      isLoading: false,
      projects: [otherProject],
      selectedProject: otherProject,
    );
    await tester.pump();
    gate.complete('/tmp/file.pdf');
    await tester.pumpAndSettle();

    expect(gatedService.openedPaths, isEmpty);
    expect(gatedService.cleanupCalls, 1);
  });

  testWidgets('shows selected project packages and runs an allowed action', (
    tester,
  ) async {
    final notifier = _FakeDesignPackageNotifier();
    final projects = _FakeProjectsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => projects),
          designPackageProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: DesignManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ПИР'), findsOneWidget);
    expect(find.text('Рабочая документация'), findsOneWidget);
    await tester.tap(find.text('Рабочая документация'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Исполнительная схема.pdf'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Исполнительная схема.pdf'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Комментарии'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Комментарии'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Результат'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Результат'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Согласовать'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Согласовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Проверено');
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(notifier.action, 'approve');
    expect(notifier.comment, 'Проверено');

    final otherProject =
        Project()
          ..serverId = 10
          ..name = 'Tower B'
          ..address = 'Other site';
    projects.state = ProjectsState(
      isLoading: false,
      projects: [otherProject],
      selectedProject: otherProject,
    );
    await tester.pumpAndSettle();

    expect(find.text('Объект изменился'), findsOneWidget);
    expect(find.text('Согласовать'), findsNothing);
    expect(find.text('Исполнительная схема.pdf'), findsNothing);
  });
}

Future<void> _pumpPackageDetail(
  WidgetTester tester,
  _FakeDesignPackageNotifier notifier,
  DesignPackageFileService fileService, {
  _FakeProjectsNotifier? projects,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FakeAuthNotifier()),
        projectsProvider.overrideWith(
          (ref) => projects ?? _FakeProjectsNotifier(),
        ),
        designPackageProvider.overrideWith((ref) => notifier),
        designPackageFileServiceProvider.overrideWithValue(fileService),
      ],
      child: const MaterialApp(home: DesignManagementScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Рабочая документация'));
  await tester.pumpAndSettle();
  notifier.detailFetchCalls = 0;
}

Future<void> _tapPreview(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Исполнительная схема.pdf'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.byTooltip('Просмотреть'));
  await tester.pumpAndSettle();
}

Future<void> _tapDownload(WidgetTester tester, {bool wait = true}) async {
  await tester.scrollUntilVisible(
    find.text('Исполнительная схема.pdf'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.byTooltip('Скачать и открыть'));
  if (wait) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

DesignPackageModel _detail({
  String previewUrl = 'https://files.example.test/stale-preview',
  String downloadUrl = 'https://files.example.test/stale-download',
}) => DesignPackageModel(
  id: 42,
  projectId: 9,
  title: 'Рабочая документация',
  stage: 'РД',
  projectStage: 'bim',
  projectStageLabel: 'Информационная модель',
  status: 'draft',
  statusLabel: 'Черновик',
  result: const [
    DesignPackageValue(
      label: 'Статус',
      value: 'draft',
      displayValue: 'Черновик',
    ),
    DesignPackageValue(
      label: 'Статус состава',
      value: 'approved',
      displayValue: 'Согласован',
    ),
    DesignPackageValue(
      label: 'Количество открытых блокирующих замечаний',
      value: '0',
    ),
  ],
  files: [
    DesignPackageFile(
      id: 11,
      name: 'Исполнительная схема.pdf',
      previewUrl: previewUrl,
      downloadUrl: downloadUrl,
    ),
    DesignPackageFile(
      id: 12,
      name: '3D_IFC.ifc',
      mimeType: 'application/octet-stream',
    ),
  ],
  comments: const [DesignPackageComment(author: 'Инженер', body: 'Проверено')],
  availableActions: const [
    DesignPackageAction(
      key: 'approve',
      title: 'Согласовать',
      requiresComment: true,
    ),
  ],
);
