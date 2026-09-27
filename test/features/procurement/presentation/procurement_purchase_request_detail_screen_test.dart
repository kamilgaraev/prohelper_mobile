import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';
import 'package:prohelpers_mobile/features/procurement/domain/procurement_provider.dart';
import 'package:prohelpers_mobile/features/procurement/presentation/procurement_purchase_request_detail_screen.dart';

class _Repository extends ProcurementRepository {
  _Repository(this.request) : super(Dio());

  final ProcurementPurchaseRequestModel request;

  @override
  Future<ProcurementPurchaseRequestModel> fetchPurchaseRequest(int id) async =>
      request;
}

void main() {
  testWidgets('purchase request detail fits long values on compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final payload = {
      'id': 12,
      'organization_id': 4,
      'request_number': 'PR_2026_SECTION_A_001',
      'status': 'pending',
      'status_label': 'Ожидает согласования руководителя',
      'statistics': {
        'lines_count': 0,
        'supplier_requests_count': 0,
        'purchase_orders_count': 1,
      },
      'lines': <Map<String, dynamic>>[],
      'purchase_orders': [
        {
          'id': 61,
          'order_number': 'PO_2026_SECTION_A_NORTH_BUILDING_001',
          'status': 'Подтвержден поставщиком',
          'total_amount': 400000,
          'currency': 'RUB',
        },
      ],
    };
    final request = ProcurementPurchaseRequestModel.fromJson(payload);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          procurementProvider.overrideWith(
            (ref) => ProcurementNotifier(_Repository(request)),
          ),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const ProcurementPurchaseRequestDetailScreen(requestId: 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PO_2026_SECTION_A_NORTH_BUILDING_001'), findsOneWidget);
    expect(find.text('Подтвержден поставщиком'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
