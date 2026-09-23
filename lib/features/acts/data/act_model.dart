class ActModel {
  const ActModel({required this.id, required this.values});
  final int id;
  final Map<String, dynamic> values;
  bool get canFieldConfirm =>
      (values['capabilities'] is Map) &&
      (values['capabilities'] as Map)['can_field_confirm'] == true;
  String get title =>
      _text(values['number']).isNotEmpty ? _text(values['number']) : 'Акт №$id';
  String get status =>
      _text(values['status_label']).isNotEmpty
          ? _text(values['status_label'])
          : _text(values['status']).isNotEmpty
          ? _text(values['status'])
          : 'Без статуса';
  factory ActModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId');
    if (id == null || id <= 0) {
      throw const FormatException('Некорректный ID акта');
    }
    return ActModel(id: id, values: Map.unmodifiable(json));
  }
}

String _text(dynamic value) => value?.toString().trim() ?? '';
