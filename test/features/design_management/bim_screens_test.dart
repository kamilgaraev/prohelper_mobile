import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_models.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_repository.dart';
import 'package:prohelpers_mobile/features/design_management/domain/bim_provider.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_provider.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_service.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_models.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/bim_catalog_screen.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/bim_viewer_screen.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/bim_issue_screens.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

void main() {
  for (final allowed in [true, false]) {
    testWidgets('online set forwards server create_issue permission $allowed', (
      tester,
    ) async {
      final repository =
          _Repository()
            ..viewers = [
              const BimPreparedViewer(versionId: 55, status: 'missing'),
            ]
            ..setPage = BimPage(
              items: [
                BimModelSet.fromJson({
                  'id': 3,
                  'project_id': 9,
                  'title': 'Координация',
                  'revision': 4,
                  'revisions': [
                    {
                      'revision': 4,
                      'version_ids': [55],
                    },
                  ],
                  'available_actions': [
                    {
                      'key': 'create_issue',
                      'label': 'Добавить замечание',
                      'enabled': allowed,
                    },
                  ],
                }),
              ],
            );
      await tester.pumpWidget(
        _host(repository, const BimCatalogScreen(projectId: 9)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Наборы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      final viewer = tester.widget<BimViewerScreen>(
        find.byType(BimViewerScreen),
      );
      expect(viewer.canCreateIssue, allowed);
      expect(viewer.modelSetRevisionId, 14);
      expect(viewer.versionIds, [55]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'package catalog displays package context and sends package filter',
    (tester) async {
      final repository =
          _Repository()
            ..catalog = const BimPage(
              items: [
                BimModelVersion(
                  id: 55,
                  title: 'Стены',
                  modelTitle: 'АР',
                  packageTitle: 'Корпус 2',
                  packageId: 42,
                  status: 'ready',
                ),
              ],
            );
      await tester.pumpWidget(
        _host(
          repository,
          const BimCatalogScreen(
            projectId: 9,
            packageId: 42,
            packageTitle: 'Корпус 2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Модели: Корпус 2'), findsOneWidget);
      expect(find.textContaining('Корпус 2\nВерсия'), findsOneWidget);
      expect(repository.packageIds.single, 42);
    },
  );

  testWidgets(
    'filtered model empty state resets conditions and restores results',
    (tester) async {
      final repository =
          _Repository()
            ..emptyWhenFiltered = true
            ..catalog = const BimPage(
              items: [BimModelVersion(id: 55, title: 'АР', status: 'ready')],
            );
      await tester.pumpWidget(
        _host(repository, const BimCatalogScreen(projectId: 9)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'нет совпадения');
      await tester.tap(find.byTooltip('Найти'));
      await tester.pumpAndSettle();
      expect(find.text('Нет моделей по выбранным условиям.'), findsOneWidget);
      await tester.tap(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      expect(find.text('АР'), findsOneWidget);
      expect(find.text('Нет моделей по выбранным условиям.'), findsNothing);
    },
  );

  testWidgets(
    'filtered issue empty state resets and restores existing issues',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        _host(repository, const BimIssuesScreen(projectId: 9)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтверждены').last);
      await tester.pumpAndSettle();
      expect(find.text('Нет замечаний по выбранным условиям.'), findsOneWidget);
      await tester.tap(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      expect(find.text('Коллизия'), findsOneWidget);
      expect(repository.issueStatus, isNull);
    },
  );

  testWidgets(
    'issue detail displays deadline severity blocking reason assignee and history',
    (tester) async {
      final repository =
          _Repository()
            ..issueValue = BimIssue.fromJson({
              'id': 6,
              'project_id': 9,
              'revision': 2,
              'title': 'Коллизия',
              'status': 'resolved',
              'severity': 'critical',
              'due_date': '2026-10-15',
              'is_blocking': true,
              'blocking_reason': 'Конфликт конструкций',
              'assignee_id': 100,
              'assignee': {'id': 100, 'name': 'Анна Иванова'},
              'author': {'id': 2, 'name': 'Автор замечания'},
              'history': [
                {
                  'to_status': 'resolved',
                  'author': 'Анна Иванова',
                  'comment': 'Коллизия устранена',
                  'changed_at': '2026-10-12T10:00:00Z',
                },
              ],
            });
      await tester.pumpWidget(
        _host(repository, const BimIssueDetailScreen(id: 6)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Исполнитель: Анна Иванова'), findsOneWidget);
      expect(find.text('Срок устранения: 15.10.2026'), findsOneWidget);
      expect(find.text('Важность: Критическая'), findsOneWidget);
      expect(
        find.text('Причина блокировки: Конфликт конструкций'),
        findsOneWidget,
      );
      expect(find.textContaining('Коллизия устранена'), findsOneWidget);
    },
  );

  testWidgets('rejected draft inspection offers repair and safe discard', (
    tester,
  ) async {
    final draft = BimIssueDraft(
      localId: 'rejected',
      versionId: 55,
      payload: {'title': 'Проверить коллизию'},
      attachments: const [],
      attempted: true,
      status: 'needs_review',
      rejectedBeforeCreate: true,
      lastError: 'Неверные данные',
    );
    await tester.pumpWidget(
      _host(_Repository(), BimDraftReviewScreen(projectId: 9, draft: draft)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Исправить черновик'), findsOneWidget);
    expect(find.text('Удалить с устройства'), findsOneWidget);
    expect(find.text('Неверные данные'), findsOneWidget);
  });

  testWidgets(
    'ambiguous draft inspection preserves content and prevents unsafe discard',
    (tester) async {
      final draft = BimIssueDraft(
        localId: 'uncertain',
        versionId: 55,
        payload: {'title': 'Сохранённая коллизия'},
        attachments: const [],
        attempted: true,
        status: 'needs_review',
      );
      await tester.pumpWidget(
        _host(_Repository(), BimDraftReviewScreen(projectId: 9, draft: draft)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Сохранённая коллизия'), findsOneWidget);
      expect(find.text('Повторить отправку'), findsOneWidget);
      expect(find.text('Исправить черновик'), findsNothing);
      expect(find.text('Удалить с устройства'), findsNothing);
    },
  );
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
  testWidgets('online attachment retry remains available after editor closes', (
    tester,
  ) async {
    final repository = _Repository()..failSnapshotOnce = true;
    final queue = _Queue(repository);
    final snapshot = await _snapshot(tester);
    await tester.pumpWidget(
      _host(
        repository,
        BimIssueEditorScreen(
          projectId: 9,
          versionId: 55,
          contextPayload: const {'title': 'Коллизия'},
          snapshot: snapshot,
        ),
        queue: queue,
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
    expect(queue.draft!.serverId, 6);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _host(
        repository,
        BimDraftReviewScreen(projectId: 9, draft: queue.draft!),
        queue: queue,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить отправку'));
    await tester.pumpAndSettle();
    expect(repository.creates, 1);
    expect(repository.snapshots, 2);
    expect(repository.snapshotKeys.toSet().length, 1);
    expect(find.text('Замечание и все вложения отправлены.'), findsOneWidget);
  });

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
      final queue = _Queue(repository);
      final snapshot = await _snapshot(tester);
      await tester.pumpWidget(
        _host(
          repository,
          BimIssueEditorScreen(
            projectId: 9,
            versionId: 55,
            contextPayload: const {'title': 'Коллизия', 'camera': {}},
            snapshot: snapshot,
          ),
          queue: queue,
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
      await tester.scrollUntilVisible(
        find.text('Отправить вложения'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Отправить вложения'), findsOneWidget);
      await tester.tap(find.text('Отправить вложения'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(repository.snapshots, 2);
      expect(repository.snapshotKeys.toSet().length, 1);
    },
  );
}

Future<Uint8List> _snapshot(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      final bytes =
          (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      return bytes;
    }))!;

Widget _host(
  _Repository repository,
  Widget child, {
  bool online = true,
  _Queue? queue,
}) => ProviderScope(
  overrides: [
    projectsProvider.overrideWith((ref) => _Projects()),
    bimRepositoryProvider.overrideWithValue(repository),
    bimOnlineProvider.overrideWith((ref) => Stream.value(online)),
    bimOfflineServiceProvider.overrideWith(
      (ref) async => queue ?? _Queue(repository),
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
  bool emptyWhenFiltered = false;
  final packageIds = <int?>[];
  String? issueStatus;
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
    int? packageId,
  }) async {
    if (forbidden) throw const ApiException('Нет прав.', statusCode: 403);
    packageIds.add(packageId);
    if (emptyWhenFiltered && (query.isNotEmpty || status != null)) {
      return const BimPage(items: []);
    }
    return catalog;
  }

  @override
  Future<BimPage<BimModelSet>> sets(int projectId, {int page = 1}) async =>
      setPage;
  @override
  Future<BimJson> openSet(int id, int revision) async => {
    'model_set_revision_id': 14,
    'model_set_revision': revision,
    'models': [55],
    'transforms': {},
  };
  @override
  Future<BimIssue> issue(int id) async => issueValue;
  @override
  Future<BimPage<BimIssue>> issues(
    int projectId, {
    int page = 1,
    String? status,
    int? versionId,
  }) async {
    issueStatus = status;
    return BimPage(items: status == null ? [issueValue] : []);
  }

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

class _Queue extends Fake implements BimOfflineService {
  _Queue(this.repository);
  final _Repository repository;
  BimIssueDraft? draft;
  bool snapshot = false;
  bool created = false;
  bool snapshotSent = false;
  final synced = Completer<void>();
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<List<BimOfflinePackage>> packages() async => [];
  @override
  Future<List<BimSavedSet>> savedSets() async => [];
  @override
  Future<List<BimIssueDraft>> drafts() async => [if (draft != null) draft!];
  @override
  Future<BimIssueDraft> createDraft({
    required int versionId,
    required Map<String, dynamic> payload,
    List<BimDraftAttachmentInput> attachments = const [],
    Uint8List? snapshot,
  }) async {
    expect(repository.creates, 0);
    this.snapshot =
        snapshot != null || attachments.any((item) => item.kind == 'snapshot');
    return draft = BimIssueDraft(
      localId: 'durable',
      versionId: versionId,
      payload: payload,
      attachments: const [],
      attempted: false,
      status: 'queued',
    );
  }

  @override
  Future<void> syncDraft(String localId) async {
    expect(draft, isNotNull);
    String? error;
    var status = 'completed';
    try {
      if (!created) {
        await repository.createIssue(
          draft!.payload['project_id'] as int,
          draft!.payload,
        );
        created = true;
      }
      if (snapshot && !snapshotSent) {
        await repository.attachSnapshot(
          repository.issueValue,
          Uint8List(0),
          idempotencyKey: 'persisted-snapshot',
        );
        snapshotSent = true;
      }
    } catch (failure) {
      status = 'queued';
      error = failure.toString();
    }
    draft = BimIssueDraft(
      localId: draft!.localId,
      versionId: draft!.versionId,
      payload: draft!.payload,
      attachments: const [],
      attempted: true,
      status: status,
      serverId: created ? repository.issueValue.id : null,
      lastError: error,
    );
    if (!synced.isCompleted) synced.complete();
  }
}
