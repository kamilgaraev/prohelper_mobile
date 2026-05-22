class WorkflowTaskEntryModel {
  const WorkflowTaskEntryModel({
    required this.id,
    required this.action,
    required this.fromStatus,
    required this.toStatus,
    required this.userId,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String action;
  final String fromStatus;
  final String toStatus;
  final int userId;
  final String createdAt;
  final String? comment;

  factory WorkflowTaskEntryModel.fromJson(Map<String, dynamic> json) {
    return WorkflowTaskEntryModel(
      id: _requiredString(json, 'id'),
      action: _requiredStringIn(json, 'action', _workflowActions),
      fromStatus: _requiredStringIn(json, 'from_status', _workflowStatuses),
      toStatus: _requiredStringIn(json, 'to_status', _workflowStatuses),
      userId: _requiredInt(json, 'user_id'),
      createdAt: _requiredString(json, 'created_at'),
      comment: _nullableString(json['comment']),
    );
  }
}

class WorkflowSummaryModel {
  const WorkflowSummaryModel({
    required this.status,
    required this.stage,
    required this.stageLabel,
    required this.availableActions,
    this.nextAction,
    this.nextActionLabel,
  });

  final String status;
  final String stage;
  final String stageLabel;
  final List<String> availableActions;
  final String? nextAction;
  final String? nextActionLabel;

  factory WorkflowSummaryModel.fromJson(Map<String, dynamic> json) {
    final nextAction = _nullableString(json['next_action']);

    return WorkflowSummaryModel(
      status: _requiredStringIn(json, 'status', _workflowStatuses),
      stage: _requiredStringIn(json, 'stage', _workflowStatuses),
      stageLabel: _requiredString(json, 'stage_label'),
      availableActions: _requiredStringListIn(
        json,
        'available_actions',
        _workflowActions,
      ),
      nextAction:
          nextAction == null
              ? null
              : _stringInValue(nextAction, 'next_action', _workflowActions),
      nextActionLabel: _nullableString(json['next_action_label']),
    );
  }
}

class WorkflowTaskModel {
  const WorkflowTaskModel({
    required this.id,
    required this.organizationId,
    required this.projectId,
    required this.status,
    required this.statusLabel,
    required this.availableActions,
    required this.workflowSummary,
    required this.comments,
    required this.statusHistory,
    required this.createdAt,
    required this.updatedAt,
    this.projectLabel,
    this.workTypeId,
    this.workTypeLabel,
    this.contractId,
    this.contractLabel,
    this.contractorId,
    this.contractorLabel,
    this.assignedUserId,
    this.assignedUserLabel,
    this.scheduleTaskId,
    this.scheduleTaskLabel,
    this.scheduleLabel,
    this.estimateItemId,
    this.estimateItemLabel,
    this.workOriginType,
    this.workOriginLabel,
    this.planningStatus,
    this.planningStatusLabel,
    this.quantity,
    this.completedQuantity,
    this.measurementUnitLabel,
    this.price,
    this.totalAmount,
    this.completionDate,
    this.notes,
  });

  final int id;
  final int organizationId;
  final int projectId;
  final String? projectLabel;
  final int? workTypeId;
  final String? workTypeLabel;
  final int? contractId;
  final String? contractLabel;
  final int? contractorId;
  final String? contractorLabel;
  final int? assignedUserId;
  final String? assignedUserLabel;
  final int? scheduleTaskId;
  final String? scheduleTaskLabel;
  final String? scheduleLabel;
  final int? estimateItemId;
  final String? estimateItemLabel;
  final String? workOriginType;
  final String? workOriginLabel;
  final String? planningStatus;
  final String? planningStatusLabel;
  final double? quantity;
  final double? completedQuantity;
  final String? measurementUnitLabel;
  final double? price;
  final double? totalAmount;
  final String? completionDate;
  final String? notes;
  final String status;
  final String statusLabel;
  final List<String> availableActions;
  final WorkflowSummaryModel workflowSummary;
  final List<WorkflowTaskEntryModel> comments;
  final List<WorkflowTaskEntryModel> statusHistory;
  final String createdAt;
  final String updatedAt;

  String get title {
    final workType = workTypeLabel?.trim();
    if (workType != null && workType.isNotEmpty) {
      return workType;
    }

    return 'Выполненная работа #$id';
  }

  bool get canApprove => availableActions.contains('approve');
  bool get canReject => availableActions.contains('reject');
  bool get canRequestChanges => availableActions.contains('request_changes');
  bool get canComment => availableActions.contains('comment');

  factory WorkflowTaskModel.fromJson(Map<String, dynamic> json) {
    return WorkflowTaskModel(
      id: _requiredInt(json, 'id'),
      organizationId: _requiredInt(json, 'organization_id'),
      projectId: _requiredInt(json, 'project_id'),
      projectLabel: _nullableString(json['project_label']),
      workTypeId: _nullableInt(json['work_type_id']),
      workTypeLabel: _nullableString(json['work_type_label']),
      contractId: _nullableInt(json['contract_id']),
      contractLabel: _nullableString(json['contract_label']),
      contractorId: _nullableInt(json['contractor_id']),
      contractorLabel: _nullableString(json['contractor_label']),
      assignedUserId: _nullableInt(json['assigned_user_id']),
      assignedUserLabel: _nullableString(json['assigned_user_label']),
      scheduleTaskId: _nullableInt(json['schedule_task_id']),
      scheduleTaskLabel: _nullableString(json['schedule_task_label']),
      scheduleLabel: _nullableString(json['schedule_label']),
      estimateItemId: _nullableInt(json['estimate_item_id']),
      estimateItemLabel: _nullableString(json['estimate_item_label']),
      workOriginType: _nullableStringIn(
        json['work_origin_type'],
        _workflowOrigins,
      ),
      workOriginLabel: _nullableString(json['work_origin_label']),
      planningStatus: _nullableStringIn(
        json['planning_status'],
        _planningStatuses,
      ),
      planningStatusLabel: _nullableString(json['planning_status_label']),
      quantity: _nullableDouble(json['quantity']),
      completedQuantity: _nullableDouble(json['completed_quantity']),
      measurementUnitLabel: _nullableString(json['measurement_unit_label']),
      price: _nullableDouble(json['price']),
      totalAmount: _nullableDouble(json['total_amount']),
      completionDate: _nullableString(json['completion_date']),
      notes: _nullableString(json['notes']),
      status: _requiredStringIn(json, 'status', _workflowStatuses),
      statusLabel: _requiredString(json, 'status_label'),
      availableActions: _requiredStringListIn(
        json,
        'available_actions',
        _workflowActions,
      ),
      workflowSummary: WorkflowSummaryModel.fromJson(
        _requiredMap(json, 'workflow_summary'),
      ),
      comments:
          _requiredMapList(
            json,
            'comments',
          ).map(WorkflowTaskEntryModel.fromJson).toList(),
      statusHistory:
          _requiredMapList(
            json,
            'status_history',
          ).map(WorkflowTaskEntryModel.fromJson).toList(),
      createdAt: _requiredString(json, 'created_at'),
      updatedAt: _requiredString(json, 'updated_at'),
    );
  }
}

class WorkflowTaskListMeta {
  const WorkflowTaskListMeta({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  factory WorkflowTaskListMeta.fromJson(Map<String, dynamic> json) {
    return WorkflowTaskListMeta(
      currentPage: _requiredInt(json, 'current_page'),
      perPage: _requiredInt(json, 'per_page'),
      total: _requiredInt(json, 'total'),
      lastPage: _requiredInt(json, 'last_page'),
    );
  }
}

class WorkflowTaskListSummary {
  const WorkflowTaskListSummary({
    required this.byStatus,
    this.projectId,
    this.status,
    this.assignedToMe,
    this.search,
  });

  final Map<String, int> byStatus;
  final int? projectId;
  final String? status;
  final bool? assignedToMe;
  final String? search;

  factory WorkflowTaskListSummary.fromJson(Map<String, dynamic> json) {
    return WorkflowTaskListSummary(
      byStatus: _statusCountMap(_requiredMap(json, 'by_status')),
      projectId: _nullableInt(json['project_id']),
      status: _nullableStringIn(json['status'], _workflowStatuses),
      assignedToMe: _nullableBool(json['assigned_to_me']),
      search: _nullableString(json['search']),
    );
  }
}

class WorkflowTaskListResult {
  const WorkflowTaskListResult({
    required this.items,
    required this.meta,
    required this.summary,
  });

  final List<WorkflowTaskModel> items;
  final WorkflowTaskListMeta meta;
  final WorkflowTaskListSummary summary;

  factory WorkflowTaskListResult.fromJson(Map<String, dynamic> json) {
    return WorkflowTaskListResult(
      items:
          _requiredMapList(
            json,
            'items',
          ).map(WorkflowTaskModel.fromJson).toList(),
      meta: WorkflowTaskListMeta.fromJson(_requiredMap(json, 'meta')),
      summary: WorkflowTaskListSummary.fromJson(_requiredMap(json, 'summary')),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Missing integer field: $key');
  }

  return parsed;
}

int? _nullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    throw const FormatException('Invalid nullable integer field');
  }

  return parsed;
}

double? _nullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }

  final parsed = double.tryParse(value.toString());
  if (parsed == null) {
    throw const FormatException('Invalid nullable double field');
  }

  return parsed;
}

bool? _nullableBool(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }

  throw const FormatException('Invalid nullable bool field');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing string field: $key');
  }

  return value;
}

