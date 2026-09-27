import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/snapshot_load.dart';
import '../../../core/storage/snapshot_read.dart';
import 'time_entry_model.dart';
import 'time_tracking_repository.dart';

class TimeTrackingSnapshotAdapter {
  TimeTrackingSnapshotAdapter({
    required TimeTrackingRepository repository,
    required Future<EntitySnapshotService> snapshots,
  }) : _repository = repository,
       _snapshots = snapshots;

  static const type = 'time_daily_summary';
  static const entryType = 'time_entry_detail';

  final TimeTrackingRepository _repository;
  final Future<EntitySnapshotService> _snapshots;

  Future<SnapshotRead<DailyTimeSummaryModel>> load({
    required bool online,
    required String date,
    required int projectId,
  }) {
    return loadSingleEntitySnapshot(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readCached(
            date: date,
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: null,
      snapshots: _snapshots,
      type: type,
      remoteId: date,
      projectId: projectId,
      fetchPayload:
          () => _repository.fetchDailySummaryPayload(
            date: date,
            projectId: projectId,
          ),
      permissionFallback: 'Недостаточно прав для просмотра учета времени.',
      malformedFallback:
          'Данные учета времени пришли неполными. Обновите экран и повторите попытку.',
    );
  }

  Future<SnapshotRead<DailyTimeSummaryModel>> readCached({
    required String date,
    required int projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    final scoped = await service.getList(type, projectId);
    if (scoped.any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final entity = await service.getOne(type, date, projectId: projectId);
    return decodeSingleSnapshot(
      entity: entity,
      decode: DailyTimeSummaryModel.fromJson,
      missingMessage: SnapshotUserMessages.openTimeTrackingOnce,
      isEmpty: (data) => data.entries.isEmpty && data.activeTimer == null,
      fromNetwork: fromNetwork,
    );
  }

  Future<SnapshotRead<TimeEntryModel>> loadEntry({
    required bool online,
    required int entryId,
    required int? projectId,
  }) async {
    if (projectId == null) {
      if (!online) {
        return const SnapshotRead(
          presence: SnapshotPresence.missing,
          error: SnapshotUserMessages.openTimeTrackingOnce,
        );
      }
      try {
        return SnapshotRead(
          presence: SnapshotPresence.ready,
          data: TimeEntryModel.fromJson(
            await _repository.fetchEntryPayload(entryId),
          ),
        );
      } catch (error) {
        return SnapshotRead(
          presence: SnapshotPresence.error,
          error: snapshotErrorMessage(
            error,
            'Не удалось загрузить запись времени.',
          ),
        );
      }
    }
    return loadSingleEntitySnapshot<TimeEntryModel>(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readEntryCached(
            entryId: entryId,
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: null,
      snapshots: _snapshots,
      type: entryType,
      remoteId: '$entryId',
      projectId: projectId,
      fetchPayload: () => _repository.fetchEntryPayload(entryId),
      permissionFallback: 'Недостаточно прав для просмотра записи времени.',
      malformedFallback:
          'Данные записи времени пришли неполными. Обновите экран и повторите попытку.',
    );
  }

  Future<SnapshotRead<TimeEntryModel>> readEntryCached({
    required int entryId,
    required int projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    final entryScope = await service.getList(entryType, projectId);
    if (entryScope.any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final entity = await service.getOne(
      entryType,
      '$entryId',
      projectId: projectId,
    );
    if (entity != null) {
      return decodeSingleSnapshot(
        entity: entity,
        decode: TimeEntryModel.fromJson,
        missingMessage: SnapshotUserMessages.openTimeTrackingOnce,
        isEmpty: (_) => false,
        fromNetwork: fromNetwork,
      );
    }
    final detailEntities = await service.getList(entryType, projectId);
    if (detailEntities.any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }

    final dailyEntities = await service.getList(type, projectId);
    if (dailyEntities.any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    for (final dailyEntity in dailyEntities) {
      if (isSnapshotCollectionMarker(dailyEntity)) continue;
      try {
        final payload = decodeSnapshotPayload(dailyEntity);
        final candidates = <Object?>[
          if (payload['entries'] is List) ...(payload['entries'] as List),
          payload['active_timer'],
        ];
        for (final candidate in candidates) {
          if (candidate is! Map) continue;
          final entryPayload = candidate.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final candidateId = _asInt(entryPayload['id']);
          if (candidateId != entryId) continue;
          final entry = TimeEntryModel.fromJson(entryPayload);
          return SnapshotRead(
            presence: SnapshotPresence.ready,
            data: entry,
            fromCache: !fromNetwork,
            hasDirtyLocal: dailyEntity.dirty,
          );
        }
      } on FormatException {
        continue;
      }
    }
    return const SnapshotRead(
      presence: SnapshotPresence.missing,
      error: SnapshotUserMessages.openTimeTrackingOnce,
    );
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
