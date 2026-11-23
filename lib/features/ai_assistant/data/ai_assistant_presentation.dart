class AiAssistantPresentation {
  const AiAssistantPresentation._(this.leadingText, this.blocks);

  static const version = 1;
  static const supportedBlocks = ['facts', 'list', 'table'];

  final String? leadingText;
  final List<AiAssistantVisualBlock> blocks;

  static AiAssistantPresentation? fromJson(
    Object? value, {
    required int sourceCount,
  }) {
    if (value is! Map ||
        value['version'] is! int ||
        value['version'] != version) {
      return null;
    }
    final items = value['blocks'];
    if (items is! List || items.isEmpty || items.length > 32) return null;

    String? leadingText;
    final blocks = <AiAssistantVisualBlock>[];
    final seen = <String>{};
    for (final item in items) {
      if (item is! Map || item['data'] is! Map) continue;
      final id = _text(item['id']);
      final refs = _refs(item['source_refs'], sourceCount);
      if (id == null || refs == null || seen.contains(id)) continue;
      final data = item['data'] as Map;
      if (item['type'] == 'text') {
        leadingText ??= _text(data['text']);
        seen.add(id);
        continue;
      }
      final block = switch (item['type']) {
        'facts' => _facts(id, data, refs, sourceCount),
        'list' => _list(id, data, refs, sourceCount),
        'table' => _table(id, data, refs, sourceCount),
        _ => null,
      };
      if (block != null) {
        blocks.add(block);
        seen.add(id);
      }
    }
    return AiAssistantPresentation._(leadingText, List.unmodifiable(blocks));
  }
}

sealed class AiAssistantVisualBlock {
  const AiAssistantVisualBlock(this.id, this.sourceRefs);

  final String id;
  final List<int> sourceRefs;
}

class AiAssistantFactsBlock extends AiAssistantVisualBlock {
  const AiAssistantFactsBlock(super.id, super.sourceRefs, this.fields);

  final List<AiAssistantField> fields;
}

class AiAssistantListBlock extends AiAssistantVisualBlock {
  const AiAssistantListBlock(super.id, super.sourceRefs, this.items);

  final List<AiAssistantListItem> items;
}

class AiAssistantTableBlock extends AiAssistantVisualBlock {
  const AiAssistantTableBlock(
    super.id,
    super.sourceRefs,
    this.columns,
    this.rows,
  );

  final List<String> columns;
  final List<AiAssistantTableRow> rows;
}

typedef AiAssistantField = ({String label, String value, List<int> sourceRefs});
typedef AiAssistantListItem =
    ({
      String title,
      String? status,
      String? details,
      List<AiAssistantField> fields,
      List<int> sourceRefs,
    });
typedef AiAssistantTableRow =
    ({List<String> cells, String? details, List<int> sourceRefs});

AiAssistantFactsBlock? _facts(
  String id,
  Map data,
  List<int> refs,
  int sourceCount,
) {
  final fields = _fields(data['items'], refs, sourceCount);
  return fields == null ? null : AiAssistantFactsBlock(id, refs, fields);
}

AiAssistantListBlock? _list(
  String id,
  Map data,
  List<int> refs,
  int sourceCount,
) {
  final rows = _objects(data['items'], limit: 200);
  if (rows == null) return null;
  final items = <AiAssistantListItem>[];
  for (final row in rows) {
    final title = _text(row['title']);
    final rowRefs = _childRefs(row, refs, sourceCount);
    final fields =
        row['fields'] == null
            ? const <AiAssistantField>[]
            : _fields(row['fields'], refs, sourceCount);
    if (title == null || fields == null || rowRefs == null) return null;
    items.add((
      title: title,
      status: _text(row['status']),
      details: _text(row['details']),
      fields: fields,
      sourceRefs: rowRefs,
    ));
  }
  return AiAssistantListBlock(id, refs, List.unmodifiable(items));
}

AiAssistantTableBlock? _table(
  String id,
  Map data,
  List<int> refs,
  int sourceCount,
) {
  final columns = _objects(data['columns'], limit: 32);
  final rows = _objects(data['rows'], limit: 200);
  if (columns == null || rows == null) return null;
  final headers = <String, String>{};
  for (final column in columns) {
    final key = _text(column['key']);
    final label = _text(column['label']);
    if (key == null || label == null || headers.containsKey(key)) return null;
    headers[key] = label;
  }
  final parsedRows = <AiAssistantTableRow>[];
  for (final row in rows) {
    final values = row['cells'];
    final rowRefs = _childRefs(row, refs, sourceCount);
    if (values is! Map || rowRefs == null) return null;
    final cells = <String>[];
    for (final key in headers.keys) {
      final value = _value(values[key]);
      if (value == null) return null;
      cells.add(value);
    }
    parsedRows.add((
      cells: List.unmodifiable(cells),
      details: _text(row['details']),
      sourceRefs: rowRefs,
    ));
  }
  return AiAssistantTableBlock(
    id,
    refs,
    List.unmodifiable(headers.values),
    List.unmodifiable(parsedRows),
  );
}

List<AiAssistantField>? _fields(
  Object? value,
  List<int> scope,
  int sourceCount,
) {
  final items = _objects(value, limit: 32);
  if (items == null) return null;
  final fields = <AiAssistantField>[];
  for (final item in items) {
    final label = _text(item['label']);
    final value = _value(item['value']);
    final refs = _childRefs(item, scope, sourceCount);
    if (label == null || value == null || refs == null) return null;
    fields.add((label: label, value: value, sourceRefs: refs));
  }
  return List.unmodifiable(fields);
}

List<Map>? _objects(Object? value, {required int limit}) {
  if (value is! List || value.isEmpty || value.length > limit) return null;
  if (value.any((item) => item is! Map)) return null;
  return value.cast<Map>();
}

List<int>? _refs(Object? value, int count) {
  if (value is! List || value.length > 200) return null;
  final refs = <int>{};
  for (final ref in value) {
    if (ref is! int || ref < 0 || ref >= count || !refs.add(ref)) return null;
  }
  return List.unmodifiable(refs);
}

List<int>? _childRefs(Map row, List<int> scope, int count) {
  if (!row.containsKey('source_refs')) return const [];
  final refs = _refs(row['source_refs'], count);
  return refs != null && refs.every(scope.contains) ? refs : null;
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

final _decimalPattern = RegExp(r'^-?(?:0|[1-9]\d*)(?:\.\d+)?$');

String? _value(Object? value) {
  if (value is! Map) return null;
  final kind = value['kind'];
  final raw = value['value'];
  if (kind == 'boolean') {
    return raw is bool ? (raw ? 'Да' : 'Нет') : null;
  }
  final text = _text(raw);
  if (text == null) return null;
  return switch (kind) {
    'text' || 'date' || 'datetime' => text,
    'decimal' when _decimalPattern.hasMatch(text) => [
      text.replaceAll('.', ','),
      if (_text(value['unit']) case final unit?) unit,
      if (_text(value['currency']) case final currency?) currency,
      if (value['vat'] == 'included') '(с НДС)',
      if (value['vat'] == 'excluded') '(без НДС)',
      if (value['vat'] == 'unknown') '(НДС не указан)',
    ].join(' '),
    _ => null,
  };
}
