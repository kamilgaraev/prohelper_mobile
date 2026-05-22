class BudgetProjectModel {
  const BudgetProjectModel({
    required this.id,
    required this.name,
    required this.status,
    this.budgetAmount,
  });

  final int id;
  final String name;
  final String status;
  final double? budgetAmount;

  factory BudgetProjectModel.fromJson(Map<String, dynamic> json) {
    return BudgetProjectModel(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      status: _requiredString(json, 'status'),
      budgetAmount: _nullableDouble(json['budget_amount']),
    );
  }
}

class BudgetTotalsModel {
  const BudgetTotalsModel({
    required this.estimatesCount,
    required this.byStatus,
    required this.totalAmount,
    required this.totalAmountWithVat,
    required this.approvedAmountWithVat,
    required this.inReviewCount,
  });

  final int estimatesCount;
  final Map<String, int> byStatus;
  final double totalAmount;
  final double totalAmountWithVat;
  final double approvedAmountWithVat;
  final int inReviewCount;

  factory BudgetTotalsModel.fromJson(Map<String, dynamic> json) {
    return BudgetTotalsModel(
      estimatesCount: _requiredInt(json, 'estimates_count'),
      byStatus: _statusCountMap(_requiredMap(json, 'by_status')),
      totalAmount: _requiredDouble(json, 'total_amount'),
      totalAmountWithVat: _requiredDouble(json, 'total_amount_with_vat'),
      approvedAmountWithVat: _requiredDouble(json, 'approved_amount_with_vat'),
      inReviewCount: _requiredInt(json, 'in_review_count'),
    );
  }
}

class BudgetRemainingModel {
  const BudgetRemainingModel({
    required this.approvedEstimateAmount,
    required this.approvedChangeDelta,
    required this.pendingChangeDelta,
    required this.committedAmount,
    this.projectBudgetAmount,
    this.budgetRemaining,
  });

  final double? projectBudgetAmount;
  final double approvedEstimateAmount;
  final double approvedChangeDelta;
  final double pendingChangeDelta;
  final double committedAmount;
  final double? budgetRemaining;

  factory BudgetRemainingModel.fromJson(Map<String, dynamic> json) {
    return BudgetRemainingModel(
      projectBudgetAmount: _nullableDouble(json['project_budget_amount']),
      approvedEstimateAmount: _requiredDouble(json, 'approved_estimate_amount'),
      approvedChangeDelta: _requiredDouble(json, 'approved_change_delta'),
      pendingChangeDelta: _requiredDouble(json, 'pending_change_delta'),
      committedAmount: _requiredDouble(json, 'committed_amount'),
      budgetRemaining: _nullableDouble(json['budget_remaining']),
    );
  }
}

class BudgetEstimateApprovalSummaryModel {
  const BudgetEstimateApprovalSummaryModel({
    required this.status,
    required this.statusLabel,
    required this.availableActions,
    this.approvedByUserId,
    this.approvedByLabel,
    this.approvedAt,
  });

  final String status;
  final String statusLabel;
  final int? approvedByUserId;
  final String? approvedByLabel;
  final String? approvedAt;
  final List<String> availableActions;

  factory BudgetEstimateApprovalSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return BudgetEstimateApprovalSummaryModel(
      status: _requiredStringIn(json, 'status', _estimateStatuses),
      statusLabel: _requiredString(json, 'status_label'),
      approvedByUserId: _nullableInt(json['approved_by_user_id']),
      approvedByLabel: _nullableString(json['approved_by_label']),
      approvedAt: _nullableString(json['approved_at']),
      availableActions: _requiredStringListIn(
        json,
        'available_actions',
        _estimateActions,
      ),
    );
  }
}

class BudgetEstimateTotalsModel {
  const BudgetEstimateTotalsModel({
    required this.directCosts,
    required this.overheadCosts,
    required this.estimatedProfit,
    required this.equipmentCosts,
    required this.amount,
    required this.amountWithVat,
    required this.vatRate,
    required this.overheadRate,
    required this.profitRate,
  });

  final double directCosts;
  final double overheadCosts;
  final double estimatedProfit;
  final double equipmentCosts;
  final double amount;
  final double amountWithVat;
  final double vatRate;
  final double overheadRate;
  final double profitRate;

