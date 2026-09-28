import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity_codec.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_snapshot_adapter.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  final owner = EntitySnapshotOwner(userId: 7, orgId: 10);

  test('офлайн читает журналы getList без сети', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: ConstructionJournalSnapshotAdapter.type,
        remoteId: '77',
        projectId: 15,
        payload: _journalItem(name: 'Журнал СМР'),
      ),
    );
    await service.putSnapshot(
      snapshotCollectionMarker(
        type: ConstructionJournalSnapshotAdapter.type,
        projectId: 15,
        at: DateTime.utc(2026, 9, 17),
        extra: {
          'summary': {
            'total_journals': 1,
            'active_journals': 1,
            'archived_journals': 0,
            'closed_journals': 0,
          },
          'meta': {
            'current_page': 1,
            'per_page': 20,
            'last_page': 1,
            'total': 1,
          },
          'available_actions': [
            {'action': 'create', 'label': 'Создать журнал'},
          ],
          'project': {'id': 15, 'name': 'Дом 300м Царево'},
        },
      ),
    );
    final repository = _FakeJournalRepository();
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.load(online: false, projectId: 15);

    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.items.single.name, 'Журнал СМР');
    expect(result.data?.summary.activeJournals, 1);
    expect(repository.fetchCount, 0);
    expect(repository.flushCount, 0);
  });

  test('офлайн без снимка журнала — missing', () async {
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
    );

    final result = await adapter.load(online: false, projectId: 15);

    expect(result.presence, SnapshotPresence.missing);
    expect(result.error, SnapshotUserMessages.openJournalOnce);
  });

  test('онлайн flush+pull пустого журнала — empty', () async {
    final repository = _FakeJournalRepository(payload: _listPayload(items: []));
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.load(online: true, projectId: 15);

    expect(repository.flushCount, 1);
    expect(repository.fetchCount, 1);
    expect(result.presence, SnapshotPresence.empty);
    expect(result.data?.items, isEmpty);
    expect(result.data?.project.name, 'Дом 300м Царево');
  });

  test('онлайн обновляет счётчик записей при прежней дате журнала', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    final previous = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(
        payload: _listPayload(items: [_journalItem()..['total_entries'] = 3]),
      ),
      snapshots: Future.value(service),
    );
    await previous.load(online: true, projectId: 15);

    final current = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(
        payload: _listPayload(items: [_journalItem()..['total_entries'] = 4]),
      ),
      snapshots: Future.value(service),
    );
    final result = await current.load(online: true, projectId: 15);

    expect(result.data?.items.single.totalEntries, 4);
  });

  test('403 журнала не становится пустым списком', () async {
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(permissionDenied: true),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async {},
    );

    final result = await adapter.load(online: true, projectId: 15);

    expect(result.presence, SnapshotPresence.permissionDenied);
    expect(result.error, 'Недостаточно прав для просмотра журнала работ.');
  });

  test('конфликт 409 журнала остаётся конфликтом', () async {
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(conflict: true),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async {},
    );

    final result = await adapter.load(online: true, projectId: 15);

    expect(result.presence, SnapshotPresence.conflict);
    expect(result.error, SnapshotUserMessages.conflict);
  });

  test('422 обновления списка не возвращает старый журнал как успех', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(),
      snapshots: Future.value(service),
    ).load(online: true, projectId: 15);

    final adapter = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(errorStatusCode: 422),
      snapshots: Future.value(service),
    );
    final result = await adapter.load(online: true, projectId: 15);

    expect(result.presence, SnapshotPresence.error);
    expect(result.data, isNull);
    expect(result.error, 'HTTP 422');
  });

  test('офлайн читает карточку журнала через getOne без сети', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: ConstructionJournalSnapshotAdapter.detailType,
        remoteId: '77',
        projectId: 15,
        payload: _detailPayload(name: 'Карточка из снимка'),
      ),
    );
    final repository = _FakeJournalRepository();
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.loadDetail(
      online: false,
      journalId: 77,
      projectId: 15,
    );

    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.journal.name, 'Карточка из снимка');
    expect(result.data?.entries.single.workDescription, contains('монтаж'));
    expect(repository.detailFetchCount, 0);
    expect(repository.flushCount, 0);
  });

  test('онлайн показывает новую запись при прежней дате журнала', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    final previous = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(detailPayload: _detailPayload()),
      snapshots: Future.value(service),
    );
    await previous.loadDetail(online: true, journalId: 77, projectId: 15);

    final newEntry =
        _entryPayload(description: 'Новая запись')
          ..['id'] = 92
          ..['entry_number'] = 6;
    final updated =
        _detailPayload()
          ..['journal'] = (_journalItem()..['total_entries'] = 4)
          ..['entries'] = [_entryPayload(), newEntry]
          ..['meta'] = {
            'current_page': 1,
            'per_page': 20,
            'last_page': 1,
            'total': 2,
          };
    final current = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(detailPayload: updated),
      snapshots: Future.value(service),
    );
    final result = await current.loadDetail(
      online: true,
      journalId: 77,
      projectId: 15,
    );

    expect(result.data?.entries, hasLength(2));
    expect(result.data?.entries.last.workDescription, 'Новая запись');
  });

  test('офлайн карточка журнала без снимка — missing', () async {
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: _FakeJournalRepository(),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
    );

    final result = await adapter.loadDetail(
      online: false,
      journalId: 77,
      projectId: 15,
    );

    expect(result.presence, SnapshotPresence.missing);
    expect(result.error, SnapshotUserMessages.openJournalOnce);
  });

  test('сеть-ошибка карточки журнала оставляет кэш', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: ConstructionJournalSnapshotAdapter.detailType,
        remoteId: '77',
        projectId: 15,
        payload: _detailPayload(name: 'Кэш карточки'),
      ),
    );
    final repository = _FakeJournalRepository(networkError: true);
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.loadDetail(
      online: true,
      journalId: 77,
      projectId: 15,
    );

    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.journal.name, 'Кэш карточки');
    expect(repository.detailFetchCount, 1);
  });

  test('офлайн читает запись журнала через getOne без сети', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: ConstructionJournalSnapshotAdapter.entryType,
        remoteId: '91',
        payload: _entryPayload(description: 'Снимок записи'),
      ),
    );
    final repository = _FakeJournalRepository();
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.loadEntry(online: false, entryId: 91);

    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.workDescription, 'Снимок записи');
    expect(repository.entryFetchCount, 0);
    expect(repository.flushCount, 0);
  });

  test('сеть-ошибка записи журнала оставляет кэш', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: ConstructionJournalSnapshotAdapter.entryType,
        remoteId: '91',
        payload: _entryPayload(description: 'Кэш записи'),
      ),
    );
    final repository = _FakeJournalRepository(networkError: true);
    final adapter = ConstructionJournalSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.loadEntry(online: true, entryId: 91);

    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.workDescription, 'Кэш записи');
    expect(repository.entryFetchCount, 1);
  });
}

