import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/snapshot_load.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../../core/storage/cached_entity_codec.dart';
import 'workforce_attendance_model.dart';
import 'workforce_repository.dart';

class WorkforceSnapshotAdapter {
  WorkforceSnapshotAdapter({
    required WorkforceRepository repository,
    required Future<EntitySnapshotService> snapshots,
  }) : _repository = repository,
       _snapshots = snapshots;

  static const type = 'attendance_history';

  final WorkforceRepository _repository;
  final Future<EntitySnapshotService> _snapshots;

  static String remoteIdFor(DateTime dateFrom, DateTime dateTo) {
    return '${_dateKey(dateFrom)}|${_dateKey(dateTo)}';
  }

  Future<SnapshotRead<AttendanceHistoryModel>> loadHistory({
    required bool online,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) {
    if (projectId == null) {
      if (!online) {
        return Future.value(
          const SnapshotRead(
            presence: SnapshotPresence.missing,
            error:
                'Выберите объект, чтобы открыть сохранённую историю явки без сети.',
          ),
        );
      }
      return _loadUnscopedOnline(dateFrom: dateFrom, dateTo: dateTo);
    }
    final remoteId = remoteIdFor(dateFrom, dateTo);
    return loadSingleEntitySnapshot(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readCached(
            dateFrom: dateFrom,
            dateTo: dateTo,
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: null,
      snapshots: _snapshots,
      type: type,
      remoteId: remoteId,
      projectId: projectId,
      fetchPayload:
          () => _repository.fetchAttendanceHistoryPayload(
            dateFrom: dateFrom,
            dateTo: dateTo,
            projectId: projectId,
          ),
      permissionFallback: 'Недостаточно прав для просмотра явки.',
      malformedFallback:
          'Данные явки пришли неполными. Обновите экран и повторите попытку.',
    );
  }

  Future<SnapshotRead<AttendanceHistoryModel>> _loadUnscopedOnline({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      return SnapshotRead(
        presence: SnapshotPresence.ready,
        data: await _repository.fetchAttendanceHistory(
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
      );
    } catch (error) {
      if (error is FormatException) rethrow;
      if (isSnapshotPermissionDenied(error)) {
        return SnapshotRead(
          presence: SnapshotPresence.permissionDenied,
          error: snapshotErrorMessage(
            error,
            'Недостаточно прав для просмотра явки.',
          ),
        );
      }
      return SnapshotRead(
        presence: SnapshotPresence.error,
        error: snapshotErrorMessage(
          error,
          'Не удалось загрузить историю явки. Для просмотра без сети выберите объект.',
        ),
      );
    }
  }

  Future<SnapshotRead<AttendanceHistoryModel>> readCached({
    required DateTime dateFrom,
    required DateTime dateTo,
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
    final entity = await service.getOne(
      type,
      remoteIdFor(dateFrom, dateTo),
      projectId: projectId,
    );
    return decodeSingleSnapshot(
      entity: entity,
      decode: AttendanceHistoryModel.fromJson,
      missingMessage: SnapshotUserMessages.openAttendanceOnce,
      isEmpty: (data) => data.items.isEmpty,
      fromNetwork: fromNetwork,
    );
  }

  static String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
