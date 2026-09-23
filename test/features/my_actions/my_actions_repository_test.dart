import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/my_actions/data/my_actions_repository.dart';
import 'package:prohelpers_mobile/features/my_actions/data/my_action.dart';
import 'package:prohelpers_mobile/features/my_actions/presentation/my_actions_section.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_defect_detail_screen.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_task_detail_screen.dart';
import 'package:prohelpers_mobile/features/procurement/presentation/procurement_purchase_request_detail_screen.dart';
import 'package:prohelpers_mobile/features/payments/presentation/payments_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';

void main() {
  test('each action opens its record screen', () {
    MyAction action(String route) => MyAction(
      id: 42,
      type: route,
      route: route,
      title: 'Работа',
      status: 'assigned',
      projectId: 15,
    );

    expect(
      myActionTarget(action('site_request')),
      isA<SiteRequestDetailScreen>(),
    );
    expect(
      myActionTarget(action('schedule_task')),
      isA<ScheduleTaskDetailScreen>(),
    );
    expect(
      myActionTarget(action('purchase_request')),
      isA<ProcurementPurchaseRequestDetailScreen>(),
    );
    expect(
      myActionTarget(action('payment_document')),
      isA<PaymentDocumentDetailScreen>(),
    );
    expect(
      myActionTarget(action('quality_defect')),
      isA<QualityDefectDetailScreen>(),
    );
    expect(myActionTarget(action('unsupported')), isNull);
  });

  test('loads a bounded project page with a direct record target', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': [
          {
            'id': 42,
            'type': 'quality_defect',
            'route': 'quality_defect',
            'title': 'Проверить шов',
            'status': 'assigned',
            'project_id': 15,
            'project_name': 'Корпус 1',
            'due_at': '2026-09-26',
            'allowed_actions': ['resolve'],
          },
        ],
        'meta': {'current_page': 2, 'last_page': 3, 'total': 21},
      };
    });

    final result = await MyActionsRepository(
      dio,
    ).fetch(projectId: 15, page: 2, perPage: 10);

    expect(request.path, '/my-actions');
    expect(request.queryParameters['project_id'], 15);
    expect(request.queryParameters['page'], 2);
    expect(request.queryParameters['per_page'], 10);
    expect(result.items.single.route, 'quality_defect');
    expect(result.items.single.allowedActions, ['resolve']);
    expect(result.currentPage, 2);
    expect(result.hasMore, isTrue);
    expect(result.total, 21);
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
