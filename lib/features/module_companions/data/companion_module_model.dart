class CompanionModuleInfo {
  const CompanionModuleInfo({
    required this.slug,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String slug;
  final String title;
  final String description;
  final String icon;
  final String route;

  factory CompanionModuleInfo.fromJson(Map<String, dynamic> json) {
    return CompanionModuleInfo(
      slug: _requiredString(json, 'slug'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      icon: _requiredString(json, 'icon'),
      route: _requiredString(json, 'route'),
    );
  }
}

class CompanionModuleListModel {
  const CompanionModuleListModel({
    required this.module,
    required this.items,
    required this.statuses,
    required this.emptyState,
    required this.permissionState,
    required this.meta,
  });

  final CompanionModuleInfo module;
  final List<CompanionListItem> items;
  final List<CompanionStatusFilter> statuses;
  final CompanionStateText emptyState;
  final CompanionStateText permissionState;
  final CompanionPagination meta;

  factory CompanionModuleListModel.fromJson(Map<String, dynamic> json) {
    final filters = _map(json['filters']);

    return CompanionModuleListModel(
      module: CompanionModuleInfo.fromJson(_map(json['module'])),
      items: _list(
        json['items'],
      ).map(CompanionListItem.fromJson).toList(growable: false),
      statuses: _list(
        filters['statuses'],
      ).map(CompanionStatusFilter.fromJson).toList(growable: false),
      emptyState: CompanionStateText.fromJson(_map(json['empty_state'])),
      permissionState: CompanionStateText.fromJson(
        _map(json['permission_state']),
      ),
      meta: CompanionPagination.fromJson(_map(json['meta'])),
    );
  }
}

class CompanionModuleDetailModel {
  const CompanionModuleDetailModel({
    required this.module,
    required this.item,
    required this.sections,
    required this.relatedItems,
    required this.emptyState,
    required this.permissionState,
  });

  final CompanionModuleInfo module;
  final CompanionListItem item;
  final List<CompanionSection> sections;
  final List<CompanionRelatedItem> relatedItems;
  final CompanionStateText emptyState;
  final CompanionStateText permissionState;

  factory CompanionModuleDetailModel.fromJson(Map<String, dynamic> json) {
    return CompanionModuleDetailModel(
      module: CompanionModuleInfo.fromJson(_map(json['module'])),
      item: CompanionListItem.fromJson(_map(json['item'])),
      sections: _list(
        json['sections'],
      ).map(CompanionSection.fromJson).toList(growable: false),
      relatedItems: _list(
        json['related_items'],
      ).map(CompanionRelatedItem.fromJson).toList(growable: false),
      emptyState: CompanionStateText.fromJson(_map(json['empty_state'])),
      permissionState: CompanionStateText.fromJson(
        _map(json['permission_state']),
      ),
    );
  }
}

class CompanionListItem {
  const CompanionListItem({
    required this.id,
    required this.title,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.actions,
    this.subtitle,
    this.status,
    this.statusLabel,
    this.statusTone,
    this.projectName,
    this.primaryValue,
    this.secondaryValue,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String? subtitle;
  final String? status;
  final String? statusLabel;
  final String? statusTone;
  final String? projectName;
  final String primaryLabel;
  final String? primaryValue;
  final String secondaryLabel;
  final String? secondaryValue;
  final String? updatedAt;
  final List<CompanionAction> actions;

  factory CompanionListItem.fromJson(Map<String, dynamic> json) {
    return CompanionListItem(
      id: _requiredInt(json, 'id'),
      title: _requiredString(json, 'title'),
      subtitle: _optionalString(json, 'subtitle'),
      status: _optionalString(json, 'status'),
      statusLabel: _optionalString(json, 'status_label'),
      statusTone: _optionalString(json, 'status_tone'),
      projectName: _optionalString(json, 'project_name'),
      primaryLabel: _requiredString(json, 'primary_label'),
      primaryValue: _optionalString(json, 'primary_value'),
      secondaryLabel: _requiredString(json, 'secondary_label'),
      secondaryValue: _optionalString(json, 'secondary_value'),
      updatedAt: _optionalString(json, 'updated_at'),
      actions: _list(
        json['available_actions'],
      ).map(CompanionAction.fromJson).toList(growable: false),
    );
  }
}

class CompanionAction {
  const CompanionAction({
    required this.key,
    required this.title,
    required this.requiresComment,
  });

  final String key;
  final String title;
  final bool requiresComment;

  factory CompanionAction.fromJson(Map<String, dynamic> json) {
    return CompanionAction(
      key: _requiredString(json, 'key'),
      title: _requiredString(json, 'title'),
      requiresComment: json['requires_comment'] == true,
    );
  }
}

class CompanionStatusFilter {
  const CompanionStatusFilter({required this.value, required this.label});

  final String value;
  final String label;

  factory CompanionStatusFilter.fromJson(Map<String, dynamic> json) {
    return CompanionStatusFilter(
      value: _requiredString(json, 'value'),
      label: _requiredString(json, 'label'),
    );
  }
}

class CompanionStateText {
  const CompanionStateText({required this.title, required this.description});

  final String title;
  final String description;

  factory CompanionStateText.fromJson(Map<String, dynamic> json) {
    return CompanionStateText(
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
    );
  }
}

class CompanionPagination {
  const CompanionPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  factory CompanionPagination.fromJson(Map<String, dynamic> json) {
    return CompanionPagination(
      currentPage: _requiredInt(json, 'current_page'),
      perPage: _requiredInt(json, 'per_page'),
      total: _requiredInt(json, 'total'),
      lastPage: _requiredInt(json, 'last_page'),
    );
  }
}

class CompanionSection {
  const CompanionSection({required this.title, required this.rows});

  final String title;
  final List<CompanionFieldRow> rows;

  factory CompanionSection.fromJson(Map<String, dynamic> json) {
    return CompanionSection(
      title: _requiredString(json, 'title'),
      rows: _list(
        json['rows'],
      ).map(CompanionFieldRow.fromJson).toList(growable: false),
    );
  }
}

class CompanionFieldRow {
  const CompanionFieldRow({required this.label, required this.value});

  final String label;
  final String value;

  factory CompanionFieldRow.fromJson(Map<String, dynamic> json) {
    return CompanionFieldRow(
      label: _requiredString(json, 'label'),
      value: _requiredString(json, 'value'),
    );
  }
}

class CompanionRelatedItem {
  const CompanionRelatedItem({
    required this.id,
    this.title,
    this.subtitle,
    this.status,
    this.statusLabel,
  });

  final int id;
  final String? title;
  final String? subtitle;
  final String? status;
  final String? statusLabel;

  factory CompanionRelatedItem.fromJson(Map<String, dynamic> json) {
    return CompanionRelatedItem(
      id: _requiredInt(json, 'id'),
      title: _optionalString(json, 'title'),
      subtitle: _optionalString(json, 'subtitle'),
      status: _optionalString(json, 'status'),
      statusLabel: _optionalString(json, 'status_label'),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  throw const FormatException('Некорректный формат данных раздела');
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((item) => item.map((key, entry) => MapEntry(key.toString(), entry)))
      .toList(growable: false);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  if (value is num || value is bool) {
    return value.toString();
  }

  throw FormatException('Не заполнено поле $key');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  if (value is num || value is bool) {
    return value.toString();
  }

  return null;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    final parsed = int.tryParse(value);

    if (parsed != null) {
      return parsed;
    }
  }

  throw FormatException('Не заполнено поле $key');
}
