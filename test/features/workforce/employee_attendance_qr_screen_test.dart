import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_attendance_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_repository.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/employee_attendance_qr_screen.dart';

class _FakeWorkforceRepository extends WorkforceRepository {
  _FakeWorkforceRepository() : super(Dio());

  final List<DateTime> requestedDates = [];

  @override
  Future<AttendanceQrModel> issueAttendanceQr({
    int? projectId,
    required DateTime workDate,
  }) async {
    requestedDates.add(workDate);

    return AttendanceQrModel(
      qrToken: 'signed-token-value',
      expiresAt: DateTime(2026, 5, 16, 9, 5),
      employeeId: 41,
      employeeLabel: 'Иванов Иван',
      projectId: projectId,
      projectLabel: 'Объект Литейная',
      workDate: workDate,
      status: 'active',
      statusLabel: 'Покажите QR-код ответственному сотруднику.',
    );
  }
}

void main() {
  testWidgets('не запрашивает QR без явно выбранной даты', (tester) async {
    final repository = _FakeWorkforceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workforceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: EmployeeAttendanceQrScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(repository.requestedDates, isEmpty);
    expect(find.text('Выберите дату явки'), findsOneWidget);
    expect(find.text('signed-token-value'), findsNothing);
  });

  testWidgets('показывает QR сотрудника без раскрытия токена текстом', (
    tester,
  ) async {
    final repository = _FakeWorkforceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workforceRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: EmployeeAttendanceQrScreen(
            projectId: 7,
            workDate: DateTime(2026, 5, 16),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(repository.requestedDates, [DateTime(2026, 5, 16)]);
    expect(find.text('Показать QR для подтверждения явки'), findsOneWidget);
    expect(find.text('Иванов Иван'), findsOneWidget);
    expect(find.text('Объект Литейная'), findsOneWidget);
    expect(find.text('signed-token-value'), findsNothing);
  });
}
