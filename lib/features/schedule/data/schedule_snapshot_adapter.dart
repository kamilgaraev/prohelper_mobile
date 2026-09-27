import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/entity_snapshot_store.dart';
import '../../../core/storage/snapshot_load.dart';
import '../../../core/storage/snapshot_read.dart';
import 'schedule_model.dart';
import 'schedule_repository.dart';

class ScheduleSnapshotAdapter {
  ScheduleSnapshotAdapter({
    required ScheduleRepository repository,
    required Future<EntitySnapshotService> snapshots,
    Future<void> Function()? flushQueue,
    DateTime Function()? now,
  }) : _repository = repository,
       _snapshots = snapshots,
       _flushQueue = flushQueue,
       _now = now ?? DateTime.now;

  static const overviewType = 'schedule_overview';
  static const detailType = 'schedule_detail';
  static const dailyType = 'schedule_daily_today';
  static const remoteId = 'current';

  final ScheduleRepository _repository;
  final Future<EntitySnapshotService> _snapshots;
  final Future<void> Function()? _flushQueue;
  final DateTime Function() _now;

  String todayKey() => _dateKey(_now());

  Future<SnapshotRead<ScheduleOverviewModel>> loadOverview({
    required bool online,
    required int projectId,
  }) {
    return loadSingleEntitySnapshot(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readOverviewCached(
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: _flushQueue,
      snapshots: _snapshots,
      type: overviewType,
      remoteId: remoteId,
      projectId: projectId,
      fetchPayload:
          () => _repository.fetchSchedulesPayload(projectId: projectId),
      permissionFallback: 'Недостаточно прав для просмотра графика.',
      malformedFallback:
          'Данные графика пришли неполными. Обновите экран и повторите попытку.',
    );
  }

  Future<SnapshotRead<ScheduleOverviewModel>> readOverviewCached({
    required int projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    if (await _isRevoked(service, overviewType, projectId)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final entity = await service.getOne(
      overviewType,
      remoteId,
      projectId: projectId,
    );
    return decodeSingleSnapshot(
      entity: entity,
      decode: ScheduleOverviewModel.fromJson,
      missingMessage: SnapshotUserMessages.openScheduleOnce,
      isEmpty: (data) => data.schedules.isEmpty,
      fromNetwork: fromNetwork,
    );
  }

  Future<SnapshotRead<ScheduleDetailsModel>> loadDetail({
    required bool online,
    required int scheduleId,
    required int projectId,
  }) {
    return loadSingleEntitySnapshot(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readDetailCached(
            scheduleId: scheduleId,
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: _flushQueue,
      snapshots: _snapshots,
      type: detailType,
      remoteId: '$scheduleId',
      projectId: projectId,
      fetchPayload: () => _repository.fetchScheduleDetailsPayload(scheduleId),
      permissionFallback: 'Недостаточно прав для просмотра графика работ.',
      malformedFallback:
          'Данные графика пришли неполными. Обновите экран и повторите попытку.',
    );
  }

  Future<SnapshotRead<ScheduleDetailsModel>> readDetailCached({
    required int scheduleId,
    required int projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    if (await _isRevoked(service, detailType, projectId)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final entity = await service.getOne(
      detailType,
      '$scheduleId',
      projectId: projectId,
    );
    return decodeSingleSnapshot(
      entity: entity,
      decode: ScheduleDetailsModel.fromJson,
      missingMessage: SnapshotUserMessages.openScheduleOnce,
      isEmpty: (_) => false,
      fromNetwork: fromNetwork,
    );
  }

  Future<SnapshotRead<List<DailyWorkPlanModel>>> loadDailyPlans({
    required bool online,
    required int projectId,
  }) async {
    final cached = await readDailyPlansCached(projectId: projectId);
    if (!online) {
      return cached;
    }

    EntitySnapshotService? service;
    EntitySnapshotOwner? owner;
    var permissionDeniedByFetch = false;
    try {
      await _flushQueue?.call();
      final currentService = await _snapshots;
      final expectedOwner = currentService.currentOwner;
      if (expectedOwner == null) return cached;
      service = currentService;
      owner = expectedOwner;

      late final List<Map<String, dynamic>> payloads;
      try {
        payloads = await _repository.fetchDailyWorkPlanPayloads(
          projectId: projectId,
        );
      } catch (error) {
        permissionDeniedByFetch = isSnapshotPermissionDenied(error);
        rethrow;
      }
      final today = todayKey();
      final todayPayloads =
          payloads
              .where((item) => item['work_date']?.toString() == today)
              .toList();
      await currentService.pullAndMerge(dailyType, () async {
        return [
          cachedEntityFromPayload(
            type: dailyType,
            remoteId: today,
            payload: {'plans': todayPayloads, 'work_date': today},
            projectId: projectId,
          ),
        ];
      }, expectedOwner: expectedOwner);
      final models = payloads.map(DailyWorkPlanModel.fromJson).toList();
      return SnapshotRead(
        presence:
            models.isEmpty ? SnapshotPresence.empty : SnapshotPresence.ready,
        data: models,
        fromCache: false,
      );
    } catch (error) {
      if (isSnapshotPermissionDenied(error)) {
        if (permissionDeniedByFetch && service != null && owner != null) {
          try {
            await service.invalidateScope(
              dailyType,
              projectId,
              expectedOwner: owner,
            );
          } catch (_) {}
        }
        return SnapshotRead(
          presence: SnapshotPresence.permissionDenied,
          error: snapshotErrorMessage(
            error,
            'Недостаточно прав для просмотра дневных планов.',
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
      if (isSnapshotOffline(error) || cached.hasData) {
        return SnapshotRead(
          presence: cached.presence,
          data: cached.data,
          error: snapshotErrorMessage(
            error,
            'Нет связи. Показаны сохранённые дневные планы.',
          ),
          fromCache: cached.hasData,
          hasDirtyLocal: cached.hasDirtyLocal,
        );
      }
      return SnapshotRead(
        presence: SnapshotPresence.error,
        error: snapshotErrorMessage(
          error,
          'Данные дневных планов пришли неполными. Обновите экран и повторите попытку.',
        ),
      );
    }
  }

  Future<SnapshotRead<List<DailyWorkPlanModel>>> readDailyPlansCached({
    required int projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    if (await _isRevoked(service, dailyType, projectId)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final entity = await service.getOne(
      dailyType,
      todayKey(),
      projectId: projectId,
    );
    return decodeSingleSnapshot(
      entity: entity,
      decode: (payload) {
        final list = payload['plans'];
        final items = list is List ? list : const [];
        return items
            .whereType<Map>()
            .map(
              (item) => DailyWorkPlanModel.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList();
      },
      missingMessage: SnapshotUserMessages.openDailyPlanOnce,
      isEmpty: (data) => data.isEmpty,
      fromNetwork: fromNetwork,
    );
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<bool> _isRevoked(
    EntitySnapshotService service,
    String type,
    int projectId,
  ) async {
    final scoped = await service.getList(type, projectId);
    return scoped.any(isSnapshotPermissionRevoked);
  }
}
