typedef BimJson = Map<String, dynamic>;

BimJson bimMap(dynamic value) =>
    value is Map
        ? value.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
int bimInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
List<BimJson> bimMaps(dynamic value) =>
    value is List
        ? value.whereType<Map>().map(bimMap).toList(growable: false)
        : const [];

class BimAction {
  const BimAction({
    required this.key,
    required this.label,
    this.enabled = true,
  });
  final String key;
  final String label;
  final bool enabled;
  factory BimAction.fromJson(BimJson json) => BimAction(
    key: '${json['key'] ?? ''}',
    label: '${json['label'] ?? json['title'] ?? 'Выполнить'}',
    enabled: json['enabled'] != false,
  );
}

class BimPage<T> {
  const BimPage({
    required this.items,
    this.page = 1,
    this.lastPage = 1,
    this.total = 0,
    this.actions = const [],
  });
  final List<T> items;
  final int page;
  final int lastPage;
  final int total;
  final List<BimAction> actions;
  factory BimPage.fromJson(
    List<BimJson> items,
    BimJson meta,
    T Function(BimJson) parse,
  ) {
    final pagination = bimMap(meta['pagination']);
    final source = pagination.isEmpty ? meta : pagination;
    return BimPage(
      items: items.map(parse).toList(growable: false),
      page: bimInt(source['current_page'], 1),
      lastPage: bimInt(source['last_page'], 1),
      total: bimInt(source['total'], items.length),
      actions:
          bimMaps(meta['available_actions']).map(BimAction.fromJson).toList(),
    );
  }
  BimPage<T> append(BimPage<T> next) => BimPage(
    items: [...items, ...next.items],
    page: next.page,
    lastPage: next.lastPage,
    total: next.total,
    actions: actions,
  );
}

class BimModelVersion {
  const BimModelVersion({
    required this.id,
    required this.title,
    required this.status,
    this.modelTitle = '',
    this.packageTitle = '',
    this.packageId,
    this.versionNumber = '',
    this.isCurrent = false,
    this.progress = 0,
    this.actions = const [],
  });
  final int id;
  final String title;
  final String modelTitle;
  final String packageTitle;
  final int? packageId;
  final String versionNumber;
  final String status;
  final bool isCurrent;
  final int progress;
  final List<BimAction> actions;
  bool get ready => status == 'ready';
  bool get processing => status == 'processing' || status == 'queued';
  bool can(String action) =>
      actions.any((item) => item.key == action && item.enabled);
  String get statusLabel => switch (status) {
    'ready' => 'Готова к просмотру',
    'queued' => 'В очереди подготовки',
    'processing' => 'Подготавливается',
    'failed' => 'Ошибка подготовки',
    'unsupported' => 'Формат не поддерживается',
    _ => 'Нужна подготовка',
  };
  factory BimModelVersion.fromJson(BimJson json) => BimModelVersion(
    id: bimInt(json['id'] ?? json['version_id']),
    title: '${json['title'] ?? json['model_title'] ?? 'Модель'}',
    modelTitle: '${json['model_title'] ?? ''}',
    packageTitle: '${json['package_title'] ?? ''}',
    packageId: json['package_id'] == null ? null : bimInt(json['package_id']),
    versionNumber: '${json['version_number'] ?? json['revision'] ?? ''}',
    status: '${json['derivative_status'] ?? 'not_prepared'}',
    isCurrent: json['is_current'] == true,
    progress: bimInt(
      json['progress_percent'] ??
          bimMap(json['derivative'])['progress_percent'],
    ),
    actions:
        bimMaps(json['available_actions']).map(BimAction.fromJson).toList(),
  );
}

class BimPreparedViewer {
  const BimPreparedViewer({
    required this.versionId,
    required this.status,
    this.url,
    this.progress = 0,
    this.failure,
    this.sizeBytes = 0,
    this.raw = const {},
  });
  final int versionId;
  final String status;
  final Uri? url;
  final int progress;
  final String? failure;
  final int sizeBytes;
  final BimJson raw;
  bool get ready => status == 'ready' && url != null;
  factory BimPreparedViewer.fromJson(int versionId, BimJson json) {
    final derivative = bimMap(json['derivative']);
    final source = derivative.isEmpty ? json : derivative;
    final url =
        source['url'] ??
        source['download_url'] ??
        source['viewer_url'] ??
        json['geometry_url'];
    return BimPreparedViewer(
      versionId: versionId,
      status: '${source['status'] ?? json['status'] ?? 'not_prepared'}',
      url: url is String && url.isNotEmpty ? Uri.tryParse(url) : null,
      progress: bimInt(source['progress_percent']),
      failure: source['failed_reason'] as String?,
      sizeBytes: bimInt(
        source['size_bytes'] ??
            bimMap(source['metadata'])['derivative_size_bytes'],
      ),
      raw: json,
    );
  }
}

