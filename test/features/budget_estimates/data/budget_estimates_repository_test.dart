import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/budget_estimates/data/budget_estimates_repository.dart';

void main() {
  test(
    'fetches project summary through mobile budget-estimates route',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return _responseData(_summaryJson());
      });

      final repository = BudgetEstimatesRepository(dio);
      final summary = await repository.fetchSummary(projectId: 9);

      expect(request.method, 'GET');
      expect(request.path, '/budget-estimates/summary');
      expect(request.queryParameters['project_id'], 9);
      expect(summary.project.name, 'Башня');
    },
  );

  test('fetches estimate detail and linked changes', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return _responseData({
        'estimate': _estimateJson(),
        'linked_change_requests': [_changeJson()],
      });
    });

    final repository = BudgetEstimatesRepository(dio);
    final detail = await repository.fetchEstimate(17);

    expect(request.path, '/budget-estimates/estimates/17');
    expect(detail.estimate.id, 17);
    expect(detail.linkedChangeRequests.single.id, 33);
  });

  test('sends approval and request changes with trimmed comments', () async {
    final requests = <RequestOptions>[];
    final payloads = <dynamic>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      payloads.add(options.data);
      return _responseData(
        _estimateJson(
          status: options.path.endsWith('/approve') ? 'approved' : 'in_review',
        ),
      );
    });

    final repository = BudgetEstimatesRepository(dio);
    final approved = await repository.approveEstimate(
      id: 17,
      comment: ' Проверено ',
    );
    final returned = await repository.requestChanges(
      id: 17,
      comment: ' Уточнить объем ',
    );

    expect(requests.first.method, 'POST');
    expect(requests.first.path, '/budget-estimates/estimates/17/approve');
    expect(payloads.first['comment'], 'Проверено');
    expect(approved.status, 'approved');
    expect(
      requests.last.path,
      '/budget-estimates/estimates/17/request-changes',
    );
    expect(payloads.last['comment'], 'Уточнить объем');
    expect(returned.canRequestChanges, isTrue);
  });

  test('rejects empty request changes comment before network call', () async {
    var calls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      calls++;
      return _responseData(_estimateJson());
    });

    final repository = BudgetEstimatesRepository(dio);

    expect(
      () => repository.requestChanges(id: 17, comment: '   '),
      throwsArgumentError,
    );
    expect(calls, 0);
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _responseData(Map<String, dynamic> data) {
  return {'success': true, 'message': null, 'data': data};
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

Map<String, dynamic> _estimateJson({String status = 'in_review'}) {
  final actions =
      status == 'approved'
          ? const <String>[]
          : const ['approve', 'request_changes'];

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
    'line_groups': [_lineGroupJson()],
    'unsectioned_items': const [],
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

Map<String, dynamic> _itemJson() {
  return {
    'id': 101,
    'estimate_id': 17,
    'estimate_section_id': 71,
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