  factory BudgetEstimateTotalsModel.fromJson(Map<String, dynamic> json) {
    return BudgetEstimateTotalsModel(
      directCosts: _requiredDouble(json, 'direct_costs'),
      overheadCosts: _requiredDouble(json, 'overhead_costs'),
      estimatedProfit: _requiredDouble(json, 'estimated_profit'),
      equipmentCosts: _requiredDouble(json, 'equipment_costs'),
      amount: _requiredDouble(json, 'amount'),
      amountWithVat: _requiredDouble(json, 'amount_with_vat'),
      vatRate: _requiredDouble(json, 'vat_rate'),
      overheadRate: _requiredDouble(json, 'overhead_rate'),
      profitRate: _requiredDouble(json, 'profit_rate'),
    );
  }
}

class BudgetEstimateStatisticsModel {
  const BudgetEstimateStatisticsModel({
    required this.sectionsCount,
    required this.itemsCount,
  });

  final int sectionsCount;
  final int itemsCount;

  factory BudgetEstimateStatisticsModel.fromJson(Map<String, dynamic> json) {
    return BudgetEstimateStatisticsModel(
      sectionsCount: _requiredInt(json, 'sections_count'),
      itemsCount: _requiredInt(json, 'items_count'),
    );
  }
}

class BudgetEstimateLineItemModel {
  const BudgetEstimateLineItemModel({
    required this.id,
    required this.estimateId,
    required this.name,
    required this.itemType,
    this.estimateSectionId,
    this.positionNumber,
    this.measurementUnitLabel,
    this.quantity,
    this.quantityTotal,
    this.unitPrice,
    this.currentUnitPrice,
    this.totalAmount,
    this.currentTotalAmount,
    this.procurementStatus,
  });

  final int id;
  final int estimateId;
  final int? estimateSectionId;
  final String? positionNumber;
  final String name;
  final String itemType;
  final String? measurementUnitLabel;
  final double? quantity;
  final double? quantityTotal;
  final double? unitPrice;
  final double? currentUnitPrice;
  final double? totalAmount;
  final double? currentTotalAmount;
  final String? procurementStatus;

  factory BudgetEstimateLineItemModel.fromJson(Map<String, dynamic> json) {
    return BudgetEstimateLineItemModel(
      id: _requiredInt(json, 'id'),
      estimateId: _requiredInt(json, 'estimate_id'),
      estimateSectionId: _nullableInt(json['estimate_section_id']),
      positionNumber: _nullableString(json['position_number']),
      name: _requiredString(json, 'name'),
      itemType: _requiredStringIn(json, 'item_type', _estimateItemTypes),
      measurementUnitLabel: _nullableString(json['measurement_unit_label']),
      quantity: _nullableDouble(json['quantity']),
      quantityTotal: _nullableDouble(json['quantity_total']),
      unitPrice: _nullableDouble(json['unit_price']),
      currentUnitPrice: _nullableDouble(json['current_unit_price']),
      totalAmount: _nullableDouble(json['total_amount']),
      currentTotalAmount: _nullableDouble(json['current_total_amount']),
      procurementStatus: _nullableString(json['procurement_status']),
    );
  }
}

class BudgetEstimateLineGroupModel {
  const BudgetEstimateLineGroupModel({
    required this.id,
    required this.estimateId,
    required this.sectionNumber,
    required this.name,
    required this.sortOrder,
    required this.isSummary,
    required this.totalAmount,
    required this.items,
    this.parentSectionId,
    this.description,
  });

  final int id;
  final int estimateId;
  final int? parentSectionId;
  final String sectionNumber;
  final String name;
  final String? description;
  final int sortOrder;
  final bool isSummary;
  final double totalAmount;
  final List<BudgetEstimateLineItemModel> items;

  factory BudgetEstimateLineGroupModel.fromJson(Map<String, dynamic> json) {
    return BudgetEstimateLineGroupModel(
      id: _requiredInt(json, 'id'),
      estimateId: _requiredInt(json, 'estimate_id'),
      parentSectionId: _nullableInt(json['parent_section_id']),
      sectionNumber: _requiredString(json, 'section_number'),
      name: _requiredString(json, 'name'),
      description: _nullableString(json['description']),
      sortOrder: _requiredInt(json, 'sort_order'),
      isSummary: _requiredBool(json, 'is_summary'),
      totalAmount: _requiredDouble(json, 'total_amount'),
      items:
          _requiredMapList(
            json,
            'items',
          ).map(BudgetEstimateLineItemModel.fromJson).toList(),
    );
  }
}

