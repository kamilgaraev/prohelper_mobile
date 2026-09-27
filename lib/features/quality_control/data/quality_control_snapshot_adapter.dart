import '../../../core/storage/cached_entity.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/list_snapshot.dart';
import '../../../core/storage/snapshot_load.dart';
import '../../../core/storage/snapshot_read.dart';
import 'quality_control_repository.dart';
import 'quality_defect_model.dart';

class QualityControlSnapshotAdapter {
  QualityControlSnapshotAdapter({
    required QualityControlRepository repository,
    required Future<EntitySnapshotService> snapshots,
    Future<void> Function()? flushQueue,
  }) : _repository = repository,
       _snapshots = snapshots,
       _flushQueue = flushQueue;

  static const type = 'quality_defect';
  static const detailType = 'quality_defect_detail';

  final QualityControlRepository _repository;
  final Future<EntitySnapshotService> _snapshots;
  final Future<void> Function()? _flushQueue;

  Future<SnapshotRead<List<QualityDefectModel>>> load({
    required bool online,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) {
    return loadListSnapshot<QualityDefectModel>(
      snapshots: _snapshots,
      type: type,
      online: online,
      flushQueue: _flushQueue,
      projectId: projectId,
      fetchPayloads:
          () => _repository.fetchDefectPayloads(projectId: projectId),
      decode: _decode,
      matches:
          (item) => _matches(
            item,
            status: status,
            severity: severity,
            overdueOnly: overdueOnly,
          ),
      missingMessage: SnapshotUserMessages.openQualityOnce,
      permissionFallback: 'Недостаточно прав для просмотра контроля качества.',
      incompleteFallback:
          'Данные контроля качества пришли неполными. Обновите экран и повторите попытку.',
    );
  }

  Future<SnapshotRead<QualityDefectModel>> loadDetail({
    required bool online,
    required int defectId,
    required int? projectId,
  }) async {
    final read = await loadSingleEntitySnapshot<QualityDefectModel>(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readCachedDetail(
            defectId: defectId,
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: _flushQueue,
      snapshots: _snapshots,
      type: detailType,
      remoteId: '$defectId',
      fetchPayload: () => _repository.fetchDefectPayload(defectId),
      projectId: projectId,
      permissionFallback: 'Недостаточно прав для просмотра контроля качества.',
      malformedFallback:
          'Данные контроля качества пришли неполными. Обновите экран и повторите попытку.',
    );
    if (read.presence == SnapshotPresence.permissionDenied) {
      final service = await _snapshots;
      final owner = service.currentOwner;
      if (owner != null) {
        await service.invalidateScope(type, projectId, expectedOwner: owner);
      }
    }
    return read;
  }

  Future<SnapshotRead<QualityDefectModel>> readCachedDetail({
    required int defectId,
    required int? projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    final detailScope = await service.getList(detailType, projectId);
    final listScope = await service.getList(type, projectId);
    if (detailScope.any(isSnapshotPermissionRevoked) ||
        listScope.any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final entity = await service.getOne(
      detailType,
      '$defectId',
      projectId: projectId,
    );
    try {
      return decodeSingleSnapshot(
        entity: entity,
        decode: QualityDefectModel.fromJson,
        missingMessage: SnapshotUserMessages.openQualityOnce,
        isEmpty: (_) => false,
        fromNetwork: fromNetwork,
      );
    } on FormatException {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openQualityOnce,
      );
    }
  }

  Future<SnapshotRead<List<QualityDefectModel>>> readCached({
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
    bool fromNetwork = false,
  }) {
    return readListSnapshot<QualityDefectModel>(
      snapshots: _snapshots,
      type: type,
      decode: _decode,
      missingMessage: SnapshotUserMessages.openQualityOnce,
      projectId: projectId,
      fromNetwork: fromNetwork,
      matches:
          (item) => _matches(
            item,
            status: status,
            severity: severity,
            overdueOnly: overdueOnly,
          ),
    );
  }

  QualityDefectModel? _decode(CachedEntity entity) {
    try {
      return QualityDefectModel.fromJson(decodeSnapshotPayload(entity));
    } on FormatException {
      return null;
    }
  }

  bool _matches(
    QualityDefectModel item, {
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) {
    if (status != null && item.status != status) {
      return false;
    }
    if (severity != null && item.severity != severity) {
      return false;
    }
    if (overdueOnly && !item.isOverdue) {
      return false;
    }
    return true;
  }
}
