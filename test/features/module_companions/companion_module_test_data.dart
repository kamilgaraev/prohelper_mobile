const remainingCompanionSlugs = [
  'contract-management',
  'change-management',
  'executive-documentation',
  'project-management',
  'catalog-management',
  'brigades',
  'video-monitoring',
];

Map<String, dynamic> companionListJson({String slug = 'contract-management'}) {
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
    'meta': {'current_page': 1, 'per_page': 20, 'total': 1, 'last_page': 1},
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
      },
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
