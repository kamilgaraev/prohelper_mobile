Map<String, dynamic> procurementSummaryJson() {
  return {
    'summary': {
      'purchase_requests_count': 1,
      'pending_requests_count': 1,
      'purchase_orders_count': 1,
      'receivable_orders_count': 1,
      'pending_approvals_count': 1,
    },
    'purchase_requests': [procurementPurchaseRequestJson()],
    'purchase_orders': [procurementPurchaseOrderJson()],
    'assigned_approvals': [procurementApprovalJson()],
    'warehouses': [procurementWarehouseJson()],
  };
}

Map<String, dynamic> procurementOrderDetailJson() {
  return {
    'order': procurementPurchaseOrderJson(),
    'warehouses': [procurementWarehouseJson()],
  };
}

Map<String, dynamic> procurementWarehouseJson() {
  return {
    'id': 44,
    'name': 'Основной склад',
    'code': 'WH-1',
    'address': 'Площадка 1',
    'warehouse_type': 'main',
    'is_main': true,
  };
}

Map<String, dynamic> procurementPurchaseRequestJson() {
  return {
    'id': 12,
    'organization_id': 4,
    'site_request_id': 31,
    'request_number': 'PR-12',
    'status': 'pending',
    'status_label': 'На согласовании',
    'needed_by': '2026-05-30',
    'budget_amount': 500000,
    'budget_currency': 'RUB',
    'notes': 'Материалы для секции А',
    'assigned_user_label': 'Иван Петров',
    'statistics': {
      'lines_count': 1,
      'supplier_requests_count': 1,
      'purchase_orders_count': 1,
    },
    'site_request': {
      'id': 31,
      'title': 'Поставка бетона',
      'project_id': 9,
      'project_label': 'Башня',
      'required_date': '2026-05-30',
    },
    'lines': [
      {
        'id': 101,
        'material_id': 77,
        'name': 'Бетон М300',
        'quantity': 5,
        'unit': 'м3',
        'specification': 'ГОСТ',
        'needed_by': '2026-05-30',
      },
    ],
    'purchase_orders': [
      {
        'id': 61,
        'order_number': 'PO-61',
        'status': 'confirmed',
        'total_amount': 400000,
        'currency': 'RUB',
      },
    ],
    'created_at': '2026-05-22T08:00:00Z',
    'updated_at': '2026-05-22T09:00:00Z',
  };
}

Map<String, dynamic> procurementPurchaseOrderJson({
  String status = 'confirmed',
  List<String> actions = const ['receive_materials', 'comment'],
  double receivedQuantity = 2,
  double remainingQuantity = 3,
}) {
  return {
    'id': 61,
    'organization_id': 4,
    'purchase_request_id': 12,
    'order_number': 'PO-61',
    'order_date': '2026-05-21',
    'status': status,
    'status_label': status == 'delivered' ? 'Поставлен' : 'Подтвержден',
    'total_amount': 400000,
    'currency': 'RUB',
    'delivery_date': '2026-05-29',
    'sent_at': '2026-05-21T08:00:00Z',
    'confirmed_at': '2026-05-21T09:00:00Z',
    'notes': 'Поставка утром',
    'supplier': {'id': 8, 'label': 'БетонПром', 'party_id': 18},
    'purchase_request': {
      'id': 12,
      'request_number': 'PR-12',
      'status': 'approved',
      'site_request_id': 31,
      'site_request_title': 'Поставка бетона',
      'project_id': 9,
      'project_label': 'Башня',
    },
    'statistics': {
      'items_count': 1,
      'receipts_count': receivedQuantity > 0 ? 1 : 0,
      'received_items_count': receivedQuantity > 0 ? 1 : 0,
    },
    'available_actions': actions,
    'items': [
      {
        'id': 701,
        'material_id': 77,
        'material_name': 'Бетон М300',
        'quantity': 5,
        'unit': 'м3',
        'unit_price': 80000,
        'total_price': 400000,
        'received_quantity': receivedQuantity,
        'remaining_quantity': remainingQuantity,
        'notes': 'Без добавок',
      },
    ],
    'receipts': [
      if (receivedQuantity > 0)
        {
          'id': 91,
          'receipt_number': 'RC-91',
          'receipt_date': '2026-05-22',
          'status': 'received',
          'warehouse': {'id': 44, 'name': 'Основной склад'},
          'received_by_label': 'Иван Петров',
          'notes': 'Принята первая часть',
          'lines': [
            {
              'id': 911,
              'purchase_order_item_id': 701,
              'quantity_received': receivedQuantity,
              'price': 80000,
              'total_amount': receivedQuantity * 80000,
            },
          ],
        },
    ],
    'comments': [
      {
        'id': 501,
        'comment': 'Поставка ожидается до обеда.',
        'actor_label': 'Иван Петров',
        'occurred_at': '2026-05-22T07:30:00Z',
      },
    ],
    'created_at': '2026-05-21T08:00:00Z',
    'updated_at': '2026-05-22T09:00:00Z',
  };
}

Map<String, dynamic> procurementApprovalJson({
  String status = 'pending',
  List<String> actions = const ['approve', 'reject'],
}) {
  return {
    'id': 21,
    'organization_id': 4,
    'reason_code': 'budget_exceeded',
    'reason_label': 'Превышение бюджета',
    'status': status,
    'status_label': status == 'approved' ? 'Согласовано' : 'Ожидает решения',
    'requested_by_label': 'Мария Иванова',
    'approved_by_label': null,
    'rejected_by_label': null,
    'requested_at': '2026-05-22T06:00:00Z',
    'resolved_at': null,
    'comment': 'Нужно согласование',
    'decision_summary': {
      'id': 88,
      'status': 'pending',
      'supplier_label': 'БетонПром',
      'proposal_id': 77,
      'proposal_number': 'SP-77',
      'total_amount': 400000,
      'currency': 'RUB',
      'is_lowest_price_selected': false,
    },
    'context_summary': {
      'selected_total': 400000,
      'cheapest_total': 360000,
      'budget_amount': 350000,
      'delta_amount': 50000,
      'delta_percent': 14.29,
      'currency': 'RUB',
      'supplier_label': 'БетонПром',
    },
    'can_resolve': actions.isNotEmpty,
    'resolution_blockers': const [],
    'available_actions': actions,
    'created_at': '2026-05-22T06:00:00Z',
    'updated_at': '2026-05-22T06:30:00Z',
  };
}