Map<String, dynamic> _journalItem({String name = 'Журнал СМР'}) {
  return {
    'id': 77,
    'project_id': 15,
    'name': name,
    'journal_number': 'Ж-15',
    'start_date': '2026-05-20',
    'status': 'active',
    'status_label': 'Активный',
    'total_entries': 0,
    'approved_entries': 0,
    'submitted_entries': 0,
    'rejected_entries': 0,
    'available_actions': [
      {'action': 'view', 'label': 'Открыть'},
    ],
    'updated_at': '2026-09-17T10:00:00Z',
  };
}

Map<String, dynamic> _listPayload({List<Map<String, dynamic>>? items}) {
  return {
    'items': items ?? [_journalItem()],
    'meta': {'current_page': 1, 'per_page': 20, 'last_page': 1, 'total': 0},
    'summary': {
      'total_journals': 0,
      'active_journals': 0,
      'archived_journals': 0,
      'closed_journals': 0,
    },
    'available_actions': [
      {'action': 'create', 'label': 'Создать журнал'},
    ],
    'project': {'id': 15, 'name': 'Дом 300м Царево'},
  };
}

Map<String, dynamic> _entryPayload({String description = 'Выполнен монтаж'}) {
  return {
    'id': 91,
    'journal_id': 77,
    'entry_date': '2026-05-21',
    'entry_number': 5,
    'work_description': description,
    'status': 'submitted',
    'status_label': 'На утверждении',
    'workflow_state': 'ready',
    'workVolumes': const [],
    'workers': const [],
    'equipment': const [],
    'materials': const [],
    'blockers': const [],
    'available_actions': [
      {'action': 'view', 'label': 'Открыть'},
    ],
    'updated_at': '2026-09-17T11:00:00Z',
  };
}

