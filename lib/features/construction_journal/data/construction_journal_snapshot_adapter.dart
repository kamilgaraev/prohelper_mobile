import '../../../core/storage/cached_entity.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/entity_snapshot_store.dart';
import '../../../core/storage/list_snapshot.dart';
import '../../../core/storage/snapshot_load.dart';
import '../../../core/storage/snapshot_read.dart';
import 'construction_journal_models.dart';
import 'construction_journal_repository.dart';

class ConstructionJournalSnapshotAdapter {
  ConstructionJournalSnapshotAdapter({
    required ConstructionJournalRepository repository,
    required Future<EntitySnapshotService> snapshots,
    Future<void> Function()? flushQueue,
  }) : _repository = repository,
       _snapshots = snapshots,
       _flushQueue = flushQueue;

  static const type = 'construction_journal';
  static const detailType = 'construction_journal_detail';
  static const entryType = 'construction_journal_entry';

  final ConstructionJournalRepository _repository;
  final Future<EntitySnapshotService> _snapshots;
  final Future<void> Function()? _flushQueue;

  Future<SnapshotRead<ConstructionJournalListPayload>> load({
    required bool online,
    required int projectId,
  }) async {
    final cached = await readCached(projectId: projectId);
    if (!online) {
      return cached;
    }

    EntitySnapshotOwner? expectedOwner;
    try {
      await _flushQueue?.call();
      final service = await _snapshots;
      final owner = service.currentOwner;
      if (owner == null) return cached;
      expectedOwner = owner;
      final pulledAt = DateTime.now().toUtc();
      late final Map<String, dynamic> payload;
      await service.pullAndMerge(type, () async {
        payload = await _repository.fetchJournalListPayload(
          projectId: projectId,
        );
        final items = _itemsOf(payload);
        return [
          for (final item in items)
            cachedEntityFromPayload(
              type: type,
              remoteId: '${item['id']}',
              payload: item,
              projectId: projectId,
              updatedAt:
                  DateTime.tryParse(item['updated_at']?.toString() ?? '') ??
                  pulledAt,
            ),
        ];
      }, expectedOwner: owner);
      await service.putSnapshot(
        snapshotCollectionMarker(
          type: type,
          projectId: projectId,
          at: pulledAt,
          extra: {
            'summary': payload['summary'],
            'meta': payload['meta'],
            'available_actions': payload['available_actions'],
            'project': payload['project'],
          },
        ),
        expectedOwner: owner,
      );
      return readCached(projectId: projectId, fromNetwork: true);
    } catch (error) {
      if (isSnapshotPermissionDenied(error)) {
        if (expectedOwner != null) {
          final service = await _snapshots;
          await service.invalidateScope(
            type,
            projectId,
            expectedOwner: expectedOwner,
          );
          await service.invalidateScope(
            detailType,
            projectId,
            expectedOwner: expectedOwner,
          );
          await service.invalidateScope(
            entryType,
            projectId,
            expectedOwner: expectedOwner,
          );
        }
        return SnapshotRead(
          presence: SnapshotPresence.permissionDenied,
          error: snapshotErrorMessage(
            error,
            'Недостаточно прав для просмотра журнала работ.',
          ),
        );
      }
      if (isSnapshotConflict(error)) {
        return SnapshotRead(
          presence: SnapshotPresence.conflict,
          data: cached.data,
          error: SnapshotUserMessages.conflict,
          fromCache: cached.hasData,
          hasDirtyLocal: true,
        );
      }
      if (isSnapshotOffline(error)) {
        return cached;
      }
      return SnapshotRead(
        presence: SnapshotPresence.error,
        error: snapshotErrorMessage(
          error,
          'Данные журнала работ пришли неполными. Обновите экран и повторите попытку.',
        ),
      );
    }
  }

