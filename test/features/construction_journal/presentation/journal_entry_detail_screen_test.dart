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
