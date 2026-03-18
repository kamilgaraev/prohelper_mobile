import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_requests_screen.dart';

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
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    return _requests;
  }
}

class _FakeSiteRequestsNotifier extends SiteRequestsNotifier {
  _FakeSiteRequestsNotifier({
    required List<SiteRequestModel> requests,
    required SiteRequestsScope scope,
  }) : super(_FakeSiteRequestsRepository(), initialProjectId: 15, initialScope: scope) {
    state = SiteRequestsState(
      isLoading: false,
      requests: requests,
      currentPage: 2,
      hasMore: false,
      error: null,
      statusFilter: null,
      projectFilter: 15,
      scope: scope,
    );
  }

  @override
  Future<void> loadRequests({bool refresh = false}) async {}

  @override
  Future<void> changeStatus(
    int requestId,
    String status, {
    String? notes,
  }) async {}
}

final _requests = [
  _buildRequest(
    serverId: 1001,
    title: 'Срочно нужен бетон',
    status: 'pending',
    statusLabel: 'На согласовании',
    priority: 'urgent',
    priorityLabel: 'Срочно',
    requestType: 'material_request',
    requestTypeLabel: 'Материалы',
    materialName: 'Бетон М300',
    materialQuantity: 12,
    materialUnit: 'м3',
    createdAt: DateTime(2026, 3, 14),
  ),
  _buildRequest(
    serverId: 1002,
    title: 'Вывод бригады каменщиков',
    status: 'in_progress',
    statusLabel: 'В работе',
    priority: 'medium',
    priorityLabel: 'Средний',
    requestType: 'personnel_request',
    requestTypeLabel: 'Персонал',
    personnelTypeLabel: 'Каменщики',
    personnelCount: 6,
    createdAt: DateTime(2026, 3, 13),
  ),
  _buildRequest(
    serverId: 1003,
    title: 'Автокран на разгрузку',
    status: 'completed',
    statusLabel: 'Закрыта',
    priority: 'low',
    priorityLabel: 'Низкий',
    requestType: 'equipment_request',
    requestTypeLabel: 'Техника',
    equipmentTypeLabel: 'Автокран 25 т',
    createdAt: DateTime(2026, 3, 12),
  ),
];

