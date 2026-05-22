import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/time_tracking/data/time_entry_model.dart';

void main() {
  test('parses daily summary with active timer and approval status', () {
    final summary = DailyTimeSummaryModel.fromJson({
      'date': '2026-05-22',
      'project_id': 9,
      'entries': [_entryJson()],
      'active_timer': _entryJson(isActive: true, hours: null),
      'totals': {
        'total_hours': 3.5,
        'billable_hours': 3.5,
        'entries_count': 1,
        'by_status': {'draft': 1, 'submitted': 0, 'approved': 0, 'rejected': 0},
      },
      'approval_status': {
        'draft': 1,
        'submitted': 0,
        'approved': 0,
        'rejected': 0,
      },
    });

    expect(summary.date, '2026-05-22');
    expect(summary.activeTimer?.isActiveTimer, isTrue);
    expect(summary.entries.single.canSubmit, isTrue);
    expect(summary.totals.totalHours, 3.5);
  });

  test('parses correction and approval contract', () {
    final entry = TimeEntryModel.fromJson(
      _entryJson(status: 'rejected', actions: ['submit', 'correction']),
    );

    expect(entry.canCorrect, isTrue);
    expect(entry.corrections.single.reason, 'Добавлен фактический демонтаж');
    expect(entry.approvalSummary.rejectionReason, 'Не совпали часы');
  });

  test('rejects unknown status and missing actions', () {
    final unknownStatus = _entryJson(status: 'waiting');
    expect(() => TimeEntryModel.fromJson(unknownStatus), throwsFormatException);

    final missingActions = _entryJson()..remove('available_actions');
    expect(
      () => TimeEntryModel.fromJson(missingActions),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _entryJson({
  String status = 'draft',
  bool isActive = false,
  double? hours = 3.5,
  List<String> actions = const ['submit'],
}) {
  return {
    'id': 17,
    'organization_id': 4,
    'user_id': 8,
    'project_id': 9,
    'project_label': 'Башня',
    'work_type_id': null,
    'work_type_label': null,
    'task_id': null,
    'task_label': null,
    'work_date': '2026-05-22',
    'start_time': '08:00',
    'end_time': isActive ? null : '12:00',
    'hours_worked': hours,
    'break_time': isActive ? null : 0.5,
    'title': 'Монтаж опалубки',
    'description': 'Секция А',
    'status': status,
    'status_label': status == 'rejected' ? 'Отклонено' : 'Черновик',
    'is_active_timer': isActive,
    'is_billable': true,
    'location': null,
    'notes': null,
    'approved_by_user_id': null,
    'approved_by_label': null,
    'approved_at': null,
    'rejection_reason': status == 'rejected' ? 'Не совпали часы' : null,
    'corrections': [
      {
        'id': 'correction-1',
        'reason': 'Добавлен фактический демонтаж',
        'previous_hours': 3.5,
        'new_hours': 4.5,
        'submitted_by_user_id': 8,
        'created_at': '2026-05-22T10:00:00Z',
      },
    ],
    'available_actions': actions,
    'approval_summary': {
      'status': status,
      'status_label': status == 'rejected' ? 'Отклонено' : 'Черновик',
      'approved_by_label': null,
      'approved_at': null,
      'rejection_reason': status == 'rejected' ? 'Не совпали часы' : null,
    },
    'created_at': '2026-05-22T08:00:00Z',
    'updated_at': '2026-05-22T10:00:00Z',
  };
}