class BimTransform {
  const BimTransform({this.shift = const [0, 0, 0], this.rotation = 0});
  final List<double> shift;
  final double rotation;
  factory BimTransform.fromJson(dynamic value) {
    final json = bimMap(value);
    final shift = json['shift'];
    return BimTransform(
      shift:
          shift is List && shift.length == 3
              ? shift.map((value) => (value as num).toDouble()).toList()
              : const [0, 0, 0],
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }
  BimJson toJson() => {'shift': shift, 'rotation': rotation};
}

class BimSetRevision {
  const BimSetRevision({
    required this.revision,
    required this.versionIds,
    this.id,
    this.transforms = const {},
  });
  final int? id;
  final int revision;
  final List<int> versionIds;
  final Map<int, BimTransform> transforms;
  factory BimSetRevision.fromJson(BimJson json) => BimSetRevision(
    id: json['id'] == null ? null : bimInt(json['id']),
    revision: bimInt(json['revision']),
    versionIds: (json['version_ids'] as List? ?? []).map(bimInt).toList(),
    transforms: bimMap(
      json['transforms'],
    ).map((key, value) => MapEntry(bimInt(key), BimTransform.fromJson(value))),
  );
}

class BimModelSet {
  const BimModelSet({
    required this.id,
    required this.projectId,
    required this.title,
    required this.revision,
    this.revisions = const [],
    this.actions = const [],
  });
  final int id;
  final int projectId;
  final String title;
  final int revision;
  final List<BimSetRevision> revisions;
  final List<BimAction> actions;
  bool can(String action) =>
      actions.any((item) => item.key == action && item.enabled);
  BimSetRevision? get current {
    for (final item in revisions) {
      if (item.revision == revision) return item;
    }
    return null;
  }

  factory BimModelSet.fromJson(BimJson json) => BimModelSet(
    id: bimInt(json['id']),
    projectId: bimInt(json['project_id']),
    title: '${json['title'] ?? 'Набор моделей'}',
    revision: bimInt(json['revision']),
    revisions: bimMaps(json['revisions']).map(BimSetRevision.fromJson).toList(),
    actions:
        bimMaps(json['available_actions']).map(BimAction.fromJson).toList(),
  );
}

class BimIssue {
  const BimIssue({
    required this.id,
    required this.projectId,
    required this.revision,
    required this.title,
    required this.status,
    this.description = '',
    this.context = const {},
    this.actions = const [],
    this.snapshotUrl,
    this.photos = const [],
    this.assigneeId,
    this.blocking = false,
  });
  final int id;
  final int projectId;
  final int revision;
  final String title;
  final String status;
  final String description;
  final BimJson context;
  final List<BimAction> actions;
  final Uri? snapshotUrl;
  final List<BimJson> photos;
  final int? assigneeId;
  final bool blocking;
  String get statusLabel => switch (status) {
    'open' => 'Открыто',
    'in_progress' => 'В работе',
    'resolved' => 'Устранено',
    'verified' => 'Подтверждено',
    'closed' => 'Закрыто',
    _ => 'На рассмотрении',
  };
  factory BimIssue.fromJson(BimJson json) => BimIssue(
    id: bimInt(json['id']),
    projectId: bimInt(json['project_id']),
    revision: bimInt(json['revision']),
    title: '${json['title'] ?? 'Замечание'}',
    status: '${json['status'] ?? 'open'}',
    description: '${json['description'] ?? ''}',
    context: bimMap(json['context']),
    actions:
        bimMaps(json['available_actions']).map(BimAction.fromJson).toList(),
    snapshotUrl:
        json['snapshot_url'] is String
            ? Uri.tryParse(json['snapshot_url'])
            : null,
    photos: bimMaps(json['photos']),
    assigneeId:
        json['assignee_id'] == null ? null : bimInt(json['assignee_id']),
    blocking: json['is_blocking'] == true,
  );
}

class BimViewContext {
  const BimViewContext({
    required this.versionIds,
    this.transforms = const {},
    this.modelSetRevisionId,
    this.viewState = const {},
  });
  final List<int> versionIds;
  final Map<int, BimTransform> transforms;
  final int? modelSetRevisionId;
  final BimJson viewState;
  factory BimViewContext.fromJson(BimJson json) => BimViewContext(
    versionIds:
        (json['models'] as List? ?? [])
            .map(bimInt)
            .where((id) => id > 0)
            .toList(),
    transforms: bimMap(
      json['transforms'],
    ).map((key, value) => MapEntry(bimInt(key), BimTransform.fromJson(value))),
    modelSetRevisionId:
        json['model_set_revision_id'] == null
            ? null
            : bimInt(json['model_set_revision_id']),
    viewState: bimMap(json['camera'] ?? json['view_state']),
  );
}
