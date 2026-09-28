import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/domain/construction_journal_provider.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/journal_entry_detail_screen.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _ProjectsRepository extends ProjectsRepository {
  _ProjectsRepository() : super(Dio());
}

class _ProjectsNotifier extends ProjectsNotifier {
  _ProjectsNotifier(int projectId) : super(_ProjectsRepository()) {
    select(projectId);
  }

  void select(int projectId) {
    final project =
        Project()
          ..serverId = projectId
          ..name = 'Объект $projectId'
          ..address = 'Площадка $projectId';
    state = state.copyWith(selectedProject: project);
  }
}

void main() {
  testWidgets('delete failure is reported and action remains retryable', (
    tester,
  ) async {
    final repository = _Repository();
    final notifier = ConstructionJournalEntryDetailNotifier(
      repository,
      84,
      projectId: 52,
    );
    await notifier.load();
    const scope = (entryId: 84, projectId: 52);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
          projectsProvider.overrideWith((ref) => _ProjectsNotifier(52)),
          constructionJournalEntryDetailProvider(
            scope,
          ).overrideWith((ref) => notifier),
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

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(
      find.text('Нельзя удалить запись, пока не подтверждены данные учета.'),
      findsOneWidget,
    );
    expect(find.text('Запись №84'), findsWidgets);
    expect(find.text('Удалить'), findsOneWidget);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 2);
    expect(find.text('Запись №84'), findsWidgets);
  });

  testWidgets('submit unknown outcome uses the saved operation message', (
    tester,
  ) async {
    final repository = _SubmitRepository();
    final notifier = ConstructionJournalEntryDetailNotifier(
      repository,
      84,
      projectId: 52,
    );
    await notifier.load();
    const scope = (entryId: 84, projectId: 52);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
          projectsProvider.overrideWith((ref) => _ProjectsNotifier(52)),
          constructionJournalEntryDetailProvider(
            scope,
          ).overrideWith((ref) => notifier),
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

    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();

    expect(find.text(SyncQueueMessages.unknownOutcome), findsOneWidget);
    expect(find.text('Отправить'), findsOneWidget);
    expect(repository.submitCalls, 1);
    expect(repository.detailCalls, 1);
  });

  testWidgets('reject dialog cannot write after the selected project changes', (
    tester,
  ) async {
    final projects = _ProjectsNotifier(9);
    final repository = _RejectRepository();
    final notifier = ConstructionJournalEntryDetailNotifier(
      repository,
      84,
      projectId: 9,
    );
    await notifier.load();
    const scope = (entryId: 84, projectId: 9);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
          projectsProvider.overrideWith((ref) => projects),
          constructionJournalEntryDetailProvider(
            scope,
          ).overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: JournalEntryDetailScreen(
            journalId: 17,
            entryId: 84,
            projectId: 9,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Отклонить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Причина');

    projects.select(52);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Отклонить'));
    await tester.pumpAndSettle();

    expect(repository.rejectCalls, 0);
    expect(find.text('Выбран другой объект'), findsOneWidget);
  });

  testWidgets('compact rejected header fits at 240dp with large text', (
    tester,
  ) async {
    await _expectCompactHeader(
      tester,
      width: 240,
      status: 'rejected',
      statusLabel: 'Отклонено',
    );
  });

  testWidgets('compact submitted header fits at 360dp with large text', (
    tester,
  ) async {
    await _expectCompactHeader(
      tester,
      width: 360,
      status: 'submitted',
      statusLabel: 'На утверждении',
    );
  });
}

class _RejectRepository extends ConstructionJournalRepository {
  _RejectRepository() : super(Dio());

  int rejectCalls = 0;

  @override
  Future<ConstructionJournalEntryModel> fetchEntryDetail(int entryId) async =>
      _entry(ConstructionJournalActionKeys.reject, 'Отклонить');

  @override
  Future<ConstructionJournalEntryModel> rejectEntry(
    int entryId,
    String reason,
  ) async {
    rejectCalls++;
    throw const ApiException('Reject request failed', statusCode: 422);
  }
}

