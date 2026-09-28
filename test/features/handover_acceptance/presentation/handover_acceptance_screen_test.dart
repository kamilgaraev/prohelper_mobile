import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_model.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_document_picker.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_repository.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/domain/handover_acceptance_provider.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/presentation/handover_acceptance_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _RecordingHandoverRepository extends HandoverAcceptanceRepository {
  _RecordingHandoverRepository() : super(Dio());

  Map<String, dynamic>? findingPayload;
  String? resolutionComment;
  String? rejectReason;
  int? rejectedScopeId;
  int? loadedScopeId;
  int? reviewedChecklistItemId;
  int reviewedChecklistCalls = 0;
  String? reviewedChecklistComment;
  Object? reviewChecklistError;
  Completer<void>? reviewChecklistCompleter;
  int? uploadedDocumentId;
  String? uploadedDocumentPath;
  String? reviewedChecklistStatus;
  List<String> reviewedChecklistPhotoPaths = const [];
  List<String> findingPhotoPaths = const [];
  List<String> resolutionPhotoPaths = const [];
  List<String> rejectionPhotoPaths = const [];
  bool queueFindingCreation = false;
  String findingTitle = 'Скол плитки';

  AcceptanceScopeModel get scope => AcceptanceScopeModel(
    id: 5,
    projectId: 9,
    title: 'Секция А',
    status: 'findings_open',
    plannedAcceptanceDate: '2026-06-10',
    workflowSummary: HandoverWorkflowSummary(
      status: 'findings_open',
      availableActions: [
        'create_finding',
        'resolve_findings',
        'ready_for_reinspection',
        'reject',
      ],
      problemFlags: [],
    ),
    checklists: [
      AcceptanceChecklistModel(
        id: 30,
        scopeId: 5,
        title: 'Чек-лист квартиры',
        status: 'active',
        items: [
          AcceptanceChecklistItemModel(
            id: 31,
            title: 'Окна проверены',
            required: true,
            status: 'pending',
            availableActions: ['accept', 'reject'],
          ),
        ],
      ),
    ],
    sessions: [
      AcceptanceSessionModel(
        id: 7,
        status: 'findings_open',
        findings: [
          AcceptanceFindingModel(
            id: 11,
            sessionId: 7,
            title: findingTitle,
            severity: 'major',
            status: 'open',
          ),
        ],
      ),
    ],
    findings: [
      AcceptanceFindingModel(
        id: 11,
        sessionId: 7,
        title: findingTitle,
        severity: 'major',
        status: 'open',
      ),
    ],
    handoverPackage: HandoverPackageModel(
      id: 40,
      title: 'Комплект передачи',
      status: 'draft',
      documents: [
        HandoverPackageDocumentModel(
          id: 41,
          title: 'Фотофиксация',
          required: true,
          status: 'missing',
          documentType: 'photo_report',
          availableActions: ['upload'],
        ),
      ],
    ),
  );

  @override
  Future<List<AcceptanceScopeModel>> fetchScopes({
    int? projectId,
    String? status,
    String? plannedFrom,
    String? plannedTo,
  }) async {
    return [scope];
  }

  @override
  Future<AcceptanceScopeModel> fetchScope(int scopeId) async {
    loadedScopeId = scopeId;
    return scope;
  }

  @override
  Future<AcceptanceChecklistModel> reviewChecklistItem(
    int itemId, {
    required String status,
    String? comment,
    List<String> photoPaths = const [],
  }) async {
    reviewedChecklistCalls++;
    reviewedChecklistItemId = itemId;
    reviewedChecklistStatus = status;
    reviewedChecklistComment = comment;
    reviewedChecklistPhotoPaths = photoPaths;
    await reviewChecklistCompleter?.future;
    final error = reviewChecklistError;
    reviewChecklistError = null;
    if (error != null) throw error;
    return scope.checklists.single;
  }

  @override
  Future<HandoverPackageModel> uploadPackageDocument(
    int documentId, {
    required String filePath,
  }) async {
    uploadedDocumentId = documentId;
    uploadedDocumentPath = filePath;
    return scope.handoverPackage!;
  }

  @override
  Future<AcceptanceFindingModel> createFinding(
    int sessionId,
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    findingPayload = Map<String, dynamic>.from(data);
    findingPhotoPaths = photoPaths;
    if (queueFindingCreation) {
      throw const SyncQueuedException(queueId: 1);
    }

    return AcceptanceFindingModel(
      id: 12,
      sessionId: sessionId,
      title: data['title'].toString(),
      severity: data['severity'].toString(),
      status: 'open',
    );
  }

  @override
  Future<AcceptanceFindingModel> resolveFinding(
    int findingId, {
    required String resolutionComment,
    List<String> photoPaths = const [],
  }) async {
    this.resolutionComment = resolutionComment;
    resolutionPhotoPaths = photoPaths;

    return AcceptanceFindingModel(
      id: findingId,
      sessionId: 7,
      title: 'Скол плитки',
      severity: 'major',
      status: 'resolved',
    );
  }

  @override
  Future<AcceptanceScopeModel> rejectScope(
    int scopeId, {
    required String reason,
    List<String> photoPaths = const [],
  }) async {
    rejectedScopeId = scopeId;
    rejectReason = reason;
    rejectionPhotoPaths = photoPaths;
    return scope;
  }
}

