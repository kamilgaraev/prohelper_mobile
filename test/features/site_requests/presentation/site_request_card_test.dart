import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/widgets/site_request_card.dart';

void main() {
  testWidgets('длинные метки заявки помещаются при увеличенном шрифте', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final request =
        SiteRequestModel()
          ..serverId = 1
          ..title = 'Учебный конкурс поставщиков цемента'
          ..status = 'approved'
          ..statusLabel = 'Одобрена'
          ..priority = 'medium'
          ..priorityLabel = 'Средний'
          ..requestType = 'material_request'
          ..requestTypeLabel =
              'Заявка на материалы для учебного конкурса поставщиков цемента'
          ..materialName = 'Цемент М500, мешки для склада';

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SiteRequestCard(request: request, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Одобрена'), findsOneWidget);
  });
}