class BudgetEstimateModel {
  const BudgetEstimateModel({
    required this.id,
    required this.organizationId,
    required this.projectId,
    required this.number,
    required this.name,
    required this.type,
    required this.status,
    required this.statusLabel,
    required this.version,
    required this.totals,
    required this.statistics,
    required this.approvalSummary,
    required this.availableActions,
    required this.lineGroups,
    required this.unsectionedItems,
    required this.createdAt,
    required this.updatedAt,
    this.projectLabel,
    this.contractId,
    this.description,
    this.estimateDate,
    this.basePriceDate,
  });

  final int id;
  final int organizationId;
  final int projectId;
  final String? projectLabel;
  final int? contractId;
  final String number;
  final String name;
  final String? description;
  final String type;
  final String status;
  final String statusLabel;
  final int version;
  final String? estimateDate;
  final String? basePriceDate;
  final BudgetEstimateTotalsModel totals;
  final BudgetEstimateStatisticsModel statistics;
  final BudgetEstimateApprovalSummaryModel approvalSummary;
  final List<String> availableActions;
  final List<BudgetEstimateLineGroupModel> lineGroups;
  final List<BudgetEstimateLineItemModel> unsectionedItems;
  final String createdAt;
  final String updatedAt;

  bool get canApprove => availableActions.contains('approve');
  bool get canRequestChanges => availableActions.contains('request_changes');

  factory BudgetEstimateModel.fromJson(Map<String, dynamic> json) {
    return BudgetEstimateModel(
      id: _requiredInt(json, 'id'),
      organizationId: _requiredInt(json, 'organization_id'),
      projectId: _requiredInt(json, 'project_id'),
      projectLabel: _nullableString(json['project_label']),
      contractId: _nullableInt(json['contract_id']),
      number: _requiredString(json, 'number'),
      name: _requiredString(json, 'name'),
      description: _nullableString(json['description']),
      type: _requiredString(json, 'type'),
      status: _requiredStringIn(json, 'status', _estimateStatuses),
      statusLabel: _requiredString(json, 'status_label'),
      version: _requiredInt(json, 'version'),
      estimateDate: _nullableString(json['estimate_date']),
      basePriceDate: _nullableString(json['base_price_date']),
      totals: BudgetEstimateTotalsModel.fromJson(_requiredMap(json, 'totals')),
      statistics: BudgetEstimateStatisticsModel.fromJson(
        _requiredMap(json, 'statistics'),
      ),
      approvalSummary: BudgetEstimateApprovalSummaryModel.fromJson(
        _requiredMap(json, 'approval_summary'),
      ),
      availableActions: _requiredStringListIn(
        json,
        'available_actions',
        _estimateActions,
      ),
      lineGroups:
          _requiredMapList(
            json,
            'line_groups',
          ).map(BudgetEstimateLineGroupModel.fromJson).toList(),
      unsectionedItems:
          _requiredMapList(
            json,
            'unsectioned_items',
          ).map(BudgetEstimateLineItemModel.fromJson).toList(),
      createdAt: _requiredString(json, 'created_at'),
      updatedAt: _requiredString(json, 'updated_at'),
    );
  }
}

class BudgetChangeRequestModel {
  const BudgetChangeRequestModel({
    required this.id,
    required this.projectId,
    required this.changeNumber,
    required this.title,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.requiresEstimateRevision,
    required this.affectedEstimateItemIds,
    required this.createdAt,
    this.costDelta,
    this.scheduleDeltaDays,
    this.approvedAt,
  });

  final int id;
  final int projectId;
  final String changeNumber;
  final String title;
  final String reason;
  final String status;
  final String statusLabel;
  final double? costDelta;
  final int? scheduleDeltaDays;
  final bool requiresEstimateRevision;
  final List<int> affectedEstimateItemIds;
  final String createdAt;
  final String? approvedAt;