class _TestHandoverNotifier extends HandoverAcceptanceNotifier {
  _TestHandoverNotifier(this.repository) : super(repository) {
    state = HandoverAcceptanceState(
      isLoading: false,
      projectFilter: 9,
      scopes: [repository.scope],
    );
  }

  final _RecordingHandoverRepository repository;

  @override
  Future<void> loadScopes() async {
    state = state.copyWith(isLoading: false, scopes: [repository.scope]);
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier(Project project) : super(_TestProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

class _FakeHandoverDocumentPicker extends HandoverDocumentPicker {
  @override
  Future<String?> pickDocumentPhoto() async => 'C:\\temp\\handover.jpg';
}

void main() {
  Project project() {
    return Project()
      ..serverId = 9
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildScreen(
    _RecordingHandoverRepository repository, {
    double textScale = 1,
  }) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        handoverAcceptanceProvider.overrideWith(
          (ref) => _TestHandoverNotifier(repository),
        ),
        handoverDocumentPickerProvider.overrideWith(
          (ref) => _FakeHandoverDocumentPicker(),
        ),
      ],
      child: MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: const HandoverAcceptanceScreen(),
      ),
    );
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('filters fit at large text scale on a phone viewport', (
    tester,
  ) async {
    final repository = _RecordingHandoverRepository();
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith(
            (ref) => _TestProjectsNotifier(project()),
          ),
          handoverAcceptanceProvider.overrideWith(
            (ref) => _TestHandoverNotifier(repository),
          ),
          handoverDocumentPickerProvider.overrideWith(
            (ref) => _FakeHandoverDocumentPicker(),
          ),
        ],
        child: MaterialApp(
          theme: MostTheme.darkTheme,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const HandoverAcceptanceScreen(),
        ),
      ),
    );
    await pumpUi(tester);

