class ActFile {
  const ActFile({
    required this.id,
    required this.name,
    this.mimeType,
    this.size,
    this.category,
  });
  final int id;
  final String name;
  final String? mimeType;
  final int? size;
  final String? category;

  factory ActFile.fromJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id == null || id <= 0) {
      throw const FormatException('Некорректные данные файла акта.');
    }
    return ActFile(
      id: id,
      name: _text(json['name']).isEmpty ? 'Файл' : _text(json['name']),
      mimeType: _nullableText(json['mime_type']),
      size: _int(json['size']),
      category: _nullableText(json['category']),
    );
  }
}

class ActModel {
  const ActModel({
    required this.id,
    required this.values,
    this.files = const [],
    this.projectId,
  });
  final int id;
  final Map<String, dynamic> values;
  final int? projectId;
  final List<ActFile> files;
  bool get canViewFiles =>
      (values['capabilities'] is Map) &&
      (values['capabilities'] as Map)['can_view_files'] == true;
  bool get canFieldConfirm =>
      (values['capabilities'] is Map) &&
      (values['capabilities'] as Map)['can_field_confirm'] == true;
  String get title =>
      _text(values['number']).isNotEmpty ? _text(values['number']) : 'Акт №$id';
  String get status {
    final label = _text(values['status_label']);
    final code = _text(values['status']);
    return _statusLabels[label] ??
        (label.isNotEmpty
            ? label
            : _statusLabels[code] ?? (code.isNotEmpty ? code : 'Без статуса'));
  }

  factory ActModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId');
    if (id == null || id <= 0) {
      throw const FormatException('Некорректный ID акта');
    }
    return ActModel(
      id: id,
      values: Map.unmodifiable(json),
      projectId:
          _int(json['project_id']) ??
          (json['project'] is Map
              ? _int((json['project'] as Map)['id'])
              : null),
      files: (json['files'] as List? ?? const [])
          .whereType<Map>()
          .map((file) => ActFile.fromJson(Map<String, dynamic>.from(file)))
          .toList(growable: false),
    );
  }
}

String _text(dynamic value) => value?.toString().trim() ?? '';
String? _nullableText(dynamic value) =>
    _text(value).isEmpty ? null : _text(value);
int? _int(dynamic value) => value is int ? value : int.tryParse('$value');

const _statusLabels = {
  'draft': 'Черновик',
  'pending_approval': 'На согласовании',
  'approved': 'Утвержден',
  'rejected': 'Отклонен',
  'signed': 'Подписан',
  'annulled': 'Аннулирован',
};
