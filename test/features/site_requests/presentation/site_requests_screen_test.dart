import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_hub_repository.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/domain/knowledge_hub_provider.dart';
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
  _FakeProjectsNotifier(Project? project) : super(_FakeProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: project == null ? const [] : [project],
      selectedProject: project,
      error: null,
    );
  }

  @override
  void selectProject(Project? project) {
    state = ProjectsState(
      isLoading: false,
      projects: project == null ? const [] : [project],
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
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    return _requests;
  }
}

class _SearchFlowSiteRequestsRepository extends SiteRequestsRepository {
  _SearchFlowSiteRequestsRepository(
    this.requests, {
    this.offlineSearch = false,
    this.delaySearch = false,
  }) : super(Dio());

  final List<SiteRequestModel> requests;
  final bool offlineSearch;
  final bool delaySearch;
  final searches = <String?>[];
  final delayedSearch = Completer<List<SiteRequestModel>>();

  @override
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) {
    searches.add(search);
    if (search == null) {
      return Future.value(requests);
    }
    if (offlineSearch) {
      return Future.error(const ApiException('Нет связи.'));
    }
    if (delaySearch) {
      return delayedSearch.future;
    }
    return Future.value(
      requests
          .where(
            (request) =>
                request.title.toLowerCase().contains(search.toLowerCase()),
          )
          .toList(),
    );
  }
}

class _FakeSiteRequestsNotifier extends SiteRequestsNotifier {
  _FakeSiteRequestsNotifier({
    required List<SiteRequestModel> requests,
    required SiteRequestsScope scope,
    bool permissionDenied = false,
    String? error,
    bool isLoading = false,
  }) : super(
         _FakeSiteRequestsRepository(),
         initialProjectId: 15,
         initialScope: scope,
       ) {
    state = SiteRequestsState(
      isLoading: isLoading,
      requests: requests,
      currentPage: 2,
      hasMore: false,
      permissionDenied: permissionDenied,
      error: error,
      statusFilter: null,
      projectFilter: 15,
      scope: scope,
    );
  }

  final statusChanges = <(int, String, String?)>[];
  bool failNextStatusChange = false;
  Completer<void>? pendingStatusChange;

  void markRefreshing() {
    state = state.copyWith(isLoading: true);
  }

  @override
  Future<void> loadRequests({bool refresh = false}) async {}

