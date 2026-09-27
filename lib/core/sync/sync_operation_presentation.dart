import 'queued_sync_operation.dart';

class SyncOperationPresentation {
  const SyncOperationPresentation._();

  static String statusLabel(String status) => switch (status) {
    SyncOperationStatuses.sending => 'Отправляется',
    SyncOperationStatuses.conflict => 'Нужно проверить результат',
    SyncOperationStatuses.needsEdit => 'Нужно исправить',
    SyncOperationStatuses.permissionDenied => 'Недостаточно прав',
    _ => 'Ждёт отправки',
  };

  static String operationLabel(QueuedSyncOperation operation) =>
      switch (operation.operationType) {
        'start_shift' => 'Начало смены',
        'finish_shift' => 'Завершение смены',
        'submit_shift' => 'Отправка рапорта',
        'record_downtime' => 'Простой',
        'record_fuel' => 'Заправка',
        'complete_maintenance' => 'Завершение ТО',
        'issue_asset' => 'Выдача техники',
        'create_shift_report' => 'Рапорт смены',
        'create_site_request' => 'Заявка с объекта',
        'custody_issue' => 'Выдача со склада',
        'custody_return' => 'Возврат на склад',
        'receive_project_delivery' => 'Приёмка поставки',
        'create_receipt' => 'Приход на склад',
        'create_transfer' => 'Перемещение',
        'upload_photos' => 'Фото к операции',
        'receive_materials' => 'Приёмка закупки',
        'create_incident' => 'Инцидент',
        'create_violation' => 'Нарушение',
        'create_inspection_finding' => 'Замечание проверки',
        'upload_package_document' => 'Документ передачи',
        'create_finding' => 'Замечание',
        'create_defect' => 'Дефект',
        'resolve_defect' => 'Закрытие дефекта',
        'record_output' => 'Выработка',
        'record_daily_work_fact' => 'Факт работ за день',
        'create_entry' => 'Запись журнала',
        'create_and_submit_entry' => 'Запись журнала на проверку',
        'submit_entry' => 'Отправка записи журнала',
        'upload_paper_original' => 'Оригинал документа',
        _ => _moduleFallback(operation.moduleSlug),
      };

  static String _moduleFallback(String moduleSlug) => switch (moduleSlug) {
    'warehouse' => 'Складская операция',
    'machinery_operations' => 'Операция с техникой',
    'site_requests' => 'Заявка',
    'procurement' => 'Закупка',
    'safety' => 'Охрана труда',
    'quality_control' => 'Контроль качества',
    'construction_journal' => 'Журнал работ',
    'schedule' => 'График',
    'production_labor' => 'Выработка',
    'handover_acceptance' => 'Передача работ',
    'legal_archive' => 'Документ',
    _ => 'Сохранённая операция',
  };
}
