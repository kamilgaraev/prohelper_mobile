import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/domain/construction_journal_provider.dart';

class _FakeConstructionJournalRepository extends ConstructionJournalRepository {
  _FakeConstructionJournalRepository({this.error}) : super(Dio());

  final Object? error;

  @override
  Future<ConstructionJournalListPayload> fetchJournals({
    required int projectId,
    int page = 1,
    int perPage = 20,
  }) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }

    return const ConstructionJournalListPayload(
      items: [],
      meta: JournalPaginationMeta(
        currentPage: 1,
        perPage: 20,
        lastPage: 1,
        total: 0,
      ),
      summary: ConstructionJournalSummary(
        totalJournals: 0,
        activeJournals: 0,
        archivedJournals: 0,
        closedJournals: 0,
      ),
      availableActions: [
        ConstructionJournalActionModel(
          action: ConstructionJournalActionKeys.create,
          label: 'Создать журнал',
        ),
      ],
      project: ConstructionJournalProjectRef(id: 15, name: 'Дом 300м Царево'),
    );
  }
}

class _DeferredConstructionJournalRepository
    extends _FakeConstructionJournalRepository {
  final pending = <int, Completer<ConstructionJournalListPayload>>{};

  @override
  Future<ConstructionJournalListPayload> fetchJournals({
    required int projectId,
    int page = 1,
    int perPage = 20,
  }) {
    return (pending[projectId] ??= Completer()).future;
  }
}

ConstructionJournalListPayload _payload(int projectId) {
  return ConstructionJournalListPayload(
    items: [
      ConstructionJournalModel(
        id: projectId,
        projectId: projectId,
        name: 'Журнал $projectId',
        journalNumber: '$projectId',
        startDate: '2026-09-29',
        status: 'active',
        statusLabel: 'Активен',
        totalEntries: 0,
        approvedEntries: 0,
        submittedEntries: 0,
        rejectedEntries: 0,
        availableActions: const [],
      ),
    ],
    meta: const JournalPaginationMeta(
      currentPage: 1,
      perPage: 20,
      lastPage: 1,
      total: 1,
    ),
    summary: const ConstructionJournalSummary(totalJournals: 1),
    availableActions: const [],
    project: ConstructionJournalProjectRef(
      id: projectId,
      name: 'Объект $projectId',
    ),
  );
}

void main() {
  test('marks journal list as permission denied on 403', () async {
    final notifier = ConstructionJournalNotifier(
      _FakeConstructionJournalRepository(
        error: const ApiException('Недостаточно прав', statusCode: 403),
      ),
    );

    await notifier.load(projectId: 15);

    expect(notifier.state.permissionDenied, isTrue);
    expect(notifier.state.error, 'Недостаточно прав');
  });

  test('normalizes malformed journal contract error', () async {
    final notifier = ConstructionJournalNotifier(
      _FakeConstructionJournalRepository(
        error: const FormatException('available_actions'),
      ),
    );

    await notifier.load(projectId: 15);

    expect(notifier.state.permissionDenied, isFalse);
    expect(
      notifier.state.error,
      'Данные журнала работ пришли неполными. Обновите экран и повторите попытку.',
    );
  });

  test(
    'ignores an older project load that finishes after the current load',
    () async {
      final repository = _DeferredConstructionJournalRepository();
      final notifier = ConstructionJournalNotifier(repository);

      final loadA = notifier.load(projectId: 15);
      final loadB = notifier.load(projectId: 52);
      repository.pending[52]!.complete(_payload(52));
      await loadB;
      repository.pending[15]!.complete(_payload(15));
      await loadA;

      expect(notifier.state.projectId, 52);
      expect(notifier.state.project?.id, 52);
      expect(notifier.state.items.single.projectId, 52);
    },
  );

  test(
    'clearing selected project invalidates an in-flight list load',
    () async {
      final repository = _DeferredConstructionJournalRepository();
      final notifier = ConstructionJournalNotifier(repository);

      final load = notifier.load(projectId: 15);
      await notifier.load(projectId: null);
      repository.pending[15]!.complete(_payload(15));
      await load;

      expect(notifier.state.projectId, isNull);
      expect(notifier.state.project, isNull);
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.summary.totalJournals, 0);
      expect(notifier.state.availableActions, isEmpty);
    },
  );
}
