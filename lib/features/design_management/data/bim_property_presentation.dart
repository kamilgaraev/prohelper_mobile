import 'bim_models.dart';

String _normalized(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

BimJson? bimLocalizedDisplay(BimJson payload, BimJson dictionary) {
  if (dictionary['schema_version'] != 1 || dictionary['labels'] is! Map) {
    return null;
  }
  final labels = bimMap(dictionary['labels']);
  final categories = bimMap(dictionary['categories']);
  final values = bimMap(dictionary['values']);
  final materialValues = bimMap(dictionary['material_values']);
  final valueFields =
      (dictionary['value_fields'] as List? ?? const []).cast<String>().toSet();
  final fields = <BimJson>[];

  String displayValue(dynamic value, List<String> path) {
    if (value == null ||
        value == '' ||
        (value is List && value.isEmpty) ||
        (value is Map && value.isEmpty)) {
      return '${dictionary['empty_value'] ?? 'Не указано в модели'}';
    }
    if (value is bool) {
      return '${dictionary[value ? 'boolean_true' : 'boolean_false'] ?? (value ? 'Да' : 'Нет')}';
    }
    if (value is String) {
      final key = _normalized(path.last);
      if (const [
        'id',
        'globalid',
        'guid',
        'initialguid',
        'reference',
        'tag',
        'serialnumber',
        'profile',
        'steelgrade',
        'concretegrade',
      ].contains(key)) {
        return value;
      }
      if (const ['category', 'ifctype', 'type'].contains(key)) {
        return '${categories[value.trim().toLowerCase()] ?? value}';
      }
      final context =
          path
              .map(_normalized)
              .where((part) => !RegExp(r'^\d+$').hasMatch(part))
              .toList();
      final field = context.isEmpty ? '' : context.last;
      if (const ['material', 'materials'].contains(field) ||
          (field == 'name' && context.contains('materials'))) {
        return '${materialValues[value.trim().toLowerCase()] ?? value}';
      }
      if (valueFields.contains(field)) {
        return '${values[value.trim().toLowerCase()] ?? value}';
      }
    }
    return '$value';
  }

  void visit(dynamic data, List<String> path, List<String> displayPath) {
    final entries =
        data is Map
            ? bimMap(data).entries
            : (data as List)
                .asMap()
                .map((index, value) => MapEntry('$index', value))
                .entries;
    for (final entry in entries) {
      final nextPath = [...path, entry.key];
      final nextLabels = [
        ...displayPath,
        '${labels[_normalized(entry.key)] ?? entry.key}',
      ];
      final value = entry.value;
      if ((value is Map && value.isNotEmpty) ||
          (value is List && value.isNotEmpty)) {
        visit(value, nextPath, nextLabels);
      } else {
        fields.add({
          'path': nextPath,
          'label': nextLabels.join(' · '),
          'value': displayValue(value, nextPath),
        });
      }
    }
  }

  visit(payload, const [], const []);
  return {
    'locale': dictionary['locale'],
    'schema_version': 1,
    'fields': fields,
  };
}
