import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/budget_estimates/data/budget_estimate_model.dart';

void main() {
  test('parses budget summary with approvals, lines and linked changes', () {
    final summary = BudgetEstimateSummaryModel.fromJson(_summaryJson());

    expect(summary.project.name, 'Башня');
    expect(summary.totals.estimatesCount, 1);
    expect(summary.budget.committedAmount, 1260000);
    expect(summary.estimates.single.canApprove, isTrue);
    expect(
      summary.estimates.single.lineGroups.single.items.single.name,
      'Бетон М300',
    );
    expect(summary.linkedChangeRequests.single.changeNumber, 'CR-17');
  });

  test('parses detail contract with unsectioned items', () {
    final detail = BudgetEstimateDetailModel.fromJson({
      'estimate': _estimateJson(
        lineGroups: const [],
        unsectionedItems: [_itemJson(sectionId: null)],
      ),
      'linked_change_requests': [_changeJson()],
    });

    expect(detail.estimate.unsectionedItems.single.itemType, 'material');
    expect(detail.linkedChangeRequests.single.requiresEstimateRevision, isTrue);
  });

  test('rejects unknown status, action and missing lines', () {
    final unknownStatus = _estimateJson(status: 'waiting');
    expect(
      () => BudgetEstimateModel.fromJson(unknownStatus),
      throwsFormatException,
    );

    final unknownAction = _estimateJson(actions: const ['send']);
    expect(
      () => BudgetEstimateModel.fromJson(unknownAction),
      throwsFormatException,
    );

    final missingLines = _estimateJson()..remove('line_groups');
    expect(
      () => BudgetEstimateModel.fromJson(missingLines),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _summaryJson() {
  return {
    'project': {
      'id': 9,
      'name': 'Башня',
      'status': 'active',
      'budget_amount': 1500000,
    },
    'totals': {
      'estimates_count': 1,
      'by_status': {'draft': 0, 'in_review': 1, 'approved': 0, 'cancelled': 0},
      'total_amount': 1000000,
      'total_amount_with_vat': 1200000,
      'approved_amount_with_vat': 0,
      'in_review_count': 1,
    },
    'budget': {
      'project_budget_amount': 1500000,
      'approved_estimate_amount': 1200000,
      'approved_change_delta': 60000,
      'pending_change_delta': 25000,
      'committed_amount': 1260000,
      'budget_remaining': 240000,
    },
    'estimates': [_estimateJson()],
    'linked_change_requests': [_changeJson()],
    'assigned_approvals': [_estimateJson()],
  };
}

Map<String, dynamic> _estimateJson({
  String status = 'in_review',
  List<String> actions = const ['approve', 'request_changes'],
  List<Map<String, dynamic>>? lineGroups,
  List<Map<String, dynamic>>? unsectionedItems,
}) {
  return {
    'id': 17,
    'organization_id': 4,
    'project_id': 9,
    'project_label': 'Башня',
    'contract_id': 3,
    'number': 'EST-17',
    'name': 'Каркас секции А',
    'description': 'Работы нулевого цикла',
    'type': 'base',
    'status': status,
    'status_label': status == 'approved' ? 'Согласовано' : 'На согласовании',
    'version': 2,
    'estimate_date': '2026-05-22',
    'base_price_date': '2026-05-01',
    'totals': {
      'direct_costs': 900000,
      'overhead_costs': 50000,
      'estimated_profit': 50000,
      'equipment_costs': 0,
      'amount': 1000000,
      'amount_with_vat': 1200000,
      'vat_rate': 20,
      'overhead_rate': 5,
      'profit_rate': 5,
    },
    'statistics': {'sections_count': 1, 'items_count': 1},
    'approval_summary': {
      'status': status,
      'status_label': status == 'approved' ? 'Согласовано' : 'На согласовании',
      'approved_by_user_id': null,
      'approved_by_label': null,
      'approved_at': null,
      'available_actions': actions,
    },
    'available_actions': actions,
    'line_groups': lineGroups ?? [_lineGroupJson()],
    'unsectioned_items': unsectionedItems ?? const [],
    'created_at': '2026-05-22T08:00:00Z',
    'updated_at': '2026-05-22T10:00:00Z',
  };
}

Map<String, dynamic> _lineGroupJson() {
  return {
    'id': 71,
    'estimate_id': 17,
    'parent_section_id': null,
    'section_number': '1',
    'name': 'Бетонные работы',
    'description': null,
    'sort_order': 10,
    'is_summary': false,
    'total_amount': 800000,
    'items': [_itemJson()],
  };
}

Map<String, dynamic> _itemJson({int? sectionId = 71}) {
  return {
    'id': 101,
    'estimate_id': 17,
    'estimate_section_id': sectionId,
    'position_number': '1.1',
    'name': 'Бетон М300',
    'item_type': 'material',
    'measurement_unit_label': 'м3',
    'quantity': 20,
    'quantity_total': 20,
    'unit_price': 4000,
    'current_unit_price': 4100,
    'total_amount': 80000,
    'current_total_amount': 82000,
    'procurement_status': 'planned',
  };
}

Map<String, dynamic> _changeJson() {
  return {
    'id': 33,
    'project_id': 9,
    'change_number': 'CR-17',
    'title': 'Уточнение марки бетона',
    'reason': 'Проектное изменение',
    'status': 'submitted',
    'status_label': 'На рассмотрении',
    'cost_delta': 25000,
    'schedule_delta_days': 2,
    'requires_estimate_revision': true,
    'affected_estimate_item_ids': [101],
    'created_at': '2026-05-22T09:00:00Z',
    'approved_at': null,
  };
}
