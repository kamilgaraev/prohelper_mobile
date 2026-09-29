import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_model.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_repository.dart';
import 'package:prohelpers_mobile/features/module_companions/domain/companion_module_provider.dart';
import 'package:prohelpers_mobile/features/module_companions/presentation/companion_module_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

import '../companion_module_test_data.dart';

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  _FakeProjectsNotifier({bool hasSelectedProject = true})
    : super(_FakeProjectsRepository()) {
    final project =
        Project()
          ..serverId = 9
          ..name = 'Tower A'
          ..address = 'Site';
    state = ProjectsState(
      isLoading: false,
      projects: hasSelectedProject ? [project] : const [],
      selectedProject: hasSelectedProject ? project : null,
    );
  }
}

class _FakeCompanionRepository extends CompanionModuleRepository {
  _FakeCompanionRepository() : super(Dio());
}

class _FakeCompanionNotifier extends CompanionModuleNotifier {
  _FakeCompanionNotifier({
    String moduleSlug = 'contract-management',
    String? itemStatus,
    String? statusLabel,
    String? itemTitle,
    Map<String, dynamic>? detailOverride,
    bool requiresComment = false,
    bool relatedRequiresComment = false,
  }) : _moduleSlug = moduleSlug,
       _itemStatus = itemStatus,
       _statusLabel = statusLabel,
       _itemTitle = itemTitle,
       _detailOverride = detailOverride,
       _requiresComment = requiresComment,
       _relatedRequiresComment = relatedRequiresComment,
       super(_FakeCompanionRepository(), moduleSlug) {
    _setLoadedState(moduleSlug: moduleSlug);
  }

  final String _moduleSlug;
  final String? _itemStatus;
  final String? _statusLabel;
  final String? _itemTitle;
  final Map<String, dynamic>? _detailOverride;
  final bool _requiresComment;
  final bool _relatedRequiresComment;
  String? query;
  String? status;
  String? action;
  String? executiveAction;
  int? executiveDocumentId;
  int actionCalls = 0;
  int executiveActionCalls = 0;
  int detailCalls = 0;
  final List<String?> actionComments = [];
  final List<String?> executiveComments = [];
  final List<Object> actionErrors = [];
  Completer<void>? actionCompleter;
  int loadCalls = 0;

  @override
  void syncProject(int? projectId) {
    state = state.copyWith(projectId: projectId);
  }

  @override
  Future<void> load() async {
    loadCalls++;
    _setLoadedState(projectId: state.projectId);
  }

  @override
  Future<void> setQuery(String query) async {
    this.query = query;
  }

  @override
  Future<void> setStatus(String? status) async {
    this.status = status;
  }

  @override
  Future<CompanionModuleDetailModel> fetchDetail(int id) async {
    detailCalls++;
    final detail = _detailOverride ?? companionDetailJson(slug: _moduleSlug);
    _setRequiresComment(
      detail['item'] as Map<String, dynamic>,
      _requiresComment,
    );
    final relatedItems = detail['related_items'] as List<dynamic>;
    final relatedItem = relatedItems.single as Map<String, dynamic>;
    _setRequiresComment(relatedItem, _relatedRequiresComment);
    return CompanionModuleDetailModel.fromJson(detail);
  }

  @override
  Future<CompanionModuleDetailModel> executeAction({
    required int id,
    required String action,
    String? comment,
  }) async {
    actionCalls++;
    actionComments.add(comment);
    final completer = actionCompleter;
    if (completer != null) await completer.future;
    if (actionErrors.isNotEmpty) throw actionErrors.removeAt(0);
    this.action = action;
    return CompanionModuleDetailModel.fromJson(companionDetailJson());
  }

  @override
  Future<void> executeExecutiveDocumentAction({
    required int documentId,
    required String action,
    String? comment,
    int? versionId,
    String? severity,
  }) async {
    executiveActionCalls++;
    executiveComments.add(comment);
    final completer = actionCompleter;
    if (completer != null) await completer.future;
    if (actionErrors.isNotEmpty) throw actionErrors.removeAt(0);
    executiveAction = action;
    executiveDocumentId = documentId;
  }

  void _setLoadedState({int? projectId, String? moduleSlug}) {
    final listJson = companionListJson(slug: moduleSlug ?? _moduleSlug);
    final item = (listJson['items'] as List).single;
    if (_statusLabel != null) {
      item['status_label'] = _statusLabel;
    }
    if (_itemStatus != null) {
      item['status'] = _itemStatus;
    }
    if (_itemTitle != null) {
      item['title'] = _itemTitle;
    }
    _setRequiresComment(item as Map<String, dynamic>, _requiresComment);
    state = CompanionModuleState(
      isLoading: false,
      projectId: projectId,
      list: CompanionModuleListModel.fromJson(listJson),
    );
  }

