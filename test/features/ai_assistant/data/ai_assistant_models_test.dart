import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';

void main() {
  test('parses assistant report artifacts from structured metadata', () {
    final message = AiMessageModel.fromJson({
      'id': 12,
      'role': 'assistant',
      'content': 'Отчет готов',
      'created_at': '2026-05-20T10:00:00Z',
      'metadata': {
        'structured_payload': {
          'answer': 'Отчет готов',
          'artifacts': [
            {
              'filename': 'timeline.pdf',
              'download_url': 'https://example.test/timeline.pdf',
              'report_type': 'project_timelines',
              'storage_disk': 's3',
              'storage_path': 'org-1/reports/timeline.pdf',
              'filters': {'date_from': '2026-05-01', 'date_to': '2026-05-20'},
              'size': '2048',
            },
            'broken artifact',
          ],
        },
      },
    });

    expect(message.artifacts, hasLength(1));
    expect(message.artifacts.single.isReport, isTrue);
    expect(message.artifacts.single.displayTitle, 'timeline.pdf');
    expect(
      message.artifacts.single.trustedUrl,
      'https://example.test/timeline.pdf',
    );
    expect(message.artifacts.single.reportType, 'project_timelines');
    expect(message.artifacts.single.size, 2048);
    expect(message.artifacts.single.filters['date_from'], '2026-05-01');
  });

  test('keeps plain assistant message usable without metadata', () {
    final message = AiMessageModel.fromJson({
      'id': 13,
      'role': 'assistant',
      'content': 'Обычный ответ',
      'created_at': null,
    });

    expect(message.content, 'Обычный ответ');
    expect(message.artifacts, isEmpty);
  });

  test('parses assistant actions from structured metadata', () {
    final message = AiMessageModel.fromJson({
      'id': 14,
      'role': 'assistant',
      'content': 'Можно создать задачу',
      'created_at': '2026-05-22T10:00:00Z',
      'metadata': {
        'structured_payload': {
          'next_actions': [
            {
              'id': 'schedule-1',
              'type': 'act',
              'label': 'Создать задачу графика',
              'allowed': true,
              'requires_confirmation': true,
              'action_class': 'confirm',
              'tool_name': 'create_schedule_task',
              'arguments': {'project_id': 77},
              'required_permissions': ['schedule_tasks.create'],
            },
          ],
        },
      },
    });

    expect(message.actions, hasLength(1));
    expect(message.actions.single.label, 'Создать задачу графика');
    expect(message.actions.single.isExecutableCandidate, isTrue);
    expect(message.actions.single.arguments['project_id'], 77);
  });
}
