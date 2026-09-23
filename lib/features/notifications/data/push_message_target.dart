class PushMessageTarget {
  const PushMessageTarget({
    this.notificationId,
    this.targetType,
    this.targetId,
    this.route,
    this.organizationId,
    this.projectId,
    this.journalId,
    this.warehouseId,
  });

  final String? notificationId;
  final String? targetType;
  final String? targetId;
  final String? route;
  final int? organizationId;
  final int? projectId;
  final int? journalId;
  final int? warehouseId;

  PushMessageDestination? get destination {
    final id = int.tryParse(targetId ?? '');
    if (id == null || id <= 0) return null;
    final normalizedType = (targetType ?? '').trim().toLowerCase().replaceAll(
      '-',
      '_',
    );
    final type = switch (normalizedType) {
      'site_request' || 'request' => PushDestinationType.siteRequest,
      'construction_journal_entry' ||
      'journal_entry' => PushDestinationType.journalEntry,
      'schedule' || 'work_schedule' => PushDestinationType.schedule,
      'warehouse_task' => PushDestinationType.warehouseTask,
      _ => null,
    };
    if (type == null) return null;
    if (type == PushDestinationType.warehouseTask &&
        (warehouseId == null || warehouseId! <= 0)) {
      return null;
    }
    return PushMessageDestination(
      type: type,
      id: id,
      parentId: switch (type) {
        PushDestinationType.journalEntry => journalId,
        PushDestinationType.warehouseTask => warehouseId,
        _ => null,
      },
    );
  }

  factory PushMessageTarget.fromData(Map<String, dynamic> data) {
    String? value(String key) {
      final raw = data[key]?.toString().trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    return PushMessageTarget(
      notificationId: value('notification_id'),
      targetType: value('target_type'),
      targetId: value('target_id'),
      route: value('route'),
      organizationId: int.tryParse(value('organization_id') ?? ''),
      projectId: int.tryParse(value('project_id') ?? ''),
      journalId: int.tryParse(value('journal_id') ?? ''),
      warehouseId: int.tryParse(value('warehouse_id') ?? ''),
    );
  }
}

enum PushDestinationType { siteRequest, journalEntry, schedule, warehouseTask }

class PushMessageDestination {
  const PushMessageDestination({
    required this.type,
    required this.id,
    this.parentId,
  });

  final PushDestinationType type;
  final int id;
  final int? parentId;
}
