import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_summary_model.dart';

void main() {
  test('parses schedule events summary from explicit labels', () {
    final summary = ScheduleSummaryModel.fromJson({
      'summary': {
        'today_count': 1,
        'upcoming_count': 2,
        'blocking_count': 1,
        'in_progress_count': 1,
        'project_id': 15,
        'project_name': 'Дом 300м Царево',
      },
      'events': [
        {
          'id': 7,
          'title': 'Поставка бетона',
          'event_type': 'delivery',
          'event_type_label': 'Поставка',
          'status': 'scheduled',
          'status_label': 'Запланировано',
          'priority': 'high',
          'priority_label': 'Высокий',
          'event_date': '2026-06-08',
          'is_blocking': true,
          'is_all_day': false,
        },
      ],
    });

    expect(summary.summary.blockingCount, 1);
    expect(summary.events.single.eventTypeLabel, 'Поставка');
    expect(summary.events.single.eventDate.year, 2026);
  });

  test('rejects summary events with hidden defaults or translation keys', () {
    expect(
      () => ScheduleSummaryModel.fromJson({
        'summary': {
          'today_count': 1,
          'upcoming_count': 2,
          'blocking_count': 1,
          'in_progress_count': 1,
        },
        'events': [
          {
            'id': 7,
            'title': 'Поставка бетона',
            'event_type': 'unknown',
            'event_type_label': 'mobile_schedule.event_types.other',
            'status': 'scheduled',
            'status_label': 'Запланировано',
            'priority': 'high',
            'priority_label': 'Высокий',
            'event_date': '2026-06-08',
            'is_blocking': true,
            'is_all_day': false,
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
