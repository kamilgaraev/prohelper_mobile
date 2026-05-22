class ProcurementSummaryModel {
  const ProcurementSummaryModel({
    required this.counters,
    required this.purchaseRequests,
    required this.purchaseOrders,
    required this.assignedApprovals,
    required this.warehouses,
  });

  final ProcurementSummaryCounters counters;
  final List<ProcurementPurchaseRequestModel> purchaseRequests;
  final List<ProcurementPurchaseOrderModel> purchaseOrders;
  final List<ProcurementApprovalModel> assignedApprovals;
  final List<ProcurementWarehouseModel> warehouses;

  factory ProcurementSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProcurementSummaryModel(
      counters: ProcurementSummaryCounters.fromJson(
        _requiredMap(json, 'summary'),
      ),
      purchaseRequests: _requiredMapList(
        json,
        'purchase_requests',
      ).map(ProcurementPurchaseRequestModel.fromJson).toList(growable: false),
      purchaseOrders: _requiredMapList(
        json,
        'purchase_orders',
      ).map(ProcurementPurchaseOrderModel.fromJson).toList(growable: false),
      assignedApprovals: _requiredMapList(
        json,
        'assigned_approvals',
      ).map(ProcurementApprovalModel.fromJson).toList(growable: false),
      warehouses: _requiredMapList(
        json,
        'warehouses',
      ).map(ProcurementWarehouseModel.fromJson).toList(growable: false),
    );
  }

  bool get isEmpty =>
      purchaseRequests.isEmpty &&
      purchaseOrders.isEmpty &&
      assignedApprovals.isEmpty;
}

class ProcurementSummaryCounters {
  const ProcurementSummaryCounters({
    required this.purchaseRequestsCount,
    required this.pendingRequestsCount,
    required this.purchaseOrdersCount,
    required this.receivableOrdersCount,
    required this.pendingApprovalsCount,
  });

  final int purchaseRequestsCount;
  final int pendingRequestsCount;
  final int purchaseOrdersCount;
  final int receivableOrdersCount;
  final int pendingApprovalsCount;

  factory ProcurementSummaryCounters.fromJson(Map<String, dynamic> json) {
    return ProcurementSummaryCounters(
      purchaseRequestsCount: _requiredInt(json, 'purchase_requests_count'),
      pendingRequestsCount: _requiredInt(json, 'pending_requests_count'),
      purchaseOrdersCount: _requiredInt(json, 'purchase_orders_count'),
      receivableOrdersCount: _requiredInt(json, 'receivable_orders_count'),
      pendingApprovalsCount: _requiredInt(json, 'pending_approvals_count'),
    );
  }
}

class ProcurementWarehouseModel {
  const ProcurementWarehouseModel({
    required this.id,
    required this.name,
    required this.isMain,
    this.code,
    this.address,
    this.warehouseType,
  });

  final int id;
  final String name;
  final bool isMain;
  final String? code;
  final String? address;
  final String? warehouseType;

  factory ProcurementWarehouseModel.fromJson(Map<String, dynamic> json) {
    return ProcurementWarehouseModel(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      isMain: _requiredBool(json, 'is_main'),
      code: _optionalString(json, 'code'),
      address: _optionalString(json, 'address'),
      warehouseType: _optionalString(json, 'warehouse_type'),
    );
  }
}

