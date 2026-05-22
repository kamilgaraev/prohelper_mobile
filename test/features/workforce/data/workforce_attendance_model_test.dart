import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_attendance_model.dart';

void main() {
  group('AttendanceQrModel', () {
    test('parses strict QR payload with status code', () {
      final qr = AttendanceQrModel.fromJson(const {
        'qr_token': 'signed-token-value',
        'expires_at': '2026-05-16T09:05:00+03:00',
        'employee_id': 41,
        'employee_label': 'Иванов Иван',
        'project_id': 7,
        'project_label': 'Объект Литейная',
        'work_date': '2026-05-16',
        'status': 'active',
        'status_label': 'Покажите QR-код ответственному сотруднику.',
      });

      expect(qr.qrToken, 'signed-token-value');
      expect(qr.employeeId, 41);
      expect(qr.projectId, 7);
      expect(qr.status, 'active');
      expect(qr.workDate, DateTime(2026, 5, 16));
    });

    test('rejects missing work date instead of using current date', () {
      expect(
        () => AttendanceQrModel.fromJson(const {
          'qr_token': 'signed-token-value',
          'expires_at': '2026-05-16T09:05:00+03:00',
          'employee_id': 41,
          'employee_label': 'Иванов Иван',
          'status': 'active',
          'status_label': 'Покажите QR-код ответственному сотруднику.',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AttendanceScanResultModel', () {
    test('parses strict confirmed scan payload', () {
      final result = AttendanceScanResultModel.fromJson(const {
        'scan_event_id': 91,
        'employee_id': 41,
        'employee_label': 'Иванов Иван',
        'project_id': 7,
        'project_label': 'Объект Литейная',
        'work_date': '2026-05-16',
        'status': 'at_work',
        'status_label': 'Явка подтверждена.',
        'source': 'qr_scan',
        'source_label': 'QR-подтверждение',
        'confirmed_at': '2026-05-16T09:01:00+03:00',
      });

      expect(result.scanEventId, 91);
      expect(result.employeeId, 41);
      expect(result.source, 'qr_scan');
      expect(result.confirmedAt.year, 2026);
    });

    test('rejects malformed confirmation time', () {
      expect(
        () => AttendanceScanResultModel.fromJson(const {
          'scan_event_id': 91,
          'employee_id': 41,
          'employee_label': 'Иванов Иван',
          'work_date': '2026-05-16',
          'status': 'at_work',
          'status_label': 'Явка подтверждена.',
          'source': 'qr_scan',
          'source_label': 'QR-подтверждение',
          'confirmed_at': 'not-a-date',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AttendanceHistoryModel', () {
    test('parses explicit history items list', () {
      final history = AttendanceHistoryModel.fromJson(const {
        'items': [
          {
            'scan_event_id': 91,
            'employee_id': 41,
            'employee_label': 'Иванов Иван',
            'project_id': 7,
            'project_label': 'Объект Литейная',
            'work_date': '2026-05-16',
            'status': 'at_work',
            'status_label': 'На работе',
            'source': 'self_attendance',
            'source_label': 'Самоотметка',
            'confirmed_at': '2026-05-16T08:58:00+03:00',
          },
        ],
      });

      expect(history.items, hasLength(1));
      expect(history.items.single.source, 'self_attendance');
      expect(history.items.single.projectLabel, 'Объект Литейная');
    });

    test('rejects history without explicit items list', () {
      expect(
        () => AttendanceHistoryModel.fromJson(const {'data': []}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
