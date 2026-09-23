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

  CompanionModuleListModel appendPage(CompanionModuleListModel next) {
    final existingIds = items.map((item) => item.id).toSet();
    return CompanionModuleListModel(
      module: module,
      items: <CompanionListItem>[
        ...items,
        ...next.items.where((item) => existingIds.add(item.id)),
      ],
      statuses: statuses,
      emptyState: emptyState,
      permissionState: permissionState,
      meta: next.meta,
    );
  }

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
    this.result = const [],
    this.files = const [],
    this.comments = const [],
    this.workflowHistory = const [],
  });

  final CompanionModuleInfo module;
  final CompanionListItem item;
  final List<CompanionSection> sections;
  final List<CompanionRelatedItem> relatedItems;
  final CompanionStateText emptyState;
  final CompanionStateText permissionState;
  final List<CompanionFieldRow> result;
  final List<CompanionFile> files;
  final List<CompanionComment> comments;
  final List<CompanionHistoryEntry> workflowHistory;

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
      result: _resultRows(json['result']),
      files: _list(
        json['files'],
      ).map(CompanionFile.fromJson).toList(growable: false),
      comments: _list(
        json['comments'],
      ).map(CompanionComment.fromJson).toList(growable: false),
      workflowHistory: _list(
        json['workflow_history'],
      ).map(CompanionHistoryEntry.fromJson).toList(growable: false),
    );
  }
}

class CompanionFile {
  const CompanionFile({
    required this.id,
    required this.name,
    this.mimeType,
    this.previewUrl,
    this.downloadUrl,
  });

  final int id;
  final String name;
  final String? mimeType;
  final String? previewUrl;
  final String? downloadUrl;

  Uri? uriFor(String purpose) {
    final value = switch (purpose) {
      'preview' => previewUrl,
      'download' => downloadUrl,
      _ => null,
    };
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  factory CompanionFile.fromJson(Map<String, dynamic> json) => CompanionFile(
    id: _optionalInt(json['id']) ?? 0,
    name:
        _optionalString(json, 'name') ??
        _optionalString(json, 'file_name') ??
        'Файл',
    mimeType: _optionalString(json, 'mime_type'),
    previewUrl: _optionalString(json, 'preview_url'),
    downloadUrl: _optionalString(json, 'download_url'),
  );
}

class CompanionComment {
  const CompanionComment({
    required this.author,
    required this.body,
    this.status,
    this.createdAt,
  });

  final String author;
  final String body;
  final String? status;
  final DateTime? createdAt;

  factory CompanionComment.fromJson(Map<String, dynamic> json) =>
      CompanionComment(
        author: _optionalString(json, 'author') ?? 'Участник проекта',
        body: _optionalString(json, 'body') ?? '',
        status: _optionalString(json, 'status'),
        createdAt: _dateTime(json['created_at']),
      );
}

class CompanionHistoryEntry {
  const CompanionHistoryEntry({
    required this.title,
    this.description,
    this.createdAt,
  });

  final String title;
  final String? description;
  final DateTime? createdAt;

  factory CompanionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CompanionHistoryEntry(
        title:
            _optionalString(json, 'title') ??
            _optionalString(json, 'action') ??
            'Изменение статуса',
        description:
            _optionalString(json, 'description') ??
            _optionalString(json, 'comment'),
        createdAt: _dateTime(json['created_at']),
      );
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
  final List<CompanionAction> actions;
  final String? statusTone;
  final String? projectName;
  final String primaryLabel;
  final String? primaryValue;
  final String secondaryLabel;
  final String? secondaryValue;
  final String? updatedAt;

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
    this.actions = const [],
    this.actionsEndpoint,
  });

  final int id;
  final String? title;
  final String? subtitle;
  final String? status;
  final String? statusLabel;
  final List<CompanionAction> actions;
  final String? actionsEndpoint;

  factory CompanionRelatedItem.fromJson(Map<String, dynamic> json) {
    return CompanionRelatedItem(
      id: _requiredInt(json, 'id'),
      title: _optionalString(json, 'title'),
      subtitle: _optionalString(json, 'subtitle'),
      status: _optionalString(json, 'status'),
      statusLabel: _optionalString(json, 'status_label'),
      actions: _list(
        json['available_actions'],
      ).map(CompanionAction.fromJson).toList(growable: false),
      actionsEndpoint: _optionalString(json, 'actions_endpoint'),
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

List<CompanionFieldRow> _resultRows(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return [CompanionFieldRow(label: 'Результат', value: value.trim())];
  }
  if (value is List) {
    return _list(value).map(CompanionFieldRow.fromJson).toList(growable: false);
  }
  final result = value is Map ? _map(value) : const <String, dynamic>{};
  if (result['rows'] is List) {
    return _list(
      result['rows'],
    ).map(CompanionFieldRow.fromJson).toList(growable: false);
  }
  if (result.containsKey('value') || result.containsKey('description')) {
    final row = CompanionFieldRow(
      label:
          _optionalString(result, 'title') ??
          _optionalString(result, 'label') ??
          'Результат',
      value:
          _optionalString(result, 'value') ??
          _optionalString(result, 'description') ??
          '',
    );
    return row.value.isEmpty ? const [] : [row];
  }
  return result.entries
      .where(
        (entry) =>
            entry.value != null && entry.value is! Map && entry.value is! List,
      )
      .map(
        (entry) => CompanionFieldRow(
          label: entry.key.replaceAll('_', ' '),
          value: entry.value.toString(),
        ),
      )
      .toList(growable: false);
}

int? _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return value == null ? null : int.tryParse('$value');
}

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

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