Map<String, dynamic> _detailPayload({String name = 'Журнал СМР'}) {
  return {
    'journal': _journalItem(name: name),
    'entries': [_entryPayload()],
    'meta': {'current_page': 1, 'per_page': 20, 'last_page': 1, 'total': 1},
    'summary': {
      'total_entries': 1,
      'approved_entries': 0,
      'submitted_entries': 1,
      'rejected_entries': 0,
    },
    'available_actions': [
      {'action': 'create_entry', 'label': 'Создать запись'},
    ],
    'project_id': 15,
    'updated_at': '2026-09-17T10:00:00Z',
  };
}

class _FakeJournalRepository extends ConstructionJournalRepository {
  _FakeJournalRepository({
    this.payload,
    this.detailPayload,
    this.permissionDenied = false,
    this.conflict = false,
    this.networkError = false,
    this.errorStatusCode,
  }) : super(Dio());

  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? detailPayload;
  final bool permissionDenied;
  final bool conflict;
  final bool networkError;
  final int? errorStatusCode;
  int fetchCount = 0;
  int detailFetchCount = 0;
  int entryFetchCount = 0;
  int flushCount = 0;

  @override
  Future<Map<String, dynamic>> fetchJournalListPayload({
    required int projectId,
    int page = 1,
    int perPage = 20,
  }) async {
    fetchCount++;
    _throwIfFailed();
    return payload ?? _listPayload();
  }

  void _throwIfFailed() {
    if (permissionDenied) {
      throw const ApiException(
        'Недостаточно прав для просмотра журнала работ.',
        statusCode: 403,
      );
    }
    if (conflict) {
      throw const ApiException('Конфликт версии журнала.', statusCode: 409);
    }
    if (networkError) {
      throw const ApiException('Нет связи с сервером.', statusCode: 500);
    }
    if (errorStatusCode != null) {
      throw ApiException('HTTP $errorStatusCode', statusCode: errorStatusCode);
    }
  }

  @override
  Future<Map<String, dynamic>> fetchJournalDetailPayload(int journalId) async {
    detailFetchCount++;
    _throwIfFailed();
    return detailPayload ?? _detailPayload();
  }

  @override
  Future<ConstructionJournalDetailPayload> fetchJournalDetail(
    int journalId,
  ) async {
    final data = await fetchJournalDetailPayload(journalId);
    return ConstructionJournalDetailPayload(
      journal: ConstructionJournalModel.fromJson(
        Map<String, dynamic>.from(data['journal'] as Map),
      ),
      entries:
          (data['entries'] as List)
              .whereType<Map>()
              .map(
                (item) => ConstructionJournalEntryModel.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
      entriesMeta: JournalPaginationMeta.fromJson(
        Map<String, dynamic>.from(data['meta'] as Map),
      ),
      entriesSummary: ConstructionJournalSummary.fromEntriesJson(
        Map<String, dynamic>.from(data['summary'] as Map),
      ),
      availableActions: const [],
    );
  }

  @override
  Future<Map<String, dynamic>> fetchEntryDetailPayload(int entryId) async {
    entryFetchCount++;
    _throwIfFailed();
    return _entryPayload();
  }

  @override
  Future<ConstructionJournalEntryModel> fetchEntryDetail(int entryId) async {
    return ConstructionJournalEntryModel.fromJson(
      await fetchEntryDetailPayload(entryId),
    );
  }

  @override
  Future<ConstructionJournalListPayload> fetchJournals({
    required int projectId,
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await fetchJournalListPayload(projectId: projectId);
    return ConstructionJournalListPayload(
      items:
          (data['items'] as List)
              .whereType<Map>()
              .map(
                (item) => ConstructionJournalModel.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
      meta: JournalPaginationMeta.fromJson(
        Map<String, dynamic>.from(data['meta'] as Map),
      ),
      summary: ConstructionJournalSummary.fromJournalListJson(
        Map<String, dynamic>.from(data['summary'] as Map),
      ),
      availableActions: const [],
      project: ConstructionJournalProjectRef.fromJson(
        Map<String, dynamic>.from(data['project'] as Map),
      ),
    );
  }
}