class ProcurementPurchaseRequestModel {
  const ProcurementPurchaseRequestModel({
    required this.id,
    required this.organizationId,
    required this.requestNumber,
    required this.status,
    required this.statusLabel,
    required this.statistics,
    required this.lines,
    required this.purchaseOrders,
    this.siteRequestId,
    this.neededBy,
    this.budgetAmount,
    this.budgetCurrency,
    this.notes,
    this.assignedUserLabel,
    this.siteRequest,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int organizationId;
  final int? siteRequestId;
  final String requestNumber;
  final String status;
  final String statusLabel;
  final String? neededBy;
  final double? budgetAmount;
  final String? budgetCurrency;
  final String? notes;
  final String? assignedUserLabel;
  final ProcurementSiteRequestModel? siteRequest;
  final ProcurementPurchaseRequestStatistics statistics;
  final List<ProcurementPurchaseRequestLineModel> lines;
  final List<ProcurementPurchaseRequestOrderModel> purchaseOrders;
  final String? createdAt;
  final String? updatedAt;

  factory ProcurementPurchaseRequestModel.fromJson(Map<String, dynamic> json) {
    return ProcurementPurchaseRequestModel(
      id: _requiredInt(json, 'id'),
      organizationId: _requiredInt(json, 'organization_id'),
      siteRequestId: _optionalInt(json, 'site_request_id'),
      requestNumber: _requiredString(json, 'request_number'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      neededBy: _optionalString(json, 'needed_by'),
      budgetAmount: _optionalDouble(json, 'budget_amount'),
      budgetCurrency: _optionalString(json, 'budget_currency'),
      notes: _optionalString(json, 'notes'),
      assignedUserLabel: _optionalString(json, 'assigned_user_label'),
      siteRequest:
          _optionalMap(json, 'site_request') == null
              ? null
              : ProcurementSiteRequestModel.fromJson(
                _requiredMap(json, 'site_request'),
              ),
      statistics: ProcurementPurchaseRequestStatistics.fromJson(
        _requiredMap(json, 'statistics'),
      ),
      lines: _requiredMapList(json, 'lines')
          .map(ProcurementPurchaseRequestLineModel.fromJson)
          .toList(growable: false),
      purchaseOrders: _requiredMapList(json, 'purchase_orders')
          .map(ProcurementPurchaseRequestOrderModel.fromJson)
          .toList(growable: false),
      createdAt: _optionalString(json, 'created_at'),
      updatedAt: _optionalString(json, 'updated_at'),
    );
  }

  String get title => siteRequest?.title ?? requestNumber;
  String? get projectLabel => siteRequest?.projectLabel;
}

class ProcurementSiteRequestModel {
  const ProcurementSiteRequestModel({
    required this.id,
    required this.title,
    this.projectId,
    this.projectLabel,
    this.requiredDate,
  });

  final int id;
  final String title;
  final int? projectId;
  final String? projectLabel;
  final String? requiredDate;

  factory ProcurementSiteRequestModel.fromJson(Map<String, dynamic> json) {
    return ProcurementSiteRequestModel(
      id: _requiredInt(json, 'id'),
      title: _requiredString(json, 'title'),
      projectId: _optionalInt(json, 'project_id'),
      projectLabel: _optionalString(json, 'project_label'),
      requiredDate: _optionalString(json, 'required_date'),
    );
  }
}

class ProcurementPurchaseRequestStatistics {
  const ProcurementPurchaseRequestStatistics({
    required this.linesCount,
    required this.supplierRequestsCount,
    required this.purchaseOrdersCount,
  });

  final int linesCount;
  final int supplierRequestsCount;
  final int purchaseOrdersCount;

  factory ProcurementPurchaseRequestStatistics.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProcurementPurchaseRequestStatistics(
      linesCount: _requiredInt(json, 'lines_count'),
      supplierRequestsCount: _requiredInt(json, 'supplier_requests_count'),
      purchaseOrdersCount: _requiredInt(json, 'purchase_orders_count'),
    );
  }
}

class ProcurementPurchaseRequestLineModel {
  const ProcurementPurchaseRequestLineModel({
    required this.id,
    required this.name,
    required this.quantity,
    this.materialId,
    this.unit,
    this.specification,
    this.neededBy,
  });

  final int id;
  final int? materialId;
  final String name;
  final double quantity;
  final String? unit;
  final String? specification;
  final String? neededBy;

  factory ProcurementPurchaseRequestLineModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProcurementPurchaseRequestLineModel(
      id: _requiredInt(json, 'id'),
      materialId: _optionalInt(json, 'material_id'),
      name: _requiredString(json, 'name'),
      quantity: _requiredDouble(json, 'quantity'),
      unit: _optionalString(json, 'unit'),
      specification: _optionalString(json, 'specification'),
      neededBy: _optionalString(json, 'needed_by'),
    );
  }
}

class ProcurementPurchaseRequestOrderModel {
  const ProcurementPurchaseRequestOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.currency,
  });

  final int id;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final String? currency;

  factory ProcurementPurchaseRequestOrderModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProcurementPurchaseRequestOrderModel(
      id: _requiredInt(json, 'id'),
      orderNumber: _requiredString(json, 'order_number'),
      status: _requiredString(json, 'status'),
      totalAmount: _requiredDouble(json, 'total_amount'),
      currency: _optionalString(json, 'currency'),
    );
  }
}

