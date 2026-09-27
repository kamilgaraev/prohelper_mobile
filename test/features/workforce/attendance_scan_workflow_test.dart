import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_attendance_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_repository.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/attendance_scan_screen.dart';

class _FakeWorkforceRepository extends WorkforceRepository {
  _FakeWorkforceRepository({this.duplicate = false}) : super(Dio());

  final bool duplicate;

  final List<String> scannedTokens = [];

  @override
  Future<AttendanceScanResultModel> scanAttendanceQr({
    required String qrToken,
    String? deviceId,
  }) async {
    scannedTokens.add(qrToken);

    if (duplicate) {
      throw const WorkforceDuplicateScanException(
        'Этот QR-код уже использован.',
      );
    }

    return AttendanceScanResultModel(
      scanEventId: 91,
      employeeId: 41,
      employeeLabel: 'Иванов Иван',
      projectId: 7,
      projectLabel: 'Объект Литейная',
      workDate: DateTime(2026, 5, 16),
      status: 'at_work',
      statusLabel: 'Явка подтверждена.',
      source: 'qr_scan',
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
    expect(find.text('Явка подтверждена.'), findsOneWidget);
    expect(find.text('Иванов Иван'), findsOneWidget);
    expect(find.text('Объект Литейная'), findsOneWidget);
  });

  testWidgets('для дубликата предлагает проверить историю без подтверждения', (
    tester,
  ) async {
    final repository = _FakeWorkforceRepository(duplicate: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workforceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: AttendanceScanScreen(initialQrToken: 'signed-token-value'),
        ),
      ),
    );

    await tester.tap(find.text('Подтвердить явку'));
    await tester.pumpAndSettle();

    expect(find.text('Результат нужно проверить'), findsOneWidget);
    expect(
      find.textContaining('Предыдущая отметка могла сохраниться'),
      findsOneWidget,
    );
    final historyButton = find.text('Проверить историю явки');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(historyButton);
    expect(historyButton, findsOneWidget);
    expect(find.text('Явка подтверждена.'), findsNothing);

    await tester.tap(historyButton);
    await tester.pumpAndSettle();
    expect(find.text('История явки'), findsOneWidget);
  });
}
