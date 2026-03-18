import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_meta_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_form_screen.dart';

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  _FakeProjectsNotifier(Project project) : super(_FakeProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
      error: null,
    );
  }
}

class _FakeSiteRequestsRepository extends SiteRequestsRepository {
  _FakeSiteRequestsRepository() : super(Dio());

  @override
  Future<SiteRequestModel> createSiteRequest(Map<String, dynamic> data) async {
    return SiteRequestModel()
      ..serverId = 1004
      ..title = data['title']?.toString() ?? ''
      ..status = 'draft'
      ..priority = data['priority']?.toString() ?? 'medium'
      ..requestType = data['request_type']?.toString() ?? 'material_request';
  }

  @override
  Future<SiteRequestModel> updateSiteRequest(
    int id,
    Map<String, dynamic> data,
  ) async {
    return SiteRequestModel()
      ..serverId = id
      ..title = data['title']?.toString() ?? ''
      ..status = 'draft'
      ..priority = data['priority']?.toString() ?? 'medium'
      ..requestType = data['request_type']?.toString() ?? 'material_request';
  }

  @override
  Future<SiteRequestModel> updateSiteRequestGroup(
    int groupId,
    Map<String, dynamic> data,
  ) async {
    return SiteRequestModel()
      ..serverId = 1001
      ..title = data['title']?.toString() ?? ''
      ..status = 'draft'
      ..priority = data['priority']?.toString() ?? 'medium'
      ..requestType = data['request_type']?.toString() ?? 'material_request'
      ..siteRequestGroupId = groupId;
  }
}

class _FakeSiteRequestsNotifier extends SiteRequestsNotifier {
  _FakeSiteRequestsNotifier()
      : super(_FakeSiteRequestsRepository(), initialProjectId: 15) {
    state = SiteRequestsState(
      isLoading: false,
      requests: const [],
      currentPage: 1,
      hasMore: false,
      error: null,
      statusFilter: null,
      projectFilter: 15,
      scope: SiteRequestsScope.own,
    );
  }

  @override
  Future<void> loadRequests({bool refresh = false}) async {}
}

void main() {
  Project buildProject() {
    return Project()
      ..serverId = 15
      ..name = 'Дом 300м Царево'
      ..address = 'Лесная улица, 15'
      ..myRole = 'Прораб';
  }

  SiteRequestModel buildEditableGroupRequest() {
    return SiteRequestModel()
      ..serverId = 1001
      ..title = 'Материалы на фундамент'
      ..description = 'Нужно обновить поставку'
      ..status = 'draft'
      ..priority = 'medium'
      ..requestType = 'material_request'
      ..projectId = 15
      ..projectName = 'Дом 300м Царево'
      ..siteRequestGroupId = 77
      ..groupRequestCount = 2
      ..canBeEdited = true
      ..groupItems = const [
        SiteRequestGroupItem(
          id: 1001,
          title: 'Бетон М300',
          status: 'draft',
          statusLabel: 'Черновик',
          requestType: 'material_request',
          materialName: 'Бетон М300',
          materialQuantity: 12,
          materialUnit: 'м3',
          notes: 'Утреннее окно',
          isCurrent: true,
        ),
        SiteRequestGroupItem(
          id: 1002,
          title: 'Арматура А500',
          status: 'draft',
          statusLabel: 'Черновик',
          requestType: 'material_request',
          materialName: 'Арматура А500',
          materialQuantity: 2,
          materialUnit: 'т',
        ),
      ];
  }

  Widget createWidget({SiteRequestModel? initialRequest}) {
    final project = buildProject();
    const meta = {
      'request_types': [
        {'value': 'material_request', 'label': 'Материалы'},
        {'value': 'personnel_request', 'label': 'Персонал'},
        {'value': 'equipment_request', 'label': 'Техника'},
      ],
      'units': [
        {'short_name': 'м3'},
        {'short_name': 'шт'},
        {'short_name': 'т'},
      ],
      'personnel_types': [
        {'value': 'masons', 'label': 'Каменщики'},
      ],
      'equipment_types': [
        {'value': 'crane', 'label': 'Автокран'},
      ],
    };

    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) => _FakeProjectsNotifier(project)),
        siteRequestsProvider.overrideWith((ref) => _FakeSiteRequestsNotifier()),
        siteRequestsRepositoryProvider.overrideWith(
          (ref) => _FakeSiteRequestsRepository(),
        ),
        siteRequestsMetaProvider.overrideWith((ref) async => meta),
      ],
      child: TickerMode(
        enabled: false,
        child: MaterialApp(
          home: SiteRequestFormScreen(initialRequest: initialRequest),
        ),
      ),
    );
  }

  testWidgets('показывает контекст объекта и переключает секции формы', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Текущий объект'), findsOneWidget);
    expect(find.text('Дом 300м Царево'), findsOneWidget);
    expect(find.text('Тип заявки'), findsOneWidget);
    expect(find.text('Приоритет'), findsOneWidget);
    expect(find.text('Детали материала'), findsOneWidget);
    expect(find.text('Наименование материала'), findsOneWidget);
    expect(find.text('+ Добавить материал'), findsOneWidget);

    await tester.ensureVisible(find.text('+ Добавить материал'));
    await tester.pump();
    await tester.tap(find.text('+ Добавить материал'));
    await tester.pump();

    expect(find.text('Материал 2'), findsOneWidget);

    await tester.ensureVisible(find.text('Персонал'));
    await tester.pump();
    await tester.tap(find.text('Персонал'));
    await tester.pump();

    expect(find.text('Детали персонала'), findsOneWidget);
    expect(find.text('Количество человек'), findsOneWidget);
    expect(find.text('Наименование материала'), findsNothing);

    await tester.ensureVisible(find.text('Техника'));
    await tester.pump();
    await tester.tap(find.text('Техника'));
    await tester.pump();

    expect(find.text('Детали техники'), findsOneWidget);
    expect(find.text('Тип техники'), findsOneWidget);
    expect(find.text('Количество человек'), findsNothing);
  });

  testWidgets('подставляет существующие позиции при редактировании группы материалов', (tester) async {
    await tester.pumpWidget(
      createWidget(initialRequest: buildEditableGroupRequest()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Редактирование заявки'), findsOneWidget);
    expect(find.text('Материал 1'), findsOneWidget);
    expect(find.text('Материал 2'), findsOneWidget);
    expect(find.text('Бетон М300'), findsWidgets);
    expect(find.text('Арматура А500'), findsWidgets);
    expect(find.text('Сохранить группу'), findsOneWidget);
  });
}