  factory BudgetChangeRequestModel.fromJson(Map<String, dynamic> json) {
    return BudgetChangeRequestModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      changeNumber: _requiredString(json, 'change_number'),
      title: _requiredString(json, 'title'),
      reason: _requiredString(json, 'reason'),
      status: _requiredStringIn(json, 'status', _changeStatuses),
      statusLabel: _requiredString(json, 'status_label'),
      costDelta: _nullableDouble(json['cost_delta']),
      scheduleDeltaDays: _nullableInt(json['schedule_delta_days']),
      requiresEstimateRevision: _requiredBool(
        json,
        'requires_estimate_revision',
      ),
      affectedEstimateItemIds: _requiredIntList(
        json,
        'affected_estimate_item_ids',
      ),
      createdAt: _requiredString(json, 'created_at'),
      approvedAt: _nullableString(json['approved_at']),
    );
  }
}

class BudgetEstimateSummaryModel {
  const BudgetEstimateSummaryModel({
    required this.project,
    required this.totals,
    required this.budget,
    required this.estimates,
    required this.linkedChangeRequests,
    required this.assignedApprovals,
  });

  final BudgetProjectModel project;
  final BudgetTotalsModel totals;
  final BudgetRemainingModel budget;
  final List<BudgetEstimateModel> estimates;
  final List<BudgetChangeRequestModel> linkedChangeRequests;
  final List<BudgetEstimateModel> assignedApprovals;

  factory BudgetEstimateSummaryModel.fromJson(Map<String, dynamic> json) {
    return BudgetEstimateSummaryModel(
      project: BudgetProjectModel.fromJson(_requiredMap(json, 'project')),
      totals: BudgetTotalsModel.fromJson(_requiredMap(json, 'totals')),
      budget: BudgetRemainingModel.fromJson(_requiredMap(json, 'budget')),
      estimates:
          _requiredMapList(
            json,
            'estimates',
          ).map(BudgetEstimateModel.fromJson).toList(),
      linkedChangeRequests:
          _requiredMapList(
            json,
            'linked_change_requests',
          ).map(BudgetChangeRequestModel.fromJson).toList(),
      assignedApprovals:
          _requiredMapList(
            json,
            'assigned_approvals',
          ).map(BudgetEstimateModel.fromJson).toList(),
    );
  }
}

class BudgetEstimateDetailModel {
  const BudgetEstimateDetailModel({
    required this.estimate,
    required this.linkedChangeRequests,
  });

  final BudgetEstimateModel estimate;
  final List<BudgetChangeRequestModel> linkedChangeRequests;

  factory BudgetEstimateDetailModel.fromJson(Map<String, dynamic> json) {
    return BudgetEstimateDetailModel(
      estimate: BudgetEstimateModel.fromJson(_requiredMap(json, 'estimate')),
      linkedChangeRequests:
          _requiredMapList(
            json,
            'linked_change_requests',
          ).map(BudgetChangeRequestModel.fromJson).toList(),
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

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = _nullableDouble(json[key]);
  if (value == null) {
    throw FormatException('Missing double field: $key');
  }

  return value;
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

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing bool field: $key');
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
      .map((item) {
        if (item is! Map) {
          throw FormatException('Invalid list item: $key');
        }

        return item.map((key, value) => MapEntry(key.toString(), value));
      })
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

List<int> _requiredIntList(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing list field: $key');
  }

  final value = json[key];
  if (value is! List) {
    throw FormatException('Invalid list field: $key');
  }

  return value
      .map((item) {
        final parsed = _nullableInt(item);
        if (parsed == null) {
          throw FormatException('Invalid list item: $key');
        }

        return parsed;
      })
      .toList(growable: false);
}

Map<String, int> _statusCountMap(Map<String, dynamic> map) {
  return map.map((key, value) {
    final status = _stringInValue(key, 'by_status', _estimateStatuses);
    final count = _nullableInt(value);
    if (count == null) {
      throw const FormatException('Invalid status count');
    }

    return MapEntry(status, count);
  });
}

const _estimateStatuses = {'draft', 'in_review', 'approved', 'cancelled'};

const _estimateActions = {'approve', 'request_changes'};

const _estimateItemTypes = {
  'work',
  'material',
  'equipment',
  'labor',
  'summary',
  'machinery',
};

const _changeStatuses = {
  'draft',
  'submitted',
  'impact_assessment',
  'internal_review',
  'customer_review',
  'approved',
  'implemented',
  'closed',
  'rejected',
  'cancelled',
};