  Future<SnapshotRead<ConstructionJournalDetailPayload>> loadDetail({
    required bool online,
    required int journalId,
    int? projectId,
  }) async {
    final read = await loadSingleEntitySnapshot<
      ConstructionJournalDetailPayload
    >(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readCachedDetail(
            journalId: journalId,
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: _flushQueue,
      snapshots: _snapshots,
      type: detailType,
      remoteId: '$journalId',
      fetchPayload: () => _repository.fetchJournalDetailPayload(journalId),
      projectId: projectId,
      permissionFallback: 'Недостаточно прав для просмотра журнала работ.',
      malformedFallback:
          'Данные журнала работ пришли неполными. Обновите экран и повторите попытку.',
    );
    if (read.presence == SnapshotPresence.permissionDenied) {
      final service = await _snapshots;
      final owner = service.currentOwner;
      if (owner != null) {
        await service.invalidateScope(
          detailType,
          projectId,
          expectedOwner: owner,
        );
        await service.invalidateScope(type, projectId, expectedOwner: owner);
        await service.invalidateScope(
          entryType,
          projectId,
          expectedOwner: owner,
        );
      }
    }
    return read;
  }

  Future<SnapshotRead<ConstructionJournalDetailPayload>> readCachedDetail({
    required int journalId,
    int? projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    final remoteId = '$journalId';
    final detailScope = await service.getList(detailType, projectId);
    final listScope = await service.getList(type, projectId);
    if (detailScope.any(isSnapshotPermissionRevoked) ||
        listScope.any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: 'Недостаточно прав для просмотра журнала работ.',
      );
    }
    final entity =
        await service.getOne(detailType, remoteId, projectId: projectId) ??
        await service.getOne(type, remoteId, projectId: projectId);
    try {
      return decodeSingleSnapshot(
        entity: entity,
        decode: _decodeDetail,
        missingMessage: SnapshotUserMessages.openJournalOnce,
        isEmpty: (_) => false,
        fromNetwork: fromNetwork,
      );
    } on FormatException {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openJournalOnce,
      );
    }
  }

  Future<SnapshotRead<ConstructionJournalEntryModel>> loadEntry({
    required bool online,
    required int entryId,
    int? projectId,
  }) async {
    final read = await loadSingleEntitySnapshot<ConstructionJournalEntryModel>(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readCachedEntry(
            entryId: entryId,
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: _flushQueue,
      snapshots: _snapshots,
      type: entryType,
      remoteId: '$entryId',
      fetchPayload: () => _repository.fetchEntryDetailPayload(entryId),
      projectId: projectId,
      permissionFallback: 'Недостаточно прав для просмотра журнала работ.',
      malformedFallback:
          'Данные журнала работ пришли неполными. Обновите экран и повторите попытку.',
    );
    if (read.presence == SnapshotPresence.permissionDenied) {
      final service = await _snapshots;
      final owner = service.currentOwner;
      if (owner != null) {
        await service.invalidateScope(
          entryType,
          projectId,
          expectedOwner: owner,
        );
        await service.invalidateScope(type, projectId, expectedOwner: owner);
        await service.invalidateScope(
          detailType,
          projectId,
          expectedOwner: owner,
        );
      }
    }
    return read;
  }

  Future<SnapshotRead<ConstructionJournalEntryModel>> readCachedEntry({
    required int entryId,
    int? projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    final scope = await service.getList(entryType, projectId);
    if (scope.any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: 'Недостаточно прав для просмотра журнала работ.',
      );
    }
    final entity = await service.getOne(
      entryType,
      '$entryId',
      projectId: projectId,
    );
    try {
      return decodeSingleSnapshot(
        entity: entity,
        decode: (payload) => ConstructionJournalEntryModel.fromJson(payload),
        missingMessage: SnapshotUserMessages.openJournalOnce,
        isEmpty: (_) => false,
        fromNetwork: fromNetwork,
      );
    } on FormatException {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openJournalOnce,
      );
    }
  }

  Future<SnapshotRead<ConstructionJournalListPayload>> readCached({
    required int projectId,
    bool fromNetwork = false,
  }) async {
    final itemsRead = await readListSnapshot<ConstructionJournalModel>(
      snapshots: _snapshots,
      type: type,
      projectId: projectId,
      fromNetwork: fromNetwork,
      missingMessage: SnapshotUserMessages.openJournalOnce,
      decode: _decodeJournal,
    );
    if (itemsRead.presence == SnapshotPresence.missing) {
      return SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openJournalOnce,
        fromCache: itemsRead.fromCache,
      );
    }

