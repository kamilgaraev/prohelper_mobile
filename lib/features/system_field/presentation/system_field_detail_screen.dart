import 'package:flutter/material.dart';

class SystemFieldDetailScreen extends StatelessWidget {
  const SystemFieldDetailScreen({
    super.key,
    required this.title,
    required this.record,
  });

  final String title;
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in record.entries)
                  if (entry.value != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DetailValue(
                        label: _label(entry.key),
                        value: entry.value,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 3),
      Text(_display(value), style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

String _display(dynamic value) {
  if (value is Map) {
    return value.entries
        .map((entry) => '${_label('${entry.key}')}: ${_display(entry.value)}')
        .join('\n');
  }
  if (value is List) return value.map(_display).join('\n');
  if (value is bool) return value ? 'Да' : 'Нет';
  return '$value';
}

String _label(String key) {
  const labels = {
    'id': 'Номер',
    'uuid': 'Идентификатор',
    'name': 'Название',
    'title': 'Название',
    'description': 'Описание',
    'status': 'Статус',
    'type': 'Тип',
    'direction': 'Направление',
    'scope': 'Область',
    'risk': 'Риск',
    'risk_level': 'Уровень риска',
    'reason': 'Причина',
    'decision': 'Решение',
    'value': 'Значение',
    'code': 'Код',
    'applies_to': 'Применяется к',
    'created_at': 'Создано',
    'updated_at': 'Обновлено',
    'started_at': 'Начало',
    'finished_at': 'Завершено',
    'due_at': 'Срок',
    'valid_from': 'Действует с',
    'valid_to': 'Действует до',
    'last_run': 'Последний запуск',
    'error_count': 'Ошибок',
    'total_count': 'Всего записей',
    'created_count': 'Создано записей',
    'updated_count': 'Обновлено записей',
    'skipped_count': 'Пропущено записей',
    'errors': 'Ошибки',
    'summary': 'Итог',
    'subject': 'Сотрудник',
    'role_label': 'Роль',
    'role_context': 'Контекст роли',
    'permission_summary': 'Доступы',
    'latest_decision': 'Последнее решение',
    'counts': 'Количество',
    'owner': 'Ответственный',
    'escalation_user': 'Эскалация',
    'risk_mode': 'Режим риска',
    'worker_enabled': 'Автоматический обмен включён',
    'manual_only': 'Только вручную',
    'configured': 'Настроено',
    'tokens_count': 'Ключей доступа',
    'active_tokens_count': 'Активных ключей',
  };
  if (labels[key] case final label?) return label;
  return key.replaceAll('_', ' ');
}
