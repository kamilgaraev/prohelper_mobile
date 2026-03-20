class MobileModuleModel {
  const MobileModuleModel({
    required this.slug,
    required this.title,
    required this.description,
    required this.icon,
    required this.supportedOnMobile,
    required this.order,
    this.route,
    this.permissions = const [],
  });

  final String slug;
  final String title;
  final String description;
  final String icon;
  final bool supportedOnMobile;
  final int order;
  final String? route;
  final List<String> permissions;

  factory MobileModuleModel.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String? ?? '';

    return MobileModuleModel(
      slug: slug,
      title: _resolveModuleTitle(slug, json['title'] as String?),
      description: _resolveModuleDescription(slug, json['description'] as String?),
      icon: json['icon'] as String? ?? 'grid',
      supportedOnMobile: json['supported_on_mobile'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
      route: json['route'] as String?,
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

String _resolveModuleTitle(String slug, String? rawTitle) {
  if (!_needsModuleFallback(rawTitle)) {
    return rawTitle!.trim();
  }

  return switch (slug) {
    'site-requests' => 'Заявки с объекта',
    'basic-warehouse' => 'Склад',
    'schedule-management' => 'График работ',
    'ai-assistant' => 'AI-ассистент',
    'workflow-management' => 'Workflow',
    'time-tracking' => 'Учет времени',
    'budget-estimates' => 'Журнал работ',
    _ => 'Модуль',
  };
}

String _resolveModuleDescription(String slug, String? rawDescription) {
  if (!_needsModuleFallback(rawDescription)) {
    return rawDescription!.trim();
  }

  return switch (slug) {
    'site-requests' =>
      'Создание, просмотр и согласование заявок по объекту.',
    'basic-warehouse' =>
      'Остатки, движения и приемка материалов по организации.',
    'schedule-management' =>
      'Графики работ, прогресс и задачи по объектам.',
    'ai-assistant' =>
      'История диалогов, управленческие вопросы и быстрый доступ к AI-помощнику.',
    'workflow-management' =>
      'Маршруты согласований и статусы бизнес-процессов.',
    'time-tracking' => 'Отметки, смены и контроль рабочего времени.',
    'budget-estimates' =>
      'Ежедневные записи, статусы согласования и экспорт журнала работ.',
    _ => '',
  };
}

bool _needsModuleFallback(String? value) {
  final normalized = value?.trim() ?? '';

  return normalized.isEmpty || normalized.startsWith('mobile_modules.modules.');
}