class ProcurementOrderDetailModel {
  const ProcurementOrderDetailModel({
    required this.order,
    required this.warehouses,
  });

  final ProcurementPurchaseOrderModel order;
  final List<ProcurementWarehouseModel> warehouses;

  factory ProcurementOrderDetailModel.fromJson(Map<String, dynamic> json) {
    return ProcurementOrderDetailModel(
      order: ProcurementPurchaseOrderModel.fromJson(
        _requiredMap(json, 'order'),
      ),
      warehouses: _requiredMapList(
        json,
        'warehouses',
      ).map(ProcurementWarehouseModel.fromJson).toList(growable: false),
    );
  }
}

class ProcurementPurchaseOrderModel {
  const ProcurementPurchaseOrderModel({
    required this.id,
    required this.organizationId,
    required this.purchaseRequestId,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.totalAmount,
    required this.supplier,
    required this.statistics,
    required this.availableActions,
    required this.items,
    required this.receipts,
    required this.comments,
    this.orderDate,
    this.currency,
    this.deliveryDate,
    this.sentAt,
    this.confirmedAt,
    this.notes,
    this.purchaseRequest,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int organizationId;
  final int purchaseRequestId;
  final String orderNumber;
  final String? orderDate;
  final String status;
  final String statusLabel;
  final double totalAmount;
  final String? currency;
  final String? deliveryDate;
  final String? sentAt;
  final String? confirmedAt;
  final String? notes;
  final ProcurementSupplierModel supplier;
  final ProcurementOrderRequestReferenceModel? purchaseRequest;
  final ProcurementOrderStatistics statistics;
  final List<String> availableActions;
  final List<ProcurementPurchaseOrderItemModel> items;
  final List<ProcurementPurchaseReceiptModel> receipts;
  final List<ProcurementOrderCommentModel> comments;
  final String? createdAt;
  final String? updatedAt;

  factory ProcurementPurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return ProcurementPurchaseOrderModel(
      id: _requiredInt(json, 'id'),
      organizationId: _requiredInt(json, 'organization_id'),
      purchaseRequestId: _requiredInt(json, 'purchase_request_id'),
      orderNumber: _requiredString(json, 'order_number'),
      orderDate: _optionalString(json, 'order_date'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      totalAmount: _requiredDouble(json, 'total_amount'),
      currency: _optionalString(json, 'currency'),
      deliveryDate: _optionalString(json, 'delivery_date'),
      sentAt: _optionalString(json, 'sent_at'),
      confirmedAt: _optionalString(json, 'confirmed_at'),
      notes: _optionalString(json, 'notes'),
      supplier: ProcurementSupplierModel.fromJson(
        _requiredMap(json, 'supplier'),
      ),
      purchaseRequest:
          _optionalMap(json, 'purchase_request') == null
              ? null
              : ProcurementOrderRequestReferenceModel.fromJson(
                _requiredMap(json, 'purchase_request'),
              ),
      statistics: ProcurementOrderStatistics.fromJson(
        _requiredMap(json, 'statistics'),
      ),
      availableActions: _requiredStringList(json, 'available_actions'),
      items: _requiredMapList(
        json,
        'items',
      ).map(ProcurementPurchaseOrderItemModel.fromJson).toList(growable: false),
      receipts: _requiredMapList(
        json,
        'receipts',
      ).map(ProcurementPurchaseReceiptModel.fromJson).toList(growable: false),
      comments: _requiredMapList(
        json,
        'comments',
      ).map(ProcurementOrderCommentModel.fromJson).toList(growable: false),
      createdAt: _optionalString(json, 'created_at'),
      updatedAt: _optionalString(json, 'updated_at'),
    );
  }

  bool get canReceiveMaterials =>
      availableActions.contains('receive_materials');
  bool get canComment => availableActions.contains('comment');

  double get remainingQuantity {
    return items.fold<double>(0, (sum, item) => sum + item.remainingQuantity);
  }
}

class ProcurementSupplierModel {
  const ProcurementSupplierModel({this.id, this.label, this.partyId});

  final int? id;
  final String? label;
  final int? partyId;

  factory ProcurementSupplierModel.fromJson(Map<String, dynamic> json) {
    return ProcurementSupplierModel(
      id: _optionalInt(json, 'id'),
      label: _optionalString(json, 'label'),
      partyId: _optionalInt(json, 'party_id'),
    );
  }
}

class ProcurementOrderRequestReferenceModel {
  const ProcurementOrderRequestReferenceModel({
    required this.id,
    required this.requestNumber,
    required this.status,
    this.siteRequestId,
    this.siteRequestTitle,
    this.projectId,
    this.projectLabel,
  });

  final int id;
  final String requestNumber;
  final String status;
  final int? siteRequestId;
  final String? siteRequestTitle;
  final int? projectId;
  final String? projectLabel;

  factory ProcurementOrderRequestReferenceModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProcurementOrderRequestReferenceModel(
      id: _requiredInt(json, 'id'),
      requestNumber: _requiredString(json, 'request_number'),
      status: _requiredString(json, 'status'),
      siteRequestId: _optionalInt(json, 'site_request_id'),
      siteRequestTitle: _optionalString(json, 'site_request_title'),
      projectId: _optionalInt(json, 'project_id'),
      projectLabel: _optionalString(json, 'project_label'),
    );
  }
}

class ProcurementOrderStatistics {
  const ProcurementOrderStatistics({
    required this.itemsCount,
    required this.receiptsCount,
    required this.receivedItemsCount,
  });

