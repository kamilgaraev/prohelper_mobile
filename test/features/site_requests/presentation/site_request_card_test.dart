import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/widgets/site_request_card.dart';

void main() {
  testWidgets('карточка не округляет малое количество до нуля', (tester) async {
    final request =
        SiteRequestModel()
          ..serverId = 3
          ..title = 'Тестовая заявка'
          ..status = 'draft'
          ..statusLabel = 'Черновик'
          ..priority = 'medium'
          ..priorityLabel = 'Средний'
          ..requestType = 'material_request'
          ..requestTypeLabel = 'Материалы'
          ..materialName = 'Кабель'
          ..materialQuantity = 0.001
          ..materialUnit = 'м';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SiteRequestCard(request: request, onTap: () {})),
      ),
    );

    expect(find.text('Кабель • 0.001 м'), findsOneWidget);

    request.materialQuantity = 1.230;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SiteRequestCard(request: request, onTap: () {})),
      ),
    );

    expect(find.text('Кабель • 1.23 м'), findsOneWidget);
  });

  testWidgets('карточка сохраняет длинные данные на узком экране', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final shortTitleRequest =
        SiteRequestModel()
          ..serverId = 1
          ..title = 'Q'
          ..status = 'pending'
          ..statusLabel = 'Ожидает согласования руководителем проекта'
          ..priority = 'medium'
          ..priorityLabel = 'Средний'
          ..requestType = 'material_request'
          ..requestTypeLabel =
              'Заявка на материалы для учебного конкурса поставщиков цемента'
          ..materialName = 'Цемент М500, мешки для склада';
    final longTitleRequest =
        SiteRequestModel()
          ..serverId = 2
          ..title = 'Учебный конкурс поставщиков цемента для нового корпуса'
          ..status = 'approved'
          ..statusLabel = 'Одобрена'
          ..priority = 'medium'
          ..priorityLabel = 'Средний'
          ..requestType = 'material_request'
          ..requestTypeLabel = 'Заявка на материалы'
          ..description =
              'Подробное описание заявки, которое должно отображаться целиком';

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
            child: Column(
              children: [
                SiteRequestCard(request: shortTitleRequest, onTap: () {}),
                SiteRequestCard(request: longTitleRequest, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Q'), findsOneWidget);
    expect(
      find.text(
        'Ожидает согласования руководителем проекта',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Заявка на материалы для учебного конкурса поставщиков цемента',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Учебный конкурс поставщиков цемента для нового корпуса',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Подробное описание заявки, которое должно отображаться целиком',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('Одобрена'), findsOneWidget);
  });
}
