import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/snapshot_load.dart';
import '../../../core/storage/snapshot_read.dart';
import 'production_labor_model.dart';
import 'production_labor_repository.dart';

class ProductionLaborSnapshotAdapter {
  ProductionLaborSnapshotAdapter({
    required ProductionLaborRepository repository,
    required Future<EntitySnapshotService> snapshots,
    Future<void> Function()? flushQueue,
  }) : _repository = repository,
       _snapshots = snapshots,
       _flushQueue = flushQueue;

  static const type = 'labor_work_orders';
  static const remoteId = 'current';

  final ProductionLaborRepository _repository;
  final Future<EntitySnapshotService> _snapshots;
  final Future<void> Function()? _flushQueue;

  Future<SnapshotRead<List<LaborWorkOrderModel>>> load({
    required bool online,
    int? projectId,
  }) {
    if (projectId == null) {
      if (!online) {
        return Future.value(
          const SnapshotRead(
            presence: SnapshotPresence.missing,
            error:
                'Выберите объект, чтобы открыть сохранённые наряды без сети.',
          ),
        );
      }
      return _loadUnscopedOnline();
    }
    return loadSingleEntitySnapshot(
      online: online,
      readCached:
          ({bool fromNetwork = false}) =>
              readCached(projectId: projectId, fromNetwork: fromNetwork),
      flushQueue: _flushQueue,
      snapshots: _snapshots,
      type: type,
      remoteId: remoteId,
      projectId: projectId,
      fetchPayload: () async {
        final payloads = await _repository.fetchWorkOrderPayloads(
          projectId: projectId,
        );
        return {'work_orders': payloads};
      },
      permissionFallback: 'Недостаточно прав для просмотра нарядов.',
      malformedFallback:
          'Данные нарядов пришли неполными. Обновите экран и повторите попытку.',
    );
  }

  Future<SnapshotRead<List<LaborWorkOrderModel>>> _loadUnscopedOnline() async {
    try {
      final payloads = await _repository.fetchWorkOrderPayloads();
      final workOrders = payloads.map(LaborWorkOrderModel.fromJson).toList();
      return SnapshotRead(
        presence:
            workOrders.isEmpty
                ? SnapshotPresence.empty
                : SnapshotPresence.ready,
        data: workOrders,
      );
    } catch (error) {
      return SnapshotRead(
        presence: SnapshotPresence.error,
        error: snapshotErrorMessage(
          error,
          'Не удалось загрузить наряды. Для просмотра без сети выберите объект.',
        ),
      );
    }
  }

  Future<SnapshotRead<List<LaborWorkOrderModel>>> readCached({
    int? projectId,
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
    final entity = await service.getOne(type, remoteId, projectId: projectId);
    return decodeSingleSnapshot(
      entity: entity,
      decode: (payload) {
        final list = payload['work_orders'];
        final items = list is List ? list : const [];
        return items
            .whereType<Map>()
            .map(
              (item) => LaborWorkOrderModel.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList();
      },
      missingMessage: SnapshotUserMessages.openProductionOnce,
      isEmpty: (data) => data.isEmpty,
      fromNetwork: fromNetwork,
    );
  }
}