String _requiredStringIn(
  Map<String, dynamic> json,
  String key,
  Set<String> allowed,
) {
  return _stringInValue(_requiredString(json, key), key, allowed);
}

String _stringInValue(String value, String key, Set<String> allowed) {
  if (!allowed.contains(value)) {
    throw FormatException('Invalid string field: $key');
  }

  return value;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

String? _nullableStringIn(dynamic value, Set<String> allowed) {
  final text = _nullableString(value);
  if (text == null) {
    return null;
  }

  return _stringInValue(text, 'nullable_string', allowed);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return const <String, dynamic>{};
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing map field: $key');
  }

  final map = _asMap(json[key]);
  if (map.isEmpty) {
    throw FormatException('Invalid map field: $key');
  }

  return map;
}

List<Map<String, dynamic>> _requiredMapList(
  Map<String, dynamic> json,
  String key,
) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing list field: $key');
  }

  final value = json[key];
  if (value is! List) {
    throw FormatException('Invalid list field: $key');
  }

  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}

List<String> _requiredStringListIn(
  Map<String, dynamic> json,
  String key,
  Set<String> allowed,
) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing list field: $key');
  }

  final value = json[key];
  if (value is! List) {
    throw FormatException('Invalid list field: $key');
  }

  return value
      .map((item) => _stringInValue(item.toString(), key, allowed))
      .toList(growable: false);
}

Map<String, int> _statusCountMap(Map<String, dynamic> map) {
  return map.map((key, value) {
    final status = _stringInValue(key, 'by_status', _workflowStatuses);
    final count = _nullableInt(value);
    if (count == null) {
      throw const FormatException('Invalid status count');
    }

    return MapEntry(status, count);
  });
}

const _workflowStatuses = {
  'draft',
  'pending',
  'in_review',
  'confirmed',
  'cancelled',
  'rejected',
};

const _workflowActions = {'approve', 'reject', 'request_changes', 'comment'};

const _workflowOrigins = {'manual', 'schedule', 'journal'};

const _planningStatuses = {'planned', 'requires_schedule'};
