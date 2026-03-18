import '../data/warehouse_scan_model.dart';

String warehouseActionLabel(String action) {
  return switch (action) {
    'receipt' => 'Приемка',
    'transfer' => 'Перемещение',
    'placement' => 'Размещение',
    'cycle_count' => 'Инвентаризация',
    'inspection' => 'Проверка',
    _ => action,
  };
}

String warehouseEntityTypeLabel(String entityType) {
  return switch (entityType) {
    'asset' => 'Актив',
    'cell' => 'Ячейка',
    'logistic_unit' => 'Логединица',
    'warehouse' => 'Склад',
    'zone' => 'Зона',
    'inventory_act' => 'Инвентаризация',
    'movement' => 'Движение',
    _ => entityType,
  };
}

String warehouseTaskTypeLabel(String type) {
  return switch (type) {
    'receipt' => 'Приемка',
    'placement' => 'Размещение',
    'transfer' => 'Перемещение',
    'picking' => 'Комплектация',
    'cycle_count' => 'Инвентаризация',
    'issue' => 'Выдача',
    'return' => 'Возврат',
    'relabel' => 'Перемаркировка',
    'inspection' => 'Проверка',
    _ => type,
  };
}

String warehouseStatusLabel(String status) {
  return switch (status) {
    'draft' => 'Черновик',
    'queued' => 'В очереди',
    'in_progress' => 'В работе',
    'blocked' => 'Заблокирована',
    'completed' => 'Завершена',
    'cancelled' => 'Отменена',
    'available' => 'Доступно',
    'sealed' => 'Запечатано',
    'in_transit' => 'В пути',
    'archived' => 'Архив',
    'active' => 'Активно',
    _ => status,
  };
}

String warehousePriorityLabel(String priority) {
  return switch (priority) {
    'critical' => 'Критично',
    'high' => 'Высокий',
    'normal' => 'Нормальный',
    'low' => 'Низкий',
    _ => priority,
  };
}

String warehouseTaskActionLabel(String status) {
  return switch (status) {
    'queued' => 'Вернуть в очередь',
    'in_progress' => 'Взять в работу',
    'blocked' => 'Заблокировать',
    'completed' => 'Завершить',
    'cancelled' => 'Отменить',
    _ => 'Обновить',
  };
}

List<String> warehouseAllowedTaskActions(WarehouseTaskModel task) {
  return switch (task.status) {
    'draft' => const ['queued', 'cancelled'],
    'queued' => const ['in_progress', 'blocked', 'cancelled'],
    'in_progress' => const ['completed', 'blocked', 'queued'],
    'blocked' => const ['in_progress', 'queued', 'cancelled'],
    'cancelled' => const ['queued'],
    _ => const <String>[],
  };
}

String? warehousePrimaryTaskAction(WarehouseTaskModel task) {
  return switch (task.status) {
    'draft' => 'queued',
    'queued' => 'in_progress',
    'in_progress' => 'completed',
    'blocked' => 'in_progress',
    'cancelled' => 'queued',
    _ => null,
  };
}

String warehouseFormatNumber(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}

String warehouseFormatDateTime(DateTime value) {
  final date = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');

  return '$date.$month.$year $hours:$minutes';
}