  void showStaleListForQuery() {
    final listJson = companionListJson(slug: _moduleSlug, lastPage: 2);
    state = state.copyWith(
      list: CompanionModuleListModel.fromJson(listJson),
      query: 'new query',
      showingStaleList: true,
      error: 'Нет соединения',
    );
  }

  void _setRequiresComment(Map<String, dynamic> item, bool requiresComment) {
    final actions = item['available_actions'] as List<dynamic>?;
    if (actions == null || actions.isEmpty) return;
    (actions.first as Map<String, dynamic>)['requires_comment'] =
        requiresComment;
  }
}

void main() {
  Widget buildApp(
    Widget child,
    _FakeCompanionNotifier notifier, {
    _FakeProjectsNotifier? projectsNotifier,
    double textScale = 1,
  }) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => projectsNotifier ?? _FakeProjectsNotifier(),
        ),
        companionModuleProvider.overrideWith((ref, moduleSlug) => notifier),
      ],
      child: MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: child,
      ),
    );
  }

  testWidgets(
    'real customer-review status fits companion card at narrow sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const itemTitle = 'Изменение условий договора и графика работ №482';

      for (final (width, textScale) in [(360.0, 1.0), (240.0, 1.3)]) {
        tester.view.physicalSize = Size(width, 800);
        final notifier = _FakeCompanionNotifier(
          moduleSlug: 'change-management',
          itemStatus: 'customer_review',
          statusLabel: 'Согласование с заказчиком',
          itemTitle: itemTitle,
        );

        await tester.pumpWidget(
          buildApp(
            const CompanionModuleScreen(
              moduleSlug: 'change-management',
              title: 'Изменения',
              icon: Icons.change_circle_outlined,
            ),
            notifier,
            textScale: textScale,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Согласование с заказчиком'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('Согласование с заказчиком')).maxLines,
          isNull,
        );
        expect(tester.getSize(find.text(itemTitle)).width, greaterThan(80));
      }
    },
  );

  testWidgets('shows companion list screen and runs filters', (tester) async {
    final notifier = _FakeCompanionNotifier();

    await tester.pumpWidget(
      buildApp(
        const CompanionModuleScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
        ),
        notifier,
      ),
    );
    await tester.pump();

    expect(find.text('Договоры'), findsWidgets);
    expect(find.text('C-001'), findsOneWidget);
    expect(find.text('Активно'), findsWidgets);
    expect(find.bySemanticsLabel('Обновить список'), findsOneWidget);
    expect(find.text('100 000,00'), findsOneWidget);
    expect(find.text('100000.00'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('companion-search')), 'Tower');
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.query, 'Tower');

    await tester.tap(find.text('Черновик'));
    await tester.pump();
    expect(notifier.status, 'draft');
  });

  testWidgets('executive detail renders localized result and remark statuses', (
    tester,
  ) async {
    final detail = companionDetailJson(slug: 'executive-documentation');
    detail['result'] = {'status': 'draft'};
    detail['comments'] = [
      {'body': 'Проверить схему', 'status': 'open'},
    ];
    final notifier = _FakeCompanionNotifier(
      moduleSlug: 'executive-documentation',
      detailOverride: detail,
    );
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'executive-documentation',
          title: 'Исполнительная документация',
          icon: Icons.description_outlined,
          itemId: 42,
          requiresProject: true,
          projectId: 9,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Черновик'), 200);
    expect(find.text('Статус'), findsOneWidget);
    expect(find.text('draft'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('Открыто'), 200);
    expect(find.textContaining('Проверить схему\nОткрыто'), findsOneWidget);
    expect(find.text('open'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labels previous companion list after offline search', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
        ),
        notifier,
      ),
    );
    await tester.pump();

    notifier.showStaleListForQuery();
    await tester.pump();

    expect(find.text('C-001'), findsOneWidget);
    expect(
      find.textContaining('может не учитывать текущие фильтры'),
      findsOneWidget,
    );
    expect(find.text('Загрузить ещё'), findsNothing);
  });

  testWidgets('requires a selected project for field workflow lists', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleScreen(
          moduleSlug: 'change-management',
          title: 'Изменения',
          icon: Icons.change_circle_outlined,
          requiresProject: true,
        ),
        notifier,
        projectsNotifier: _FakeProjectsNotifier(hasSelectedProject: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Выберите объект'), findsOneWidget);
    expect(find.text('C-001'), findsNothing);
    expect(notifier.loadCalls, 0);
  });

  testWidgets('shows detail screen and executes action', (tester) async {
    final notifier = _FakeCompanionNotifier();

    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Основное'), findsOneWidget);
    expect(find.text('Отправить на оценку'), findsOneWidget);

    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(notifier.action, 'submit');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Связанные записи'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Связанные записи'), findsOneWidget);
  });

  testWidgets('shows files, comments, result and permitted executive actions', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier(
      moduleSlug: 'executive-documentation',
    );

    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'executive-documentation',
          title: 'Исполнительная документация',
          icon: Icons.description_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Исполнительная схема.pdf'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Файлы'), findsOneWidget);
    expect(find.text('Исполнительная схема.pdf'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Комментарии'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Комментарии'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Проверено'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Проверено'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Принято'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Принято'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Передано на проверку'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Передано на проверку'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Исполнительные документы'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Исполнительные документы'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Согласовать'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Согласовать'), findsOneWidget);

    await tester.tap(find.text('Согласовать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(notifier.executiveAction, 'approve');
    expect(notifier.executiveDocumentId, 7);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
  });

  testWidgets('cancelling optional action sends no request', (tester) async {
    final notifier = _FakeCompanionNotifier();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(notifier.actionCalls, 0);
  });

  testWidgets('barrier dismissal of optional action sends no request', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();

    expect(notifier.actionCalls, 0);
  });

  testWidgets('dismissing required action sends no request', (tester) async {
    final notifier = _FakeCompanionNotifier(requiresComment: true);
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();

    expect(notifier.actionCalls, 0);
  });

  testWidgets('cancelling required action sends no request', (tester) async {
    final notifier = _FakeCompanionNotifier(requiresComment: true);
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(notifier.actionCalls, 0);
  });

  testWidgets('dismissing optional related action sends no request', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier(
      moduleSlug: 'executive-documentation',
    );
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'executive-documentation',
          title: 'Исполнительная документация',
          icon: Icons.description_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Согласовать'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Согласовать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Согласовать'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();

    expect(notifier.executiveActionCalls, 0);
  });

  testWidgets('422 keeps comment and retries same action', (tester) async {
    final notifier = _FakeCompanionNotifier(requiresComment: true)
      ..actionErrors.add(
        const ApiException('Действие отклонено сервером.', statusCode: 422),
      );
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();
    expect(notifier.actionCalls, 0);
    expect(find.text('Укажите комментарий к действию.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('companion-action-comment')),
      'Подтверждаю корректировку',
    );
    await tester.ensureVisible(find.text('Выполнить'));
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();
    expect(find.text('Действие отклонено сервером.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('companion-action-comment')))
          .controller!
          .text,
      'Подтверждаю корректировку',
    );
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(notifier.actionCalls, 2);
    expect(notifier.actionComments, [
      'Подтверждаю корректировку',
      'Подтверждаю корректировку',
    ]);
    expect(find.text('Готово'), findsOneWidget);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
  });

  testWidgets('rapid taps while action is pending send one request', (
    tester,
  ) async {
    final notifier =
        _FakeCompanionNotifier()..actionCompleter = Completer<void>();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнить'));
    await tester.pump();
    await tester.tapAt(const Offset(3, 3));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Выполняем'), findsOneWidget);
    final sheetRect = tester.getRect(find.byType(BottomSheet).last);
    await tester.dragFrom(
      Offset(sheetRect.center.dx, sheetRect.top + 4),
      const Offset(0, 500),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Выполняем'), findsOneWidget);
    await tester.tap(find.text('Выполняем'), warnIfMissed: false);

    expect(notifier.actionCalls, 1);
    notifier.actionCompleter!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Готово'), findsOneWidget);
    final detailCallsBeforeAcknowledgement = notifier.detailCalls;
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();
    expect(find.text('Готово'), findsOneWidget);
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(notifier.detailCalls, greaterThan(detailCallsBeforeAcknowledgement));
  });

  testWidgets('action sheet controls fit narrow viewport at large text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(240, 426);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notifier = _FakeCompanionNotifier(requiresComment: true);
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Отправить на оценку'));
    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Отмена'));
    await tester.ensureVisible(find.text('Выполнить'));

    expect(tester.takeException(), isNull);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('Выполнить'), findsOneWidget);
  });

  testWidgets('late action completion after route disposal is safe', (
    tester,
  ) async {
    final notifier =
        _FakeCompanionNotifier()..actionCompleter = Completer<void>();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнить'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    notifier.actionCompleter!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('hides detail and actions after selected project changes', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier();
    final projects = _FakeProjectsNotifier();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'change-management',
          title: 'Изменения',
          icon: Icons.change_circle_outlined,
          itemId: 42,
          requiresProject: true,
          projectId: 9,
        ),
        notifier,
        projectsNotifier: projects,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Основное'), findsOneWidget);

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
    expect(find.text('Отправить на оценку'), findsNothing);
    expect(find.text('Основное'), findsNothing);
    expect(find.text('Исполнительная схема.pdf'), findsNothing);
  });
}
