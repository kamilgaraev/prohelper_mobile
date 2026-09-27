import 'cached_entity_codec.dart';
import 'entity_snapshot_service.dart';

enum SnapshotPresence {
  ready,
  empty,
  permissionDenied,
  missing,
  conflict,
  error,
}

class SnapshotRead<T> {
  const SnapshotRead({
    required this.presence,
    this.data,
    this.error,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.hasMore = false,
  });

  final SnapshotPresence presence;
  final T? data;
  final String? error;
  final bool fromCache;
  final bool hasDirtyLocal;
  final bool hasMore;

  bool get hasData => data != null;
}

SnapshotRead<T> snapshotFailureRead<T>({
  required SnapshotRead<T> cached,
  required Object error,
  required String fallback,
  required String permissionFallback,
}) {
  if (error is SnapshotOwnerChangedException) {
    return SnapshotRead(
      presence: SnapshotPresence.error,
      error: error.toString(),
    );
  }

  if (isSnapshotPermissionDenied(error)) {
    return SnapshotRead(
      presence: SnapshotPresence.permissionDenied,
      error: snapshotErrorMessage(error, permissionFallback),
    );
  }

  if (isSnapshotConflict(error)) {
    return SnapshotRead(
      presence: SnapshotPresence.conflict,
      data: cached.data,
      error: SnapshotUserMessages.conflict,
      fromCache: cached.hasData,
      hasDirtyLocal: true,
      hasMore: cached.hasMore,
    );
  }

  final message = snapshotErrorMessage(error, fallback);
  if (cached.hasData) {
    return SnapshotRead(
      presence: cached.presence,
      data: cached.data,
      error: message,
      fromCache: true,
      hasDirtyLocal: cached.hasDirtyLocal,
      hasMore: cached.hasMore,
    );
  }

  return SnapshotRead(presence: SnapshotPresence.error, error: message);
}

class SnapshotUserMessages {
  static const permissionRevoked =
      'Нет доступа к сохраненным данным этого раздела. Проверьте права при подключении к сети.';
  static const openWarehouseOnce =
      'Откройте склад один раз при связи, чтобы сохранить данные на устройство.';
  static const openSiteRequestsOnce =
      'Откройте заявки один раз при связи, чтобы сохранить список на устройство.';
  static const conflict =
      'Локальные изменения не затёрты снимком с сервера. Разберите конфликт в разделе «Не отправлено».';
  static const emptyWarehouse = 'По складу пока нет данных.';
  static const emptySiteRequests = 'Заявок пока нет.';
  static const openMachineryOnce =
      'Откройте технику один раз при связи, чтобы сохранить данные на устройство.';
  static const openProductionOnce =
      'Откройте наряды один раз при связи, чтобы сохранить список на устройство.';
  static const openAttendanceOnce =
      'Откройте явку один раз при связи, чтобы сохранить историю на устройство.';
  static const openTimeTrackingOnce =
      'Откройте учет времени один раз при связи, чтобы сохранить день на устройство.';
  static const openScheduleOnce =
      'Откройте график один раз при связи, чтобы сохранить данные на устройство.';
  static const openDailyPlanOnce =
      'Откройте факт дня один раз при связи, чтобы сохранить сегодняшний план на устройство.';
  static const openQualityOnce =
      'Откройте контроль качества один раз при связи, чтобы сохранить замечания на устройство.';
  static const openSafetyOnce =
      'Откройте охрану труда один раз при связи, чтобы сохранить данные на устройство.';
  static const openJournalOnce =
      'Откройте журнал работ один раз при связи, чтобы сохранить список на устройство.';
  static const openHandoverOnce =
      'Откройте приёмку один раз при связи, чтобы сохранить зоны на устройство.';
  static const openProcurementOnce =
      'Откройте снабжение один раз при связи, чтобы сохранить сводку на устройство.';
  static const openBudgetOnce =
      'Откройте сметы один раз при связи, чтобы сохранить сводку на устройство.';
  static const openWorkflowOnce =
      'Откройте согласования один раз при связи, чтобы сохранить список на устройство.';
  static const openContractsOnce =
      'Откройте договоры один раз при связи, чтобы сохранить список на устройство.';
  static const openCompanionOnce =
      'Откройте раздел один раз при связи, чтобы сохранить список на устройство.';
  static const openAiAssistantOnce =
      'Откройте ассистента один раз при связи, чтобы сохранить диалоги на устройство.';
  static const needsNetwork =
      'Нужна сеть. Это действие нельзя сохранить без связи.';
}