  @override
  Future<void> changeStatus(
    int requestId,
    String status, {
    String? notes,
  }) async {
    statusChanges.add((requestId, status, notes));
    final pending = pendingStatusChange;
    pendingStatusChange = null;
    if (pending != null) await pending.future;
    if (failNextStatusChange) {
      failNextStatusChange = false;
      throw const ApiException('Нет подключения. Повторите попытку.');
    }
  }
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
    bool permissionDenied = false,
    String? error,
    bool isLoading = false,
    bool hasProject = true,
    _FakeProjectsNotifier? projectsNotifier,
    _FakeSiteRequestsNotifier? requestsNotifier,
  }) {
    final project = hasProject ? buildProject() : null;
    final resolvedRequests = requests ?? _requests;
    final resolvedProjectsNotifier =
        projectsNotifier ?? _FakeProjectsNotifier(project);
    final resolvedRequestsNotifier =
        requestsNotifier ??
        _FakeSiteRequestsNotifier(
          requests: resolvedRequests,
          scope: scope,
          permissionDenied: permissionDenied,
          error: error,
          isLoading: isLoading,
        );

    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) => resolvedProjectsNotifier),
        knowledgeContextHelpProvider.overrideWith(
          (ref, params) async => const KnowledgeContextHelpModel(
            primary: null,
            suggested: [],
            context: {},
          ),
        ),
        siteRequestsProvider.overrideWith((ref) => resolvedRequestsNotifier),
      ],
      child: TickerMode(
        enabled: false,
        child: MaterialApp(home: SiteRequestsScreen(scope: scope)),
      ),
    );
  }

  Widget createSearchFlowWidget(_SearchFlowSiteRequestsRepository repository) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _FakeProjectsNotifier(buildProject()),
        ),
        knowledgeContextHelpProvider.overrideWith(
          (ref, params) async => const KnowledgeContextHelpModel(
            primary: null,
            suggested: [],
            context: {},
          ),
        ),
        siteRequestsProvider.overrideWith(
          (ref) => SiteRequestsNotifier(repository, initialProjectId: 15),
        ),
      ],
      child: TickerMode(
        enabled: false,
        child: MaterialApp(
          home: SiteRequestsScreen(scope: SiteRequestsScope.all),
        ),
      ),
    );
  }

  testWidgets('показывает заявки и фильтрует их по срочности и поиску', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pump();

    expect(find.text('Ждут решения'), findsOneWidget);
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

  testWidgets('до загрузки не показывает нулевой счётчик заявок', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget(requests: const [], isLoading: true));
    await tester.pump();

    expect(find.text('Загружаем заявки'), findsOneWidget);
    expect(find.textContaining('Всего заявок: 0'), findsNothing);
    expect(find.text('Найдено: 0 из 0'), findsNothing);
  });

  testWidgets('при смене объекта скрывает строки предыдущего объекта', (
    tester,
  ) async {
    final previousRequest = _buildRequest(
      serverId: 1501,
      title: 'Заявка прежнего объекта',
      status: 'pending',
      statusLabel: 'На согласовании',
      priority: 'medium',
      priorityLabel: 'Средний',
      requestType: 'material_request',
      requestTypeLabel: 'Материалы',
      createdAt: DateTime(2026, 3, 14),
    );
    final nextProject =
        Project()
          ..serverId = 16
          ..name = 'Новый объект'
          ..myRole = 'Прораб';
    final projectsNotifier = _FakeProjectsNotifier(buildProject());
    final requestsNotifier = _FakeSiteRequestsNotifier(
      requests: [previousRequest],
      scope: SiteRequestsScope.all,
    );

    await tester.pumpWidget(
      createWidget(
        scope: SiteRequestsScope.all,
        projectsNotifier: projectsNotifier,
        requestsNotifier: requestsNotifier,
      ),
    );
    await tester.pump();
    expect(find.text('Заявка прежнего объекта'), findsOneWidget);

    requestsNotifier.markRefreshing();
    await tester.pump();
    projectsNotifier.selectProject(nextProject);
    await tester.pump();
    await tester.pump();

    expect(find.text('Новый объект'), findsOneWidget);
    expect(find.text('Заявка прежнего объекта'), findsNothing);
  });

  testWidgets('поле поиска и клавиатура остаются при медленном пустом ответе', (
    tester,
  ) async {
    final repository = _SearchFlowSiteRequestsRepository(
      _requests,
      delaySearch: true,
    );
    await tester.pumpWidget(createSearchFlowWidget(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'нет совпадений');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(repository.searches, [null, 'нет совпадений']);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );

    repository.delayedSearch.complete(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Очистить поиск'), findsOneWidget);
  });

  testWidgets('без сети поиск и очистка сохраняют строки текущего объекта', (
    tester,
  ) async {
    final repository = _SearchFlowSiteRequestsRepository(
      _requests,
      offlineSearch: true,
    );
    await tester.pumpWidget(createSearchFlowWidget(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField).first, 'бетон');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Найдено: 1 из 3'), findsOneWidget);
    expect(find.text('Срочно нужен бетон'), findsOneWidget);
    expect(find.text('Вывод бригады каменщиков'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Найдено: 3 из 3'), findsOneWidget);
    expect(find.text('Срочно нужен бетон'), findsOneWidget);
  });

  testWidgets('одобренная заявка ещё не считается работой', (tester) async {
    final approvedRequest = _buildRequest(
      serverId: 3001,
      title: 'Одобрена закупка',
      status: 'approved',
      statusLabel: 'Одобрена',
      priority: 'medium',
      priorityLabel: 'Средний',
      requestType: 'material_request',
      requestTypeLabel: 'Материалы',
      createdAt: DateTime(2026, 3, 12),
    );
    await tester.pumpWidget(createWidget(requests: [approvedRequest]));
    await tester.pump();

    expect(find.text('Всего заявок: 1. Активных в работе: 0.'), findsOneWidget);
  });

  testWidgets('в режиме согласования показывает быстрые действия по workflow', (
    tester,
  ) async {
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
        transitions: const [SiteRequestTransition(status: 'in_review')],
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
        transitions: const [
          SiteRequestTransition(status: 'approved'),
          SiteRequestTransition(status: 'rejected'),
        ],
      ),
    ];

    await tester.pumpWidget(
      createWidget(
        scope: SiteRequestsScope.approvals,
        requests: approvalRequests,
      ),
    );
    await tester.pump();

    expect(find.text('Согласование'), findsOneWidget);
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

  testWidgets(
    'для черновика показывает рабочие действия из available transitions',
    (tester) async {
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
        createWidget(scope: SiteRequestsScope.own, requests: draftRequests),
      );
      await tester.pump();

      expect(find.text('Отправить'), findsOneWidget);
      expect(find.text('Отменить'), findsOneWidget);
    },
  );

  testWidgets('закрытие диалога отмены не отправляет переход', (tester) async {
    final request = _buildRequest(
      serverId: 3101,
      title: 'Материалы на плиту',
      status: 'draft',
      statusLabel: 'Черновик',
      priority: 'medium',
      priorityLabel: 'Средний',
      requestType: 'material_request',
      requestTypeLabel: 'Материалы',
      createdAt: DateTime(2026, 3, 14),
      transitions: const [SiteRequestTransition(status: 'cancelled')],
    );
    final notifier = _FakeSiteRequestsNotifier(
      requests: [request],
      scope: SiteRequestsScope.own,
    );
    await tester.pumpWidget(
      createWidget(scope: SiteRequestsScope.own, requestsNotifier: notifier),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Отменить'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Отменить'));
    await tester.pump();

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Назад'));
    await tester.pumpAndSettle();
    expect(notifier.statusChanges, isEmpty);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(notifier.statusChanges, isEmpty);
  });

  testWidgets('ошибка отмены сохраняет комментарий для явного повтора', (
    tester,
  ) async {
    final request = _buildRequest(
      serverId: 3102,
      title: 'Материалы на плиту',
      status: 'draft',
      statusLabel: 'Черновик',
      priority: 'medium',
      priorityLabel: 'Средний',
      requestType: 'material_request',
      requestTypeLabel: 'Материалы',
      createdAt: DateTime(2026, 3, 14),
      transitions: const [SiteRequestTransition(status: 'cancelled')],
    );
    final notifier = _FakeSiteRequestsNotifier(
      requests: [request],
      scope: SiteRequestsScope.own,
    )..failNextStatusChange = true;
    await tester.pumpWidget(
      createWidget(scope: SiteRequestsScope.own, requestsNotifier: notifier),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Отменить'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Отменить'));
    await tester.pump();

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('site-request-inline-transition-comment')),
      'Не удалось договориться',
    );
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();

    expect(find.text('Нет подключения. Повторите попытку.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(
              const ValueKey('site-request-inline-transition-comment'),
            ),
          )
          .controller!
          .text,
      'Не удалось договориться',
    );
    expect(notifier.statusChanges, [
      (3102, 'cancelled', 'Не удалось договориться'),
    ]);

    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(find.text('Комментарий к отмене'), findsNothing);
    expect(notifier.statusChanges, [
      (3102, 'cancelled', 'Не удалось договориться'),
      (3102, 'cancelled', 'Не удалось договориться'),
    ]);
  });

  testWidgets('действие заявки и отправка комментария блокируют повторы', (
    tester,
  ) async {
    final request = _buildRequest(
      serverId: 3103,
      title: 'Материалы на плиту',
      status: 'draft',
      statusLabel: 'Черновик',
      priority: 'medium',
      priorityLabel: 'Средний',
      requestType: 'material_request',
      requestTypeLabel: 'Материалы',
      createdAt: DateTime(2026, 3, 14),
      transitions: const [
        SiteRequestTransition(status: 'pending'),
        SiteRequestTransition(status: 'cancelled'),
      ],
    );
    final notifier = _FakeSiteRequestsNotifier(
      requests: [request],
      scope: SiteRequestsScope.own,
    );
    await tester.pumpWidget(
      createWidget(scope: SiteRequestsScope.own, requestsNotifier: notifier),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Отправить'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Отправить'));
    await tester.pump();

    final directAction = Completer<void>();
    notifier.pendingStatusChange = directAction;
    await tester.tap(find.text('Отправить'));
    await tester.pump();
    await tester.tap(find.text('Отправить'), warnIfMissed: false);
    await tester.pump();
    expect(notifier.statusChanges, [(3103, 'pending', null)]);
    directAction.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('отправка комментария блокирует повтор и закрытие до ACK', (
    tester,
  ) async {
    final request = _buildRequest(
      serverId: 3104,
      title: 'Материалы на плиту',
      status: 'draft',
      statusLabel: 'Черновик',
      priority: 'medium',
      priorityLabel: 'Средний',
      requestType: 'material_request',
      requestTypeLabel: 'Материалы',
      createdAt: DateTime(2026, 3, 14),
      transitions: const [SiteRequestTransition(status: 'cancelled')],
    );
    final notifier = _FakeSiteRequestsNotifier(
      requests: [request],
      scope: SiteRequestsScope.own,
    );
    await tester.pumpWidget(
      createWidget(scope: SiteRequestsScope.own, requestsNotifier: notifier),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Отменить'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Отменить'));
    await tester.pump();
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    final cancelAction = Completer<void>();
    notifier.pendingStatusChange = cancelAction;
    await tester.enterText(
      find.byKey(const ValueKey('site-request-inline-transition-comment')),
      'Повтор не нужен',
    );
    await tester.tap(find.text('Подтвердить'));
    await tester.pump();
    expect(find.text('Сохраняем…'), findsOneWidget);
    await tester.tap(find.text('Сохраняем…'), warnIfMissed: false);
    await tester.tap(find.text('Назад'), warnIfMissed: false);
    await tester.pump();
    expect(notifier.statusChanges, [(3104, 'cancelled', 'Повтор не нужен')]);
    expect(find.text('Комментарий к отмене'), findsOneWidget);

    cancelAction.complete();
    await tester.pumpAndSettle();
    expect(find.text('Комментарий к отмене'), findsNothing);
  });

  testWidgets('не придумывает быстрые действия без available transitions', (
    tester,
  ) async {
    final requests = [
      _buildRequest(
        serverId: 4001,
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
    ];

    await tester.pumpWidget(
      createWidget(scope: SiteRequestsScope.approvals, requests: requests),
    );
    await tester.pump();

    expect(find.text('Арматура на плиту'), findsOneWidget);
    expect(find.text('Взять в рассмотрение'), findsNothing);
  });

  testWidgets('показывает состояние недостаточных прав отдельным экраном', (
    tester,
  ) async {
    await tester.pumpWidget(
      createWidget(
        requests: const [],
        permissionDenied: true,
        error: 'Недостаточно прав для просмотра заявок.',
      ),
    );
    await tester.pump();

    expect(find.text('Нет доступа к заявкам объекта'), findsOneWidget);
    expect(
      find.text('Недостаточно прав для просмотра заявок.'),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('не показывает создание заявки, пока объект не выбран', (
    tester,
  ) async {
    await tester.pumpWidget(
      createWidget(requests: const [], hasProject: false),
    );
    await tester.pump();

    expect(find.text('Объект не выбран'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
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
  List<SiteRequestTransition> transitions = const [],
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
    ..availableTransitions = transitions
    ..createdAt = createdAt;
}