void main() {
  Project buildProject() {
    return Project()
      ..serverId = 15
      ..name = 'Дом 300м Царево'
      ..address = 'Лесная улица, 15'
      ..myRole = 'Прораб';
  }

  Widget createWidget({
    SiteRequestsScope scope = SiteRequestsScope.own,
    List<SiteRequestModel>? requests,
  }) {
    final project = buildProject();
    final resolvedRequests = requests ?? _requests;

    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) => _FakeProjectsNotifier(project)),
        siteRequestsProvider.overrideWith(
          (ref) => _FakeSiteRequestsNotifier(requests: resolvedRequests, scope: scope),
        ),
      ],
      child: TickerMode(
        enabled: false,
        child: MaterialApp(
          home: SiteRequestsScreen(scope: scope),
        ),
      ),
    );
  }

  testWidgets('показывает заявки и фильтрует их по срочности и поиску', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pump();

    expect(find.text('Есть заявки, требующие реакции'), findsOneWidget);
    expect(find.text('Найдено: 3 из 3'), findsOneWidget);
    expect(find.text('Срочные'), findsOneWidget);

    await tester.ensureVisible(find.text('Срочные'));
    await tester.pump();
    await tester.tap(find.text('Срочные'));
    await tester.pump();

    expect(find.text('Найдено: 1 из 3'), findsOneWidget);
    expect(find.text('Срочно нужен бетон'), findsOneWidget);
    expect(find.text('Вывод бригады каменщиков'), findsNothing);
    expect(find.text('Автокран на разгрузку'), findsNothing);

    await tester.ensureVisible(find.text('Все'));
    await tester.pump();
    await tester.tap(find.text('Все'));
    await tester.pump();

    expect(find.text('Найдено: 3 из 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Бетон');
    await tester.pump();

    expect(find.text('Найдено: 1 из 3'), findsOneWidget);
    expect(find.text('Срочно нужен бетон'), findsOneWidget);
    expect(find.text('Вывод бригады каменщиков'), findsNothing);
    expect(find.text('Автокран на разгрузку'), findsNothing);
  });

  testWidgets('в режиме согласования показывает быстрые действия по workflow', (tester) async {
    final approvalRequests = [
      _buildRequest(
        serverId: 2001,
        title: 'Арматура на плиту',
        status: 'pending',
        statusLabel: 'На согласовании',
        priority: 'high',
        priorityLabel: 'Высокий',
        requestType: 'material_request',
        requestTypeLabel: 'Материалы',
        materialName: 'Арматура А500',
        materialQuantity: 3,
        materialUnit: 'т',
        createdAt: DateTime(2026, 3, 14),
      ),
      _buildRequest(
        serverId: 2002,
        title: 'Кран на монтаж',
        status: 'in_review',
        statusLabel: 'На рассмотрении',
        priority: 'medium',
        priorityLabel: 'Средний',
        requestType: 'equipment_request',
        requestTypeLabel: 'Техника',
        equipmentTypeLabel: 'Автокран 25 т',
        createdAt: DateTime(2026, 3, 13),
      ),
    ];

    await tester.pumpWidget(
      createWidget(
        scope: SiteRequestsScope.approvals,
        requests: approvalRequests,
      ),
    );
    await tester.pump();

    expect(find.text('Нуждаются в рассмотрении'), findsOneWidget);
    expect(find.text('Взять в рассмотрение'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Кран на монтаж'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Согласовать'), findsOneWidget);
    expect(find.text('Отклонить'), findsOneWidget);
  });

  testWidgets('для черновика показывает рабочие действия из available transitions', (tester) async {
    final draftRequests = [
      _buildRequest(
        serverId: 3001,
        title: 'Материалы на плиту',
        status: 'draft',
        statusLabel: 'Черновик',
        priority: 'medium',
        priorityLabel: 'Средний',
        requestType: 'material_request',
        requestTypeLabel: 'Материалы',
        materialName: 'Щебень 20-40',
        materialQuantity: 8,
        materialUnit: 'м3',
        createdAt: DateTime(2026, 3, 14),
      )
        ..availableTransitions = const [
          SiteRequestTransition(status: 'pending'),
          SiteRequestTransition(status: 'cancelled'),
        ],
    ];

    await tester.pumpWidget(
      createWidget(
        scope: SiteRequestsScope.own,
        requests: draftRequests,
      ),
    );
    await tester.pump();

    expect(find.text('Отправить'), findsOneWidget);
    expect(find.text('Отменить'), findsOneWidget);
  });
}

SiteRequestModel _buildRequest({
  required int serverId,
  required String title,
  required String status,
  required String statusLabel,
  required String priority,
  required String priorityLabel,
  required String requestType,
  required String requestTypeLabel,
  String? materialName,
  double? materialQuantity,
  String? materialUnit,
  String? personnelTypeLabel,
  int? personnelCount,
  String? equipmentTypeLabel,
  required DateTime createdAt,
}) {
  return SiteRequestModel()
    ..serverId = serverId
    ..title = title
    ..status = status
    ..statusLabel = statusLabel
    ..priority = priority
    ..priorityLabel = priorityLabel
    ..requestType = requestType
    ..requestTypeLabel = requestTypeLabel
    ..materialName = materialName
    ..materialQuantity = materialQuantity
    ..materialUnit = materialUnit
    ..personnelTypeLabel = personnelTypeLabel
    ..personnelCount = personnelCount
    ..equipmentTypeLabel = equipmentTypeLabel
    ..projectId = 15
    ..projectName = 'Дом 300м Царево'
    ..createdAt = createdAt;
}
