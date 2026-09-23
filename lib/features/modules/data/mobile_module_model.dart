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
      description: _resolveModuleDescription(
        slug,
        json['description'] as String?,
      ),
      icon: json['icon'] as String? ?? 'grid',
      supportedOnMobile: json['supported_on_mobile'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
      route: json['route'] as String?,
      permissions:
          (json['permissions'] as List<dynamic>? ?? const [])
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
    'crm' => 'CRM',
    'tenders' => 'Тендеры',
    'act-reporting' => 'Акты',
    'payments' => 'Финансовые документы',
    'file-management' => 'Опубликованные отчёты',
    'report-templates' => 'Шаблоны отчётов',
    'budgeting' => 'Исполнение бюджета',
    'one-c-basic-exchange' => 'Обмен с 1С',
    'access_recertification' => 'Пересмотр доступов',
    'rate-management' => 'Коэффициенты',
    'system-logs' => 'Журнал событий',
    'workflow-management' => 'Согласования',
    'time-tracking' => 'Учет времени',
    'construction-journal' => 'Журнал работ',
    'budget-estimates' => 'Сметы и бюджет',
    'quality-control' => 'Контроль качества',
    'safety-management' => 'Охрана труда',
    'machinery-operations' => 'Техника',
    'production-labor' => 'Наряды',
    'workforce-management' => 'Явка сотрудников',
    'handover-acceptance' => 'Приемка зон',
    'procurement' => 'Закупки',
    'contract-management' => 'Договоры',
    'design-management' => 'ПИР',
    'change-management' => 'Изменения',
    'executive-documentation' => 'Исполнительная документация',
    'project-management' => 'Управление проектом',
    'catalog-management' => 'Справочники',
    'brigades' => 'Бригады',
    'contractor-marketplace' => 'Подрядчики',
    'video-monitoring' => 'Видеонаблюдение',
    _ => 'Модуль',
  };
}

String _resolveModuleDescription(String slug, String? rawDescription) {
  if (!_needsModuleFallback(rawDescription)) {
    return rawDescription!.trim();
  }

  return switch (slug) {
    'site-requests' => 'Создание, просмотр и согласование заявок по объекту.',
    'basic-warehouse' =>
      'Остатки, движения и приемка материалов по организации.',
    'schedule-management' => 'Графики работ, прогресс и задачи по объектам.',
    'ai-assistant' =>
      'История диалогов, управленческие вопросы и быстрый доступ к AI-помощнику.',
    'crm' => 'Компании, контакты, лиды и сделки.',
    'tenders' => 'Сроки и статусы участия в тендерах.',
    'act-reporting' => 'Реестр актов и фиксация полевой приёмки.',
    'payments' => 'Счета, согласование и учёт оплаты.',
    'file-management' => 'Просмотр и скачивание опубликованных отчётов.',
    'report-templates' => 'Библиотека доступных шаблонов.',
    'workflow-management' =>
      'Маршруты согласований и статусы бизнес-процессов.',
    'time-tracking' => 'Отметки, смены и контроль рабочего времени.',
    'construction-journal' =>
      'Ежедневные записи, объемы работ, согласование и экспорт КС-6 по объекту.',
    'budget-estimates' =>
      'Сводка смет, лимитов бюджета, изменений и назначенных согласований.',
    'quality-control' =>
      'Замечания, дефекты и повторная проверка выполненных работ.',
    'safety-management' =>
      'Наряды-допуски, происшествия и нарушения на объекте.',
    'machinery-operations' =>
      'Сменные рапорты, простои и ГСМ по технике на объекте.',
    'production-labor' => 'Наряды, табели и выработка бригад на объекте.',
    'workforce-management' =>
      'QR-подтверждение присутствия, табель и контроль сотрудников на объекте.',
    'handover-acceptance' =>
      'Зоны, punch-list и передача готовых помещений заказчику.',
    'procurement' =>
      'Заявки, поставки, согласования и связь со складской приемкой.',
    'contract-management' =>
      'Договоры, обязательства, статусы и назначенные согласования.',
    'design-management' =>
      'Пакеты проектной документации, результаты и согласования.',
    'change-management' =>
      'Запросы на изменения, влияние на сроки и бюджет, согласования.',
    'executive-documentation' =>
      'Пакеты документов, статусы подготовки и полевые вложения.',
    'project-management' =>
      'Обзор объекта, этапы, ответственные и риски исполнения.',
    'catalog-management' =>
      'Материалы, ресурсы и справочные данные для полевых форм.',
    'brigades' => 'Составы бригад, назначения и связь с явкой сотрудников.',
    'contractor-marketplace' =>
      'Поиск подрядчиков и приглашение к работе на объекте.',
    'budgeting' => 'Сводка исполнения бюджета и показатели по объекту.',
    'one-c-basic-exchange' => 'Состояние и ошибки обмена с 1С.',
    'access_recertification' =>
      'Кампании пересмотра доступов и назначенные решения.',
    'rate-management' => 'Действующие коэффициенты организации.',
    'system-logs' => 'Журнал событий организации.',
    'video-monitoring' =>
      'Камеры объекта, статусы подключения и контроль доступности.',
    _ => '',
  };
}

bool _needsModuleFallback(String? value) {
  final normalized = value?.trim() ?? '';

  return normalized.isEmpty || normalized.startsWith('mobile_modules.modules.');
}