    final exception = tester.takeException();
    expect(exception, isNull);
  });

  testWidgets('submits explicit severity and quality-defect decision', (
    tester,
  ) async {
    final repository = _RecordingHandoverRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byIcon(Icons.add_comment_outlined));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).first, 'Неровная плитка');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await pumpUi(tester);
    await tester.tap(find.text('Средняя').last);
    await pumpUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await pumpUi(tester);
    await tester.tap(find.text('Создать').last);
    await pumpUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<bool>).last);
    await pumpUi(tester);
    await tester.tap(find.text('Не требуется').last);
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.findingPayload?['title'], 'Неровная плитка');
    expect(repository.findingPayload?['severity'], 'major');
    expect(repository.findingPayload?['create_quality_defect'], isTrue);
    expect(
      repository.findingPayload?['quality_defect_inspection_required'],
      isFalse,
    );
  });

  testWidgets('shows queued finding as saved and closes the form', (
    tester,
  ) async {
    final repository =
        _RecordingHandoverRepository()..queueFindingCreation = true;
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byIcon(Icons.add_comment_outlined));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).first, 'Неровная плитка');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await pumpUi(tester);
    await tester.tap(find.text('Средняя').last);
    await pumpUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await pumpUi(tester);
    await tester.tap(find.text('Не создавать').last);
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(find.text('Новое замечание'), findsNothing);
    expect(
      find.text('Будет отправлено при восстановлении связи'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app-error-notice')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires resolution comment before resolving finding', (
    tester,
  ) async {
    final repository = _RecordingHandoverRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byIcon(Icons.task_alt_rounded));
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.resolutionComment, isNull);

    await tester.enterText(find.byType(TextField).first, 'Плитка заменена');
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.resolutionComment, 'Плитка заменена');
  });

  testWidgets('requires rejection reason before rejecting scope', (
    tester,
  ) async {
    final repository = _RecordingHandoverRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byIcon(Icons.block_outlined));
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.rejectedScopeId, isNull);

    await tester.enterText(find.byType(TextField).first, 'Нужно переделать');
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.rejectedScopeId, 5);
    expect(repository.rejectReason, 'Нужно переделать');
  });

  testWidgets('opens detail and reviews checklist item', (tester) async {
    final repository = _RecordingHandoverRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.text('Подробнее').first);
    await pumpUi(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.loadedScopeId, 5);
    expect(find.text('Чек-лист квартиры'), findsOneWidget);
    expect(find.text('Окна проверены'), findsOneWidget);
    expect(find.text('Фотофиксация'), findsOneWidget);
    expect(find.text('Загрузить фото'), findsOneWidget);

    await tester.tap(find.text('Загрузить фото'));
    await pumpUi(tester);

    expect(repository.uploadedDocumentId, 41);
    expect(repository.uploadedDocumentPath, 'C:\\temp\\handover.jpg');

    await tester.ensureVisible(find.text('Принять').last);
    await tester.pump();
    await tester.tap(find.text('Принять').last);
    await pumpUi(tester);
    await tester.tap(find.text('Принять').last);
    await pumpUi(tester);

    expect(repository.reviewedChecklistItemId, 31);
    expect(repository.reviewedChecklistStatus, 'accepted');
  });

  testWidgets(
    'preserves checklist rejection draft after error and retries once on compact sheet',
    (tester) async {
      tester.view.physicalSize = const Size(240, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository =
          _RecordingHandoverRepository()
            ..reviewChecklistError = const ApiException(
              'Не удалось сохранить проверку. Повторите попытку.',
              statusCode: 403,
            );

      await tester.pumpWidget(buildScreen(repository, textScale: 1.3));
      await pumpUi(tester);
      final details = find.text('Подробнее').first;
      await tester.ensureVisible(details);
      await tester.tap(details);
      await pumpUi(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Окна проверены'));
      await tester.tap(find.text('Отклонить').last);
      await tester.pumpAndSettle();

      const comment =
          'Сначала проверить герметичность окон, заменить поврежденный уплотнитель и повторно подтвердить качество монтажа. ';
      final longComment = List.filled(4, comment).join();
      await tester.enterText(find.byType(TextField).last, longComment);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Отклонить'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить'));
      await tester.pumpAndSettle();

      expect(
        find.text('Не удалось сохранить проверку. Повторите попытку.'),
        findsOneWidget,
      );
      expect(find.text(longComment), findsOneWidget);
      expect(tester.takeException(), isNull);

      repository.reviewChecklistCompleter = Completer<void>();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Отклонить'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить'));
      await tester.pump();
      final submit = find.widgetWithText(FilledButton, 'Сохранение...');
      expect(submit, findsOneWidget);
      await tester.tap(submit);
      await tester.pump();
      expect(repository.reviewedChecklistCalls, 2);
      expect(repository.reviewedChecklistComment, longComment.trim());
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Сохранение...'), findsOneWidget);
      expect(repository.reviewedChecklistCalls, 2);

      repository.reviewChecklistCompleter!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Отклонить пункт чек-листа'), findsNothing);
      expect(repository.reviewedChecklistCalls, 2);
      expect(repository.reviewedChecklistComment, longComment.trim());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceling checklist review does not send a mutation', (
    tester,
  ) async {
    final repository = _RecordingHandoverRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    await tester.tap(find.text('Подробнее').first);
    await pumpUi(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Окна проверены'));
    await tester.tap(find.text('Отклонить').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(repository.reviewedChecklistCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending checklist review completes safely after screen disposal',
    (tester) async {
      final repository =
          _RecordingHandoverRepository()
            ..reviewChecklistCompleter = Completer<void>();
      useLargeSurface(tester);

      await tester.pumpWidget(buildScreen(repository));
      await pumpUi(tester);
      await tester.tap(find.text('Подробнее').first);
      await pumpUi(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Окна проверены'));
      await tester.tap(find.text('Отклонить').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Проверить повторно');
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить'));
      await tester.pump();
      expect(repository.reviewedChecklistCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      repository.reviewChecklistCompleter!.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('finding row gives long title full width above status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const title = 'Гидроизоляция_стыков_между_секциями_северного_корпуса';
    final repository = _RecordingHandoverRepository()..findingTitle = title;

    await tester.pumpWidget(buildScreen(repository, textScale: 1.3));
    await pumpUi(tester);
    await tester.ensureVisible(find.text('Подробнее').first);
    await tester.pump();
    await tester.tap(find.text('Подробнее').first);
    await pumpUi(tester);
    await tester.scrollUntilVisible(
      find.text(title),
      250,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text(title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