    final extra = await _collectionExtra(projectId);
    final payload = ConstructionJournalListPayload(
      items: itemsRead.data ?? const [],
      meta: JournalPaginationMeta.fromJson(
        _asMap(extra['meta'], fallbackPage: itemsRead.data?.length ?? 0),
      ),
      summary: ConstructionJournalSummary.fromJournalListJson(
        _asMap(extra['summary']),
      ),
      availableActions:
          _asList(
            extra['available_actions'],
          ).map(ConstructionJournalActionModel.fromJson).toList(),
      project: ConstructionJournalProjectRef.fromJson(
        _asMap(extra['project'], fallbackProjectId: projectId),
      ),
    );

    return SnapshotRead(
      presence: itemsRead.presence,
      data: payload,
      error: itemsRead.error,
      fromCache: itemsRead.fromCache,
      hasDirtyLocal: itemsRead.hasDirtyLocal,
    );
  }

  ConstructionJournalDetailPayload _decodeDetail(Map<String, dynamic> payload) {
    final journalPayload = payload['journal'];
    if (journalPayload is Map) {
      return ConstructionJournalDetailPayload(
        journal: ConstructionJournalModel.fromJson(
          journalPayload.map((key, value) => MapEntry(key.toString(), value)),
        ),
        entries:
            _asList(
              payload['entries'],
            ).map(ConstructionJournalEntryModel.fromJson).toList(),
        entriesMeta: JournalPaginationMeta.fromJson(
          _asMap(
            payload['meta'],
            fallbackPage: _asList(payload['entries']).length,
          ),
        ),
        entriesSummary: ConstructionJournalSummary.fromEntriesJson(
          _asMap(payload['summary'], fallbackEntries: true),
        ),
        availableActions:
            _asList(
              payload['available_actions'],
            ).map(ConstructionJournalActionModel.fromJson).toList(),
      );
    }

    final journal = ConstructionJournalModel.fromJson(payload);
    return ConstructionJournalDetailPayload(
      journal: journal,
      entries: const [],
      entriesMeta: JournalPaginationMeta.fromJson(
        _asMap(null, fallbackPage: 0),
      ),
      entriesSummary: ConstructionJournalSummary(
        totalEntries: journal.totalEntries,
        approvedEntries: journal.approvedEntries,
        submittedEntries: journal.submittedEntries,
        rejectedEntries: journal.rejectedEntries,
      ),
      availableActions: journal.availableActions,
    );
  }

  ConstructionJournalModel? _decodeJournal(CachedEntity entity) {
    try {
      return ConstructionJournalModel.fromJson(decodeSnapshotPayload(entity));
    } on FormatException {
      return null;
    }
  }

  Future<Map<String, dynamic>> _collectionExtra(int projectId) async {
    final service = await _snapshots;
    final extra = collectionExtraOf(await service.getList(type, projectId));
    return extra ?? const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> payload) {
    final value = payload['items'];
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, entry) => MapEntry(key.toString(), entry)),
        )
        .toList();
  }

  Map<String, dynamic> _asMap(
    Object? value, {
    int? fallbackPage,
    int? fallbackProjectId,
    bool fallbackEntries = false,
  }) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    if (fallbackPage != null) {
      return {
        'current_page': 1,
        'per_page': 20,
        'last_page': 1,
        'total': fallbackPage,
      };
    }
    if (fallbackProjectId != null) {
      return {'id': fallbackProjectId, 'name': 'Объект'};
    }
    if (fallbackEntries) {
      return {
        'total_entries': 0,
        'approved_entries': 0,
        'submitted_entries': 0,
        'rejected_entries': 0,
      };
    }
    return const {
      'total_journals': 0,
      'active_journals': 0,
      'archived_journals': 0,
      'closed_journals': 0,
    };
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, entry) => MapEntry(key.toString(), entry)),
        )
        .toList();
  }
}
