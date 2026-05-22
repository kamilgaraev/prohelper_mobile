import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_attendance_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_repository.dart';
import 'package:prohelpers_mobile/features/workforce/domain/workforce_attendance_provider.dart';

enum _FailureMode { none, forbidden, duplicateScan, malformedContract }

class _FakeWorkforceRepository extends WorkforceRepository {
  _FakeWorkforceRepository({this.failureMode = _FailureMode.none})
    : super(Dio());

  final _FailureMode failureMode;

  @override
  Future<AttendanceQrModel> issueAttendanceQr({
    int? projectId,
    required DateTime workDate,
  }) async {
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

  @override
  Future<AttendanceScanResultModel> scanAttendanceQr({
    required String qrToken,
    String? deviceId,
  }) async {
    if (failureMode == _FailureMode.duplicateScan) {
      throw const WorkforceDuplicateScanException(
        'Этот QR-код уже использован.',
      );
    }

    return _confirmation(source: 'qr_scan', sourceLabel: 'QR-подтверждение');
  }

  @override
  Future<AttendanceScanResultModel> recordSelfAttendance({
    int? projectId,
    required DateTime workDate,
    String? deviceId,
  }) async {
    if (failureMode == _FailureMode.forbidden) {
      throw const ApiException(
        'Недостаточно прав для отметки явки.',
        statusCode: 403,
      );
    }

    return _confirmation(
      projectId: projectId,
      workDate: workDate,
      source: 'self_attendance',
      sourceLabel: 'Самоотметка',
    );
  }

  @override
  Future<AttendanceHistoryModel> fetchAttendanceHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) async {
    if (failureMode == _FailureMode.malformedContract) {
      throw const FormatException('items is required');
    }

    return AttendanceHistoryModel(
      items: [
        _confirmation(
          projectId: projectId,
          workDate: dateFrom,
          source: 'self_attendance',
          sourceLabel: 'Самоотметка',
        ).toHistoryItem(),
      ],
    );
  }

  AttendanceScanResultModel _confirmation({
    int? projectId = 7,
    DateTime? workDate,
    required String source,
    required String sourceLabel,
  }) {
    return AttendanceScanResultModel(
      scanEventId: 91,
      employeeId: 41,
      employeeLabel: 'Иванов Иван',
      projectId: projectId,
      projectLabel: projectId == null ? null : 'Объект Литейная',
      workDate: workDate ?? DateTime(2026, 5, 16),
      status: 'at_work',
      statusLabel: 'Явка подтверждена.',
      source: source,
      sourceLabel: sourceLabel,
      confirmedAt: DateTime(2026, 5, 16, 9, 1),
    );
  }
}

void main() {
  ProviderContainer container(_FakeWorkforceRepository repository) {
    return ProviderContainer(
      overrides: [workforceRepositoryProvider.overrideWithValue(repository)],
    );
  }

  test(
    'scanQr stores duplicate scan state separately from generic errors',
    () async {
      final ref = container(
        _FakeWorkforceRepository(failureMode: _FailureMode.duplicateScan),
      );
      addTearDown(ref.dispose);

      await ref.read(workforceAttendanceProvider.notifier).scanQr('token');

      final state = ref.read(workforceAttendanceProvider);
      expect(state.duplicateScan, isTrue);
      expect(state.permissionDenied, isFalse);
      expect(state.error, 'Этот QR-код уже использован.');
    },
  );

  test('recordSelfAttendance stores permission denied state for 403', () async {
    final ref = container(
      _FakeWorkforceRepository(failureMode: _FailureMode.forbidden),
    );
    addTearDown(ref.dispose);

    await ref
        .read(workforceAttendanceProvider.notifier)
        .recordSelfAttendance(workDate: DateTime(2026, 5, 16));

    final state = ref.read(workforceAttendanceProvider);
    expect(state.permissionDenied, isTrue);
    expect(state.selfAttendanceResult, isNull);
    expect(state.error, 'Недостаточно прав для отметки явки.');
  });

  test(
    'loadHistory exposes malformed contract without hiding it as network error',
    () async {
      final ref = container(
        _FakeWorkforceRepository(failureMode: _FailureMode.malformedContract),
      );
      addTearDown(ref.dispose);

      await ref
          .read(workforceAttendanceProvider.notifier)
          .loadHistory(
            dateFrom: DateTime(2026, 5, 1),
            dateTo: DateTime(2026, 5, 16),
          );

      final state = ref.read(workforceAttendanceProvider);
      expect(state.malformedContract, isTrue);
      expect(state.history, isEmpty);
      expect(
        state.error,
        'Данные по явке отличаются от ожидаемого формата. Обратитесь к администратору.',
      );
    },
  );

  test('clearScanResult keeps QR and attendance history', () async {
    final ref = container(_FakeWorkforceRepository());
    addTearDown(ref.dispose);

    await ref
        .read(workforceAttendanceProvider.notifier)
        .issueQr(workDate: DateTime(2026, 5, 16));
    await ref
        .read(workforceAttendanceProvider.notifier)
        .loadHistory(
          dateFrom: DateTime(2026, 5, 1),
          dateTo: DateTime(2026, 5, 16),
        );
    await ref.read(workforceAttendanceProvider.notifier).scanQr('token');

    ref.read(workforceAttendanceProvider.notifier).clearScanResult();

    final state = ref.read(workforceAttendanceProvider);
    expect(state.qr, isNotNull);
    expect(state.history, hasLength(1));
    expect(state.scanResult, isNull);
  });
}
