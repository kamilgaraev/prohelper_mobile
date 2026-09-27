import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/workforce_attendance_screen.dart';

void main() {
  testWidgets('shows full attendance labels at large text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 1280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: WorkforceAttendanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('Явка сотрудников')).maxLines, 2);
    expect(
      tester
          .widget<Text>(find.text('QR, подтверждение и история отметок'))
          .maxLines,
      2,
    );
    expect(
      tester
          .widget<Text>(find.text('Состав сотрудников, отсутствия и наряды'))
          .maxLines,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