Future<void> _expectCompactHeader(
  WidgetTester tester, {
  required double width,
  required String status,
  required String statusLabel,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _HeaderRepository(status, statusLabel);
  final notifier = ConstructionJournalEntryDetailNotifier(
    repository,
    7,
    projectId: 52,
  );
  await notifier.load();
  const scope = (entryId: 7, projectId: 52);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        constructionJournalRepositoryProvider.overrideWithValue(repository),
        projectsProvider.overrideWith((ref) => _ProjectsNotifier(52)),
        constructionJournalEntryDetailProvider(
          scope,
        ).overrideWith((ref) => notifier),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: const JournalEntryDetailScreen(
            journalId: 17,
            entryId: 7,
            projectId: 52,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text(statusLabel), findsOneWidget);
  final titleFinder = find.byKey(const ValueKey('journal-entry-card-title'));
  final dateFinder = find.byKey(const ValueKey('journal-entry-card-date'));
  expect(find.text('Запись №7', skipOffstage: false), findsWidgets);
  expect(find.text('28.09.2026'), findsOneWidget);
  expect(tester.widget<Text>(titleFinder).maxLines, 1);
  expect(tester.widget<Text>(dateFinder).maxLines, 1);
  expect(tester.getSize(titleFinder).height, lessThan(60));
  expect(tester.getSize(dateFinder).height, lessThan(40));
  expect(tester.getSize(titleFinder).width, greaterThan(width - 130));
  expect(tester.takeException(), isNull);
}

class _Repository extends ConstructionJournalRepository {
  _Repository() : super(Dio());

  int deleteCalls = 0;

  @override
  Future<ConstructionJournalEntryModel> fetchEntryDetail(int entryId) async =>
      const ConstructionJournalEntryModel(
        id: 84,
        journalId: 17,
        entryDate: '2026-09-28',
        entryNumber: 84,
        workDescription: 'QA: проверка обработки отказа удаления',
        status: 'rejected',
        statusLabel: 'Отклонена',
        workflowState: 'rejected',
        workVolumes: [],
        blockers: [],
        availableActions: [
          ConstructionJournalActionModel(
            action: ConstructionJournalActionKeys.delete,
            label: 'Удалить',
          ),
        ],
      );

  @override
  Future<void> deleteEntry(int entryId) async {
    deleteCalls++;
    throw const ApiException(
      'Нельзя удалить запись, пока не подтверждены данные учета.',
      statusCode: 422,
    );
  }
}

class _SubmitRepository extends ConstructionJournalRepository {
  _SubmitRepository() : super(Dio());

  int detailCalls = 0;
  int submitCalls = 0;

  @override
  Future<ConstructionJournalEntryModel> fetchEntryDetail(int entryId) async {
    detailCalls++;
    return _entry(ConstructionJournalActionKeys.submit, 'Отправить');
  }

  @override
  Future<ConstructionJournalEntryModel> submitEntry(
    int entryId, {
    String? idempotencyKey,
    int? journalId,
  }) async {
    submitCalls++;
    throw const SyncQueuedException(requiresReview: true);
  }
}

class _HeaderRepository extends ConstructionJournalRepository {
  _HeaderRepository(this.status, this.statusLabel) : super(Dio());

  final String status;
  final String statusLabel;

  @override
  Future<ConstructionJournalEntryModel> fetchEntryDetail(int entryId) async =>
      ConstructionJournalEntryModel(
        id: 7,
        journalId: 17,
        entryDate: '2026-09-28',
        entryNumber: 7,
        workDescription: 'QA_ASCII_LONGDESCRIPTIONWITHOUTSPACES',
        status: status,
        statusLabel: statusLabel,
        workflowState: status,
        workVolumes: const [],
        blockers: const [],
        availableActions: const [],
      );
}

ConstructionJournalEntryModel _entry(String action, String label) =>
    ConstructionJournalEntryModel(
      id: 84,
      journalId: 17,
      entryDate: '2026-09-28',
      entryNumber: 84,
      workDescription: 'QA: проверка обработки действия',
      status: 'draft',
      statusLabel: 'Черновик',
      workflowState: 'draft',
      workVolumes: const [],
      blockers: const [],
      availableActions: [
        ConstructionJournalActionModel(action: action, label: label),
      ],
    );
