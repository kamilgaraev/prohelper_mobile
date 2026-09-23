class DesignPackagePage {
  const DesignPackagePage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<DesignPackageModel> items;
  final int currentPage;
  final int lastPage;
  final int total;

  DesignPackagePage append(DesignPackagePage next) {
    final ids = items.map((item) => item.id).toSet();
    return DesignPackagePage(
      items: [...items, ...next.items.where((item) => ids.add(item.id))],
      currentPage: next.currentPage,
      lastPage: next.lastPage,
      total: next.total,
    );
  }

  factory DesignPackagePage.fromJson(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> meta,
  ) => DesignPackagePage(
    items: items.map(DesignPackageModel.fromJson).toList(growable: false),
    currentPage: _int(meta['current_page'], 1),
    lastPage: _int(meta['last_page'], 1),
    total: _int(meta['total'], items.length),
  );
}

class DesignPackageAction {
  const DesignPackageAction({
    required this.key,
    required this.title,
    required this.requiresComment,
  });

  final String key;
  final String title;
  final bool requiresComment;

  factory DesignPackageAction.fromJson(Map<String, dynamic> json) =>
      DesignPackageAction(
        key: _string(json['key']),
        title: _string(json['title'], _string(json['key'])),
        requiresComment: json['requires_comment'] == true,
      );
}

class DesignPackageFile {
  const DesignPackageFile({
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
    final value =
        purpose == 'preview'
            ? previewUrl
            : purpose == 'download'
            ? downloadUrl
            : null;
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  factory DesignPackageFile.fromJson(Map<String, dynamic> json) =>
      DesignPackageFile(
        id: _int(json['id'], 0),
        name: _string(json['name'], 'Файл'),
        mimeType: _nullableString(json['mime_type']),
        previewUrl: _nullableString(json['preview_url']),
        downloadUrl: _nullableString(json['download_url']),
      );
}

class DesignPackageComment {
  const DesignPackageComment({
    required this.author,
    required this.body,
    this.status,
    this.createdAt,
  });

  final String author;
  final String body;
  final String? status;
  final DateTime? createdAt;

  factory DesignPackageComment.fromJson(Map<String, dynamic> json) =>
      DesignPackageComment(
        author: _string(json['author'], 'Участник проекта'),
        body: _string(json['body']),
        status: _nullableString(json['status']),
        createdAt: _date(json['created_at']),
      );
}

class DesignPackageHistoryEntry {
  const DesignPackageHistoryEntry({
    required this.title,
    this.description,
    this.createdAt,
  });

  final String title;
  final String? description;
  final DateTime? createdAt;

  factory DesignPackageHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DesignPackageHistoryEntry(
        title: _string(
          json['title'],
          _string(json['action'], 'Изменение статуса'),
        ),
        description:
            _nullableString(json['description']) ??
            _nullableString(json['comment']),
        createdAt: _date(json['created_at']),
      );
}

class DesignPackageValue {
  const DesignPackageValue({required this.label, required this.value});

  final String label;
  final String value;
}

class DesignPackageModel {
  const DesignPackageModel({
    required this.id,
    required this.title,
    this.projectId,
    this.stage,
    this.projectStage,
    this.discipline,
    this.status,
    this.plannedIssueDate,
    this.result = const [],
    this.files = const [],
    this.comments = const [],
    this.workflowHistory = const [],
    this.availableActions = const [],
  });

  final int id;
  final int? projectId;
  final String title;
  final String? stage;
  final String? projectStage;
  final String? discipline;
  final String? status;
  final DateTime? plannedIssueDate;
  final List<DesignPackageValue> result;
  final List<DesignPackageFile> files;
  final List<DesignPackageComment> comments;
  final List<DesignPackageHistoryEntry> workflowHistory;
  final List<DesignPackageAction> availableActions;

  factory DesignPackageModel.fromJson(Map<String, dynamic> json) =>
      DesignPackageModel(
        id: _int(json['id'], 0),
        projectId: _nullableInt(json['project_id']),
        title: _string(json['title'], 'Пакет документации'),
        stage: _nullableString(json['stage']),
        projectStage: _nullableString(json['project_stage']),
        discipline: _nullableString(json['discipline']),
        status: _nullableString(json['status']),
        plannedIssueDate: _date(json['planned_issue_date']),
        result: _resultRows(json['result']),
        files: _maps(
          json['files'],
        ).map(DesignPackageFile.fromJson).toList(growable: false),
        comments: _maps(
          json['comments'],
        ).map(DesignPackageComment.fromJson).toList(growable: false),
        workflowHistory: _maps(
          json['workflow_history'],
        ).map(DesignPackageHistoryEntry.fromJson).toList(growable: false),
        availableActions: _maps(json['available_actions'])
            .map(DesignPackageAction.fromJson)
            .where((action) => action.key.isNotEmpty)
            .toList(growable: false),
      );
}

List<DesignPackageValue> _resultRows(Object? value) {
  if (value is! Map) return const [];
  final result = value.map((key, item) => MapEntry(key.toString(), item));
  if (result['items'] is List) {
    return _maps(result['items'])
        .map(
          (row) => DesignPackageValue(
            label: _string(row['title'], _string(row['label'], 'Результат')),
            value: _string(row['value'], _string(row['description'])),
          ),
        )
        .where((row) => row.value.isNotEmpty)
        .toList(growable: false);
  }
  if (result.containsKey('value') || result.containsKey('description')) {
    final row = DesignPackageValue(
      label: _string(result['title'], _string(result['label'], 'Результат')),
      value: _string(result['value'], _string(result['description'])),
    );
    return row.value.isEmpty ? const [] : [row];
  }
  return result.entries
      .where(
        (entry) =>
            entry.value != null && entry.value is! Map && entry.value is! List,
      )
      .map(
        (entry) => DesignPackageValue(
          label: _label(entry.key),
          value: entry.value.toString(),
        ),
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> _maps(Object? value) =>
    value is List
        ? value
            .whereType<Map>()
            .map(
              (row) => row.map((key, item) => MapEntry(key.toString(), item)),
            )
            .toList(growable: false)
        : const [];

String _label(String key) => key
    .replaceAll('_', ' ')
    .replaceFirstMapped(
      RegExp(r'^[a-zа-яё]'),
      (match) => match[0]!.toUpperCase(),
    );
String _string(Object? value, [String fallback = '']) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
String? _nullableString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
int _int(Object? value, int fallback) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
int? _nullableInt(Object? value) => value == null ? null : _int(value, 0);
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