  final int itemsCount;
  final int receiptsCount;
  final int receivedItemsCount;

  factory ProcurementOrderStatistics.fromJson(Map<String, dynamic> json) {
    return ProcurementOrderStatistics(
      itemsCount: _requiredInt(json, 'items_count'),
      receiptsCount: _requiredInt(json, 'receipts_count'),
      receivedItemsCount: _requiredInt(json, 'received_items_count'),
    );
  }
}

class ProcurementPurchaseOrderItemModel {
  const ProcurementPurchaseOrderItemModel({
    required this.id,
    required this.materialName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    required this.receivedQuantity,
    required this.remainingQuantity,
    this.materialId,
    this.notes,
  });

  final int id;
  final int? materialId;
  final String materialName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final double receivedQuantity;
  final double remainingQuantity;
  final String? notes;

  factory ProcurementPurchaseOrderItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProcurementPurchaseOrderItemModel(
      id: _requiredInt(json, 'id'),
      materialId: _optionalInt(json, 'material_id'),
      materialName: _requiredString(json, 'material_name'),
      quantity: _requiredDouble(json, 'quantity'),
      unit: _requiredString(json, 'unit'),
      unitPrice: _requiredDouble(json, 'unit_price'),
      totalPrice: _requiredDouble(json, 'total_price'),
      receivedQuantity: _requiredDouble(json, 'received_quantity'),
      remainingQuantity: _requiredDouble(json, 'remaining_quantity'),
      notes: _optionalString(json, 'notes'),
    );
  }
}

class ProcurementPurchaseReceiptModel {
  const ProcurementPurchaseReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.status,
    required this.lines,
    this.receiptDate,
    this.warehouse,
    this.receivedByLabel,
    this.notes,
  });

  final int id;
  final String receiptNumber;
  final String? receiptDate;
  final String status;
  final ProcurementReceiptWarehouseModel? warehouse;
  final String? receivedByLabel;
  final String? notes;
  final List<ProcurementPurchaseReceiptLineModel> lines;

  factory ProcurementPurchaseReceiptModel.fromJson(Map<String, dynamic> json) {
    return ProcurementPurchaseReceiptModel(
      id: _requiredInt(json, 'id'),
      receiptNumber: _requiredString(json, 'receipt_number'),
      receiptDate: _optionalString(json, 'receipt_date'),
      status: _requiredString(json, 'status'),
      warehouse:
          _optionalMap(json, 'warehouse') == null
              ? null
              : ProcurementReceiptWarehouseModel.fromJson(
                _requiredMap(json, 'warehouse'),
              ),
      receivedByLabel: _optionalString(json, 'received_by_label'),
      notes: _optionalString(json, 'notes'),
      lines: _requiredMapList(json, 'lines')
          .map(ProcurementPurchaseReceiptLineModel.fromJson)
          .toList(growable: false),
    );
  }
}

