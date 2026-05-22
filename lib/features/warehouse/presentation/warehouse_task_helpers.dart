import '../data/warehouse_scan_model.dart';

String warehouseActionLabel(String action) {
  return switch (action) {
    'receipt' => 'Приемка',
    'transfer' => 'Перемещение',
    'placement' => 'Размещение',
    'cycle_count' => 'Инвентаризация',
    'inspection' => 'Проверка',
    _ =>
      throw ArgumentError.value(action, 'action', 'Unknown warehouse action'),
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
    _ =>
      throw ArgumentError.value(
        entityType,
        'entityType',
        'Unknown warehouse entity type',
      ),
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
    _ => throw ArgumentError.value(type, 'type', 'Unknown warehouse task type'),
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
    _ =>
      throw ArgumentError.value(status, 'status', 'Unknown warehouse status'),
  };
}

String warehousePriorityLabel(String priority) {
  return switch (priority) {
    'critical' => 'Критично',
    'high' => 'Высокий',
    'normal' => 'Нормальный',
    'low' => 'Низкий',
    _ =>
      throw ArgumentError.value(
        priority,
        'priority',
        'Unknown warehouse priority',
      ),
  };
}

String warehouseTaskActionLabel(WarehouseTaskModel task, String status) {
  for (final transition in task.availableTransitions) {
    if (transition.status == status) {
      return transition.name;
    }
  }

  if (task.status == status) {
    return task.statusLabel;
  }

  throw ArgumentError.value(status, 'status', 'Unknown warehouse task action');
}

List<WarehouseTaskTransitionModel> warehouseAllowedTaskActions(
  WarehouseTaskModel task,
) {
  return task.availableTransitions;
}

WarehouseTaskTransitionModel? warehousePrimaryTaskAction(
  WarehouseTaskModel task,
) {
  return task.availableTransitions.isEmpty
      ? null
      : task.availableTransitions.first;
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
