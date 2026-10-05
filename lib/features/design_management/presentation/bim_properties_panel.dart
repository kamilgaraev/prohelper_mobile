import 'package:flutter/material.dart';
import '../data/bim_models.dart';

class BimPropertiesPanel extends StatelessWidget {
  const BimPropertiesPanel({super.key, required this.properties});

  final BimJson properties;

  @override
  Widget build(BuildContext context) {
    final display = bimMap(properties['display']);
    final fields =
        display['schema_version'] == 1 && display['fields'] is List
            ? bimMaps(display['fields'])
            : _sourceFields(properties, '');
    return Column(
      children: [
        for (final field in fields)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${field['label']}'),
            subtitle: SelectableText('${field['value']}'),
          ),
      ],
    );
  }

  List<BimJson> _sourceFields(BimJson json, String prefix) => [
    for (final entry in json.entries)
      if (entry.key != 'display' && entry.key != 'category_label')
        if (entry.value is Map)
          ..._sourceFields(bimMap(entry.value), '$prefix${entry.key} · ')
        else
          {'label': '$prefix${entry.key}', 'value': '${entry.value ?? '—'}'},
  ];
}