class ProcurementReceiptWarehouseModel {
  const ProcurementReceiptWarehouseModel({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ProcurementReceiptWarehouseModel.fromJson(Map<String, dynamic> json) {
    return ProcurementReceiptWarehouseModel(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
    );
  }
}

class ProcurementPurchaseReceiptLineModel {
  const ProcurementPurchaseReceiptLineModel({
    required this.id,
    required this.purchaseOrderItemId,
    required this.quantityReceived,
    required this.price,
    required this.totalAmount,
  });

  final int id;
  final int purchaseOrderItemId;
  final double quantityReceived;
  final double price;
  final double totalAmount;

  factory ProcurementPurchaseReceiptLineModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProcurementPurchaseReceiptLineModel(
      id: _requiredInt(json, 'id'),
      purchaseOrderItemId: _requiredInt(json, 'purchase_order_item_id'),
      quantityReceived: _requiredDouble(json, 'quantity_received'),
      price: _requiredDouble(json, 'price'),
      totalAmount: _requiredDouble(json, 'total_amount'),
    );
  }
}

class ProcurementOrderCommentModel {
  const ProcurementOrderCommentModel({
    required this.id,
    required this.comment,
    this.actorLabel,
    this.occurredAt,
  });

  final int id;
  final String comment;
  final String? actorLabel;
  final String? occurredAt;

  factory ProcurementOrderCommentModel.fromJson(Map<String, dynamic> json) {
    return ProcurementOrderCommentModel(
      id: _requiredInt(json, 'id'),
      comment: _requiredString(json, 'comment'),
      actorLabel: _optionalString(json, 'actor_label'),
      occurredAt: _optionalString(json, 'occurred_at'),
    );
  }
}

class ProcurementApprovalModel {
  const ProcurementApprovalModel({
    required this.id,
    required this.organizationId,
    required this.status,
    required this.statusLabel,
    required this.contextSummary,
    required this.canResolve,
    required this.resolutionBlockers,
    required this.availableActions,
    this.reasonCode,
    this.reasonLabel,
    this.requestedByLabel,
    this.approvedByLabel,
    this.rejectedByLabel,
    this.requestedAt,
    this.resolvedAt,
    this.comment,
    this.decisionSummary,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int organizationId;
  final String? reasonCode;
  final String? reasonLabel;
  final String status;
  final String statusLabel;
  final String? requestedByLabel;
  final String? approvedByLabel;
  final String? rejectedByLabel;
  final String? requestedAt;
  final String? resolvedAt;
  final String? comment;
  final ProcurementApprovalDecisionSummaryModel? decisionSummary;
  final ProcurementApprovalContextSummaryModel contextSummary;
  final bool canResolve;
  final List<ProcurementApprovalBlockerModel> resolutionBlockers;
  final List<String> availableActions;
  final String? createdAt;
  final String? updatedAt;

  factory ProcurementApprovalModel.fromJson(Map<String, dynamic> json) {
    return ProcurementApprovalModel(
      id: _requiredInt(json, 'id'),
      organizationId: _requiredInt(json, 'organization_id'),
      reasonCode: _optionalString(json, 'reason_code'),
      reasonLabel: _optionalString(json, 'reason_label'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      requestedByLabel: _optionalString(json, 'requested_by_label'),
      approvedByLabel: _optionalString(json, 'approved_by_label'),
      rejectedByLabel: _optionalString(json, 'rejected_by_label'),
      requestedAt: _optionalString(json, 'requested_at'),
      resolvedAt: _optionalString(json, 'resolved_at'),
      comment: _optionalString(json, 'comment'),
      decisionSummary:
          _optionalMap(json, 'decision_summary') == null
              ? null
              : ProcurementApprovalDecisionSummaryModel.fromJson(
                _requiredMap(json, 'decision_summary'),
              ),
      contextSummary: ProcurementApprovalContextSummaryModel.fromJson(
        _requiredMap(json, 'context_summary'),
      ),
      canResolve: _requiredBool(json, 'can_resolve'),
      resolutionBlockers: _requiredMapList(
        json,
        'resolution_blockers',
      ).map(ProcurementApprovalBlockerModel.fromJson).toList(growable: false),
      availableActions: _requiredStringList(json, 'available_actions'),
      createdAt: _optionalString(json, 'created_at'),
      updatedAt: _optionalString(json, 'updated_at'),
    );
  }

  bool get canApprove => availableActions.contains('approve');
  bool get canReject => availableActions.contains('reject');
}

class ProcurementApprovalDecisionSummaryModel {
  const ProcurementApprovalDecisionSummaryModel({
    required this.id,
    required this.status,
    required this.isLowestPriceSelected,
    this.supplierLabel,
    this.proposalId,
    this.proposalNumber,
    this.totalAmount,
    this.currency,
  });

  final int id;
  final String status;
  final String? supplierLabel;
  final int? proposalId;
  final String? proposalNumber;
  final double? totalAmount;
  final String? currency;
  final bool isLowestPriceSelected;

  factory ProcurementApprovalDecisionSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProcurementApprovalDecisionSummaryModel(
      id: _requiredInt(json, 'id'),
      status: _requiredString(json, 'status'),
      supplierLabel: _optionalString(json, 'supplier_label'),
      proposalId: _optionalInt(json, 'proposal_id'),
      proposalNumber: _optionalString(json, 'proposal_number'),
      totalAmount: _optionalDouble(json, 'total_amount'),
      currency: _optionalString(json, 'currency'),
      isLowestPriceSelected: _requiredBool(json, 'is_lowest_price_selected'),
    );
  }
}

class ProcurementApprovalContextSummaryModel {
  const ProcurementApprovalContextSummaryModel({
    this.selectedTotal,
    this.cheapestTotal,
    this.budgetAmount,
    this.deltaAmount,
    this.deltaPercent,
    this.currency,
    this.supplierLabel,
  });

  final double? selectedTotal;
  final double? cheapestTotal;
  final double? budgetAmount;
  final double? deltaAmount;
  final double? deltaPercent;
  final String? currency;
  final String? supplierLabel;

  factory ProcurementApprovalContextSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProcurementApprovalContextSummaryModel(
      selectedTotal: _optionalDouble(json, 'selected_total'),
      cheapestTotal: _optionalDouble(json, 'cheapest_total'),
      budgetAmount: _optionalDouble(json, 'budget_amount'),
      deltaAmount: _optionalDouble(json, 'delta_amount'),
      deltaPercent: _optionalDouble(json, 'delta_percent'),
      currency: _optionalString(json, 'currency'),
      supplierLabel: _optionalString(json, 'supplier_label'),
    );
  }
}

class ProcurementApprovalBlockerModel {
  const ProcurementApprovalBlockerModel({this.code, this.message});

