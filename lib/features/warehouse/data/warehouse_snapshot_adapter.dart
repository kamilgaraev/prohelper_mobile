import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/entity_snapshot_store.dart';
import '../../../core/storage/snapshot_read.dart';
import 'warehouse_repository.dart';
import 'warehouse_summary_model.dart';

class WarehouseSnapshotAdapter {
  WarehouseSnapshotAdapter({
    required WarehouseRepository repository,
    required Future<EntitySnapshotService> snapshots,
    Future<void> Function()? flushQueue,
  }) : _repository = repository,
       _snapshots = snapshots,
       _flushQueue = flushQueue;

  static const type = 'warehouse_summary';
  static const remoteId = 'current';

  final WarehouseRepository _repository;
  final Future<EntitySnapshotService> _snapshots;
  final Future<void> Function()? _flushQueue;

  Future<SnapshotRead<WarehouseSummaryModel>> load({
    required bool online,
  }) async {
    final cached = await readCached();
    if (!online) {
      return cached;
    }

    EntitySnapshotService? service;
    EntitySnapshotOwner? owner;
    try {
      await _flushQueue?.call();
      service = await _snapshots;
      owner = service.currentOwner;
      if (owner == null) return cached;
      await service.pullAndMerge(type, () async {
        final payload = await _repository.fetchWarehouseSummaryPayload();
        return [
          cachedEntityFromPayload(
            type: type,
            remoteId: remoteId,
            payload: payload,
          ),
        ];
      }, expectedOwner: owner);
      return readCached(fromNetwork: true);
    } catch (error) {
      if (isSnapshotPermissionDenied(error)) {
        if (service != null && owner != null) {
          await service.invalidateScope(type, null, expectedOwner: owner);
        }
        return SnapshotRead(
          presence: SnapshotPresence.permissionDenied,
          error: snapshotErrorMessage(
            error,
            'Недостаточно прав для просмотра склада.',
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
        if (cached.presence == SnapshotPresence.missing) {
          return cached;
        }
        return cached;
      }
      if (cached.hasData) {
        return cached;
      }
      return SnapshotRead(
        presence: SnapshotPresence.error,
        error: snapshotErrorMessage(
          error,
          'Данные склада пришли неполными. Обновите экран и повторите попытку.',
        ),
      );
    }
  }

  Future<SnapshotRead<WarehouseSummaryModel>> readCached({
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    if ((await service.getList(type, null)).any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final entity = await service.getOne(type, remoteId);
    if (entity == null) {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openWarehouseOnce,
      );
    }

    final model = WarehouseSummaryModel.fromJson(decodeSnapshotPayload(entity));
    if (entity.dirty) {
      return SnapshotRead(
        presence: SnapshotPresence.conflict,
        data: model,
        error: SnapshotUserMessages.conflict,
        fromCache: !fromNetwork,
        hasDirtyLocal: true,
      );
    }
    if (_isEmpty(model)) {
      return SnapshotRead(
        presence: SnapshotPresence.empty,
        data: model,
        fromCache: !fromNetwork,
      );
    }
    return SnapshotRead(
      presence: SnapshotPresence.ready,
      data: model,
      fromCache: !fromNetwork,
    );
  }

  bool _isEmpty(WarehouseSummaryModel model) {
    return model.warehouses.isEmpty &&
        model.summary.warehouseCount == 0 &&
        model.summary.uniqueItemsCount == 0;
  }
}
