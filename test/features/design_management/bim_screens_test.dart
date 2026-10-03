import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_models.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_repository.dart';
import 'package:prohelpers_mobile/features/design_management/domain/bim_provider.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_provider.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/bim_catalog_screen.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/bim_viewer_screen.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/bim_issue_screens.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

void main() {
  testWidgets(
    'viewer automatically checks preparation and stops after failure',
    (tester) async {
      final repository =
          _Repository()
            ..viewers = [
              const BimPreparedViewer(versionId: 55, status: 'queued'),
              const BimPreparedViewer(versionId: 55, status: 'failed'),
            ];
      await tester.pumpWidget(
        _host(
          repository,
          const BimViewerScreen(projectId: 9, title: 'АР', versionIds: [55]),
        ),
      );
      await tester.pump();
      expect(find.text('Модель ожидает подготовки.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Не удалось подготовить модель.'), findsOneWidget);
      expect(repository.viewerReads, 2);
      await tester.pump(const Duration(seconds: 6));
      expect(repository.viewerReads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('viewer cancels preparation polling when closed', (tester) async {
    final repository =
        _Repository()
          ..viewers = [
            const BimPreparedViewer(versionId: 55, status: 'processing'),
          ];
    await tester.pumpWidget(
      _host(
        repository,
        const BimViewerScreen(projectId: 9, title: 'АР', versionIds: [55]),
      ),
    );
    await tester.pump();
    expect(repository.viewerReads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
    expect(repository.viewerReads, 1);
  });
  testWidgets('ready model does not request another preparation', (
    tester,
  ) async {
    final repository =
        _Repository()
          ..catalog = const BimPage(
            items: [
              BimModelVersion(
                id: 55,
                title: 'АР',
                status: 'ready',
                actions: [
                  BimAction(key: 'prepare_viewer', label: 'Подготовить'),
                ],
              ),
            ],
          );
    await tester.pumpWidget(
      _host(repository, const BimCatalogScreen(projectId: 9)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Готова к просмотру'), findsOneWidget);
    expect(find.text('Подготовить к просмотру'), findsNothing);
    expect(find.text('Открыть'), findsOneWidget);
  });
  testWidgets('catalog shows forbidden and preserves offline entry', (
    tester,
  ) async {
    final repository = _Repository()..forbidden = true;
    await tester.pumpWidget(
      _host(repository, const BimCatalogScreen(projectId: 9)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Модели недоступны'), findsOneWidget);
    expect(find.text('На устройстве'), findsOneWidget);
    expect(find.text('Создать набор'), findsNothing);
  });
  testWidgets('processing model exposes server-authorized recovery action', (
    tester,
  ) async {
    final repository =
        _Repository()
          ..catalog = const BimPage(
            items: [
              BimModelVersion(
                id: 55,
                title: 'АР',
                status: 'processing',
                progress: 45,
                actions: [
                  BimAction(key: 'prepare_viewer', label: 'Подготовить'),
                ],
              ),
            ],
          );
    await tester.pumpWidget(
      _host(repository, const BimCatalogScreen(projectId: 9)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Подготавливается'), findsOneWidget);
    expect(find.text('Повторить подготовку'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Повторить подготовку'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('Создать набор'), findsNothing);
  });
  testWidgets(
    'set mutations are disabled offline although server permits them',
    (tester) async {
      final repository =
          _Repository()
            ..setPage = const BimPage(
              items: [
                BimModelSet(
                  id: 3,
                  projectId: 9,
                  title: 'Координация',
                  revision: 4,
                  actions: [BimAction(key: 'update', label: 'Изменить')],
                ),
              ],
              actions: [BimAction(key: 'create', label: 'Создать')],
            );
      await tester.pumpWidget(
        _host(repository, const BimCatalogScreen(projectId: 9), online: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Наборы'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Создать набор'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Изменить'))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('issue actions follow enabled flags', (tester) async {
    final repository =
        _Repository()
          ..issueValue = const BimIssue(
            id: 6,
            projectId: 9,
            revision: 2,
            title: 'Коллизия',
            status: 'resolved',
            actions: [
              BimAction(key: 'verify', label: 'Подтвердить', enabled: false),
            ],
          );
    await tester.pumpWidget(
      _host(repository, const BimIssueDetailScreen(id: 6)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Устранено'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Подтвердить'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('issue without snapshot preserves version and view context', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      _host(
        repository,
        const BimIssueEditorScreen(
          projectId: 9,
          versionId: 55,
          snapshotUnavailable: true,
          contextPayload: {
            'camera': {'section_planes': []},
            'elements': [
              {'version_id': 55, 'element_id': 71},
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Не удалось сделать снимок модели.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Создать замечание'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Создать замечание'));
    await tester.pumpAndSettle();
    expect(repository.creates, 0);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('bim-issue-title')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Укажите название'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('bim-issue-title')),
      'Коллизия',
    );
    await tester.scrollUntilVisible(
      find.text('Создать замечание'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Создать замечание'));
    await tester.pumpAndSettle();
    expect(repository.creates, 1);
    expect(repository.payload!['version_id'], 55);
    expect(repository.payload!['camera'], {'section_planes': []});
    expect(repository.payload!['elements'].single['element_id'], 71);
  });
  testWidgets(
    'failed snapshot upload retries stable operation without second issue',
    (tester) async {
      final repository = _Repository()..failSnapshotOnce = true;
      final snapshot =
          (await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            ui.Canvas(
              recorder,
            ).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
            final picture = recorder.endRecording();
            final image = await picture.toImage(1, 1);
            final result =
                (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!.buffer.asUint8List();
            image.dispose();
            picture.dispose();
            return result;
          }))!;
      await tester.pumpWidget(
        _host(
          repository,
          BimIssueEditorScreen(
            projectId: 9,
            versionId: 55,
            contextPayload: const {'title': 'Коллизия', 'camera': {}},
            snapshot: snapshot,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Создать замечание'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Создать замечание'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(repository.snapshots, 1);
      expect(find.text('Отправить вложения'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Отправить вложения'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Отправить вложения'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(repository.snapshots, 2);
      expect(repository.snapshotKeys.toSet().length, 1);
    },
  );
}

Widget _host(_Repository repository, Widget child, {bool online = true}) =>
    ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) => _Projects()),
        bimRepositoryProvider.overrideWithValue(repository),
        bimOnlineProvider.overrideWith((ref) => Stream.value(online)),
        bimOfflineServiceProvider.overrideWith(
          (ref) async => throw const ApiException('Нет сохранённых моделей.'),
        ),
      ],
      child: MaterialApp(home: child),
    );

class _ProjectsRepository extends ProjectsRepository {
  _ProjectsRepository() : super(Dio());
  @override
  Future<List<Project>> fetchProjects() async => [];
}

class _Projects extends ProjectsNotifier {
  _Projects() : super(_ProjectsRepository()) {
    final project =
        Project()
          ..serverId = 9
          ..name = 'Объект';
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

class _Repository extends BimRepository {
  _Repository() : super(Dio());
  bool forbidden = false;
  bool failSnapshotOnce = false;
  int creates = 0;
  int snapshots = 0;
  int viewerReads = 0;
  List<BimPreparedViewer> viewers = [];
  @override
  Future<BimPreparedViewer> viewer(int id) async {
    final index =
        viewerReads < viewers.length ? viewerReads : viewers.length - 1;
    viewerReads++;
    return viewers[index];
  }

  BimJson? payload;
  final snapshotKeys = <String?>[];
  BimPage<BimModelVersion> catalog = const BimPage(items: []);
  BimPage<BimModelSet> setPage = const BimPage(items: []);
  BimIssue issueValue = const BimIssue(
    id: 6,
    projectId: 9,
    revision: 2,
    title: 'Коллизия',
    status: 'open',
  );
  @override
  Future<BimPage<BimModelVersion>> versions(
    int projectId, {
    int page = 1,
    String query = '',
    String? status,
  }) async {
    if (forbidden) throw const ApiException('Нет прав.', statusCode: 403);
    return catalog;
  }

  @override
  Future<BimPage<BimModelSet>> sets(int projectId, {int page = 1}) async =>
      setPage;
  @override
  Future<BimIssue> issue(int id) async => issueValue;
  @override
  Future<BimIssue> createIssue(
    int projectId,
    BimJson payload, {
    String? idempotencyKey,
  }) async {
    creates++;
    this.payload = payload;
    return issueValue;
  }

  @override
  Future<BimIssue> attachSnapshot(
    BimIssue issue,
    Uint8List bytes, {
    String? idempotencyKey,
  }) async {
    snapshots++;
    snapshotKeys.add(idempotencyKey);
    if (failSnapshotOnce && snapshots == 1) {
      throw const ApiException('Соединение прервано.');
    }
    return issueValue;
  }
}
