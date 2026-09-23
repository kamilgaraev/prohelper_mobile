const remainingCompanionSlugs = [
  'contract-management',
  'change-management',
  'executive-documentation',
  'project-management',
  'catalog-management',
  'brigades',
  'video-monitoring',
];

Map<String, dynamic> companionListJson({
  String slug = 'contract-management',
  int page = 1,
  int lastPage = 1,
}) {
  return {
    'module': {
      'slug': slug,
      'title': 'Договоры',
      'description': 'Договоры и обязательства',
      'icon': 'contract',
      'route': slug,
    },
    'items': [companionItemJson()],
    'filters': {
      'statuses': [
        {'value': 'active', 'label': 'Активно'},
        {'value': 'draft', 'label': 'Черновик'},
      ],
    },
    'empty_state': {'title': 'Нет записей', 'description': 'Записи не найдены'},
    'permission_state': {
      'title': 'Раздел недоступен',
      'description': 'Нет доступа',
    },
    'meta': {
      'current_page': page,
      'per_page': 20,
      'total': lastPage > 1 ? 21 : 1,
      'last_page': lastPage,
    },
  };
}

Map<String, dynamic> companionDetailJson({
  String slug = 'contract-management',
}) {
  return {
    'module': {
      'slug': slug,
      'title': 'Договоры',
      'description': 'Договоры и обязательства',
      'icon': 'contract',
      'route': slug,
    },
    'item': companionItemJson(),
    'sections': [
      {
        'title': 'Основное',
        'rows': [
          {'label': 'Номер', 'value': 'C-001'},
          {'label': 'Объект', 'value': 'Tower A'},
        ],
      },
    ],
    'related_items': [
      {
        'id': 7,
        'title': 'Связанная запись',
        'subtitle': 'Tower A',
        'status': 'active',
        'status_label': 'Активно',
        'actions_endpoint': '/api/v1/mobile/pto/executive-documents/7/actions',
        'available_actions': [
          {'key': 'approve', 'title': 'Согласовать', 'requires_comment': false},
        ],
      },
    ],
    'result': {'title': 'Результат проверки', 'value': 'Принято'},
    'files': [
      {
        'id': 11,
        'name': 'Исполнительная схема.pdf',
        'mime_type': 'application/pdf',
        'preview_url': 'https://files.example.test/preview',
        'download_url': 'https://files.example.test/download',
      },
    ],
    'comments': [
      {
        'id': 1,
        'author': 'Инженер',
        'body': 'Проверено',
        'status': 'Принято',
        'created_at': '2026-09-23T08:00:00Z',
      },
    ],
    'workflow_history': [
      {'title': 'Передано на проверку', 'created_at': '2026-09-22T08:00:00Z'},
    ],
    'empty_state': {'title': 'Нет записей', 'description': 'Записи не найдены'},
    'permission_state': {
      'title': 'Раздел недоступен',
      'description': 'Нет доступа',
    },
  };
}

Map<String, dynamic> companionItemJson() {
  return {
    'id': 42,
    'title': 'C-001',
    'subtitle': 'Tower A',
    'status': 'active',
    'status_label': 'Активно',
    'status_tone': 'success',
    'project_name': 'Tower A',
    'primary_label': 'Сумма',
    'primary_value': '100000.00',
    'secondary_label': 'Акты',
    'secondary_value': '2',
    'updated_at': '2026-05-22T09:00:00+03:00',
    'available_actions': [
      {
        'key': 'submit',
        'title': 'Отправить на оценку',
        'requires_comment': false,
      },
    ],
  };
}
