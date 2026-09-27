import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_request_detail_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';

class _FakeSiteRequestsRepository extends SiteRequestsRepository {
  _FakeSiteRequestsRepository(this.request, {List<Map<String, dynamic>>? files})
    : files = files ?? [],
      super(Dio());

  final SiteRequestModel request;
  final List<Map<String, dynamic>> files;
  final List<int> deletedFileIds = [];

  @override
  Future<SiteRequestModel> fetchSiteRequestDetails(int id) async {
    return request;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFiles(int requestId) async {
    return List<Map<String, dynamic>>.from(files);
  }

  @override
  Future<void> deleteFile(int requestId, int fileId) async {
    deletedFileIds.add(fileId);
    files.removeWhere((file) => file['id'] == fileId);
  }
}

final _request =
    SiteRequestModel()
      ..serverId = 1001
      ..title = 'Срочно нужен бетон'
      ..description = 'Нужно закрыть подачу бетона до конца смены.'
      ..notes = 'Подтвердить время поставки до 14:00.'
      ..status = 'draft'
      ..statusLabel = 'Черновик'
      ..priority = 'urgent'
      ..priorityLabel = 'Срочно'
      ..requestType = 'material_request'
      ..requestTypeLabel = 'Материалы'
      ..materialName = 'Бетон М300'
      ..materialQuantity = 12
      ..materialUnit = 'м3'
      ..projectId = 15
      ..projectName = 'Дом 300м Царево'
      ..canBeEdited = true
      ..userName = 'Иван Петров'
      ..assignedUserName = 'Снабжение'
      ..requiredDate = '2026-03-15'
      ..groupTitle = 'Материалы на фундамент'
      ..groupRequestCount = 2
      ..groupItems = const [
        SiteRequestGroupItem(
          id: 1001,
          title: 'Бетон М300',
          status: 'draft',
          statusLabel: 'Черновик',
          requestType: 'material_request',
          requestTypeLabel: 'Материалы',
          materialName: 'Бетон М300',
          materialQuantity: 12,
          materialUnit: 'м3',
          assignedUserName: 'Снабжение',
          isCurrent: true,
        ),
        SiteRequestGroupItem(
          id: 1002,
          title: 'Арматура А500',
          status: 'pending',
          statusLabel: 'На согласовании',
          requestType: 'material_request',
          requestTypeLabel: 'Материалы',
          materialName: 'Арматура А500',
          materialQuantity: 2,
          materialUnit: 'т',
        ),
      ]
      ..history = const [
        SiteRequestHistoryEntry(
          id: 1,
          action: 'created',
          actionLabel: 'Создана',
          userName: 'Иван Петров',
        ),
        SiteRequestHistoryEntry(
          id: 2,
          action: 'status_changed',
          actionLabel: 'Статус изменен',
          userName: 'Руководитель проекта',
          oldStatusLabel: 'Черновик',
          newStatusLabel: 'На согласовании',
          notes: 'Нужно ускорить поставку.',
        ),
      ]
      ..availableTransitions = const [
        SiteRequestTransition(status: 'pending'),
        SiteRequestTransition(status: 'cancelled'),
      ]
      ..createdAt = DateTime(2026, 3, 14);

void main() {
  Widget createWidget({
    SiteRequestModel? request,
    _FakeSiteRequestsRepository? repository,
    double textScaleFactor = 1,
  }) {
    final fakeRepository =
        repository ?? _FakeSiteRequestsRepository(request ?? _request);
    return ProviderScope(
      overrides: [
        siteRequestsRepositoryProvider.overrideWithValue(fakeRepository),
        siteRequestDetailProvider.overrideWith(
          (ref, id) => SiteRequestDetailNotifier(fakeRepository, ref, id),
        ),
      ],
      child: TickerMode(
        enabled: false,
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
                child: child!,
              ),
          home: SiteRequestDetailScreen(id: 1001),
        ),
      ),
    );
  }

  testWidgets('показывает ключевой контекст, группу и историю по заявке', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Срочно нужен бетон'), findsOneWidget);
    expect(find.text('Срочная заявка'), findsOneWidget);
    expect(find.text('Контекст заявки'), findsOneWidget);
    expect(find.text('Участники'), findsOneWidget);
    expect(find.text('Редактировать заявку'), findsOneWidget);
    expect(find.text('Состав заявки'), findsOneWidget);
    expect(find.text('История обработки'), findsOneWidget);
    expect(find.text('Отправить на согласование'), findsOneWidget);
    expect(find.text('Бетон М300'), findsWidgets);
    expect(find.text('Арматура А500'), findsOneWidget);
    expect(find.text('Дом 300м Царево'), findsOneWidget);
    expect(find.text('Иван Петров'), findsWidgets);
    expect(find.text('Подтвердить время поставки до 14:00.'), findsOneWidget);
  });

  testWidgets('не показывает действия, если backend не прислал переходы', (
    tester,
  ) async {
    final requestWithoutTransitions =
        SiteRequestModel()
          ..serverId = 1002
          ..title = 'Арматура'
          ..status = 'draft'
          ..statusLabel = 'Черновик'
          ..priority = 'medium'
          ..priorityLabel = 'Средний'
          ..requestType = 'material_request'
          ..requestTypeLabel = 'Материалы'
          ..projectId = 15
          ..projectName = 'Дом 300м Царево';

    await tester.pumpWidget(createWidget(request: requestWithoutTransitions));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Арматура'), findsOneWidget);
    expect(find.text('Отправить на согласование'), findsNothing);
    expect(find.text('Отменить заявку'), findsNothing);
  });

  testWidgets('действия оставляют место деталям при крупном шрифте', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final request =
        SiteRequestModel()
          ..serverId = 1001
          ..title = 'Тестовая заявка'
          ..status = 'pending'
          ..statusLabel = 'Ожидает обработки'
          ..priority = 'medium'
          ..priorityLabel = 'Средний'
          ..requestType = 'material_request'
          ..requestTypeLabel = 'Материалы'
          ..projectId = 15
          ..projectName = 'Тестовый'
          ..availableTransitions = const [
            SiteRequestTransition(status: 'approved'),
            SiteRequestTransition(status: 'in_review'),
            SiteRequestTransition(status: 'cancelled'),
            SiteRequestTransition(status: 'rejected'),
          ];

    await tester.pumpWidget(
      createWidget(request: request, textScaleFactor: 1.3),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.getSize(find.byType(SingleChildScrollView).first).height,
      greaterThan(500),
    );
    expect(find.text('Согласовать'), findsOneWidget);
    await tester.tap(find.byTooltip('Другие действия'));
    await tester.pumpAndSettle();
    expect(find.text('Взять на рассмотрение'), findsOneWidget);
    expect(find.text('Отменить заявку'), findsOneWidget);
    expect(find.text('Отклонить'), findsOneWidget);
  });

  testWidgets('контекст заявки читабелен на узком экране', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final request =
        SiteRequestModel()
          ..serverId = 1001
          ..title = 'Проверка заявки'
          ..status = 'pending'
          ..statusLabel = 'Ожидает обработки'
          ..priority = 'medium'
          ..priorityLabel = 'Средний'
          ..requestType = 'material_request'
          ..requestTypeLabel = 'Заявка на материалы'
          ..projectId = 15
          ..projectName = 'Тестовый';

    await tester.pumpWidget(
      createWidget(request: request, textScaleFactor: 1.3),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.scrollUntilVisible(
      find.text('Объект'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Тестовый')).dy,
      greaterThan(tester.getTopLeft(find.text('Объект')).dy),
    );
    expect(tester.getSize(find.text('Тестовый')).width, greaterThan(100));
  });

  testWidgets('после удаления файла список перечитывается', (tester) async {
    final repository = _FakeSiteRequestsRepository(
      _request,
      files: [
        {'id': 11, 'name': 'qa-photo.jpg', 'can_delete': true},
      ],
    );

    await tester.pumpWidget(createWidget(repository: repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.scrollUntilVisible(
      find.text('qa-photo.jpg'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить файл'));
    await tester.pumpAndSettle();

    expect(repository.deletedFileIds, [11]);
    expect(find.text('К заявке пока не приложены файлы.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
