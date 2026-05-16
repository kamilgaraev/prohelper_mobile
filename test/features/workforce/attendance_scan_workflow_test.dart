import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_attendance_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_repository.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/attendance_scan_screen.dart';

class _FakeWorkforceRepository extends WorkforceRepository {
  _FakeWorkforceRepository() : super(Dio());

  final List<String> scannedTokens = [];

  @override
  Future<AttendanceScanResultModel> scanAttendanceQr({
    required String qrToken,
    String? deviceId,
  }) async {
    scannedTokens.add(qrToken);

    return AttendanceScanResultModel(
      employeeLabel: 'Иванов Иван',
      projectLabel: 'Объект Литейная',
      workDate: DateTime(2026, 5, 16),
      statusLabel: 'Явка подтверждена',
      sourceLabel: 'QR-подтверждение',
      confirmedAt: DateTime(2026, 5, 16, 9, 1),
    );
  }
}

void main() {
  testWidgets('подтверждает явку по отсканированному QR', (tester) async {
    final repository = _FakeWorkforceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workforceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: AttendanceScanScreen(initialQrToken: 'signed-token-value'),
        ),
      ),
    );

    await tester.tap(find.text('Подтвердить явку'));
    await tester.pump();
    await tester.pump();

    expect(repository.scannedTokens, contains('signed-token-value'));
    expect(find.text('Явка подтверждена'), findsOneWidget);
    expect(find.text('Иванов Иван'), findsOneWidget);
    expect(find.text('Объект Литейная'), findsOneWidget);
  });
}