  final String? code;
  final String? message;

  factory ProcurementApprovalBlockerModel.fromJson(Map<String, dynamic> json) {
    return ProcurementApprovalBlockerModel(
      code: _optionalString(json, 'code'),
      message: _optionalString(json, 'message'),
    );
  }
}

class ProcurementReceiveItemPayload {
  const ProcurementReceiveItemPayload({
    required this.itemId,
    required this.quantityReceived,
    required this.price,
  });

  final int itemId;
  final double quantityReceived;
  final double price;

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'quantity_received': quantityReceived,
      'price': price,
    };
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is Map) {
    return _toMap(value);
  }

  throw FormatException('Missing map field $field');
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }

  if (value is Map) {
    return _toMap(value);
  }

  throw FormatException('Invalid map field $field');
}

List<Map<String, dynamic>> _requiredMapList(
  Map<String, dynamic> json,
  String field,
) {
  final value = json[field];
  if (value is List) {
    return value
        .map((item) {
          if (item is Map) {
            return _toMap(item);
          }

          throw FormatException('Invalid list item field $field');
        })
        .toList(growable: false);
  }

  throw FormatException('Missing list field $field');
}

List<String> _requiredStringList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List) {
    return value
        .map((item) {
          if (item is String) {
            return item;
          }

          throw FormatException('Invalid string list field $field');
        })
        .toList(growable: false);
  }

  throw FormatException('Missing string list field $field');
}

Map<String, dynamic> _toMap(Map<dynamic, dynamic> value) {
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  throw FormatException('Missing string field $field');
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  throw FormatException('Invalid string field $field');
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Missing integer field $field');
}

int? _optionalInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Invalid integer field $field');
}

double _requiredDouble(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is num) {
    return value.toDouble();
  }

  throw FormatException('Missing numeric field $field');
}

double? _optionalDouble(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  throw FormatException('Invalid numeric field $field');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing boolean field $field');
}
