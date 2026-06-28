class KnowledgeArticleModel {
  const KnowledgeArticleModel({
    required this.id,
    required this.title,
    required this.slug,
    this.kind,
    this.kindLabel,
    this.excerpt,
    this.categoryTitle,
    this.parentId,
    this.depth = 0,
    this.readingTime = 1,
    this.isPinned = false,
    this.tags = const <String>[],
    this.moduleSlugs = const <String>[],
    this.contextKeys = const <String>[],
    this.snippet,
    this.searchRank,
    this.content,
    this.plainText,
    this.tableOfContents = const <KnowledgeArticleTocItem>[],
    this.children = const <KnowledgeArticleModel>[],
    this.related = const <KnowledgeArticleModel>[],
  });

  final int id;
  final String title;
  final String slug;
  final String? kind;
  final String? kindLabel;
  final String? excerpt;
  final String? categoryTitle;
  final int? parentId;
  final int depth;
  final int readingTime;
  final bool isPinned;
  final List<String> tags;
  final List<String> moduleSlugs;
  final List<String> contextKeys;
  final String? snippet;
  final double? searchRank;
  final String? content;
  final String? plainText;
  final List<KnowledgeArticleTocItem> tableOfContents;
  final List<KnowledgeArticleModel> children;
  final List<KnowledgeArticleModel> related;

  String get readingTimeLabel => '$readingTime мин';

  String get preview {
    final snippetValue = snippetText;
    if (snippetValue.isNotEmpty) {
      return snippetValue;
    }

    final excerptValue = excerpt?.trim();
    if (excerptValue != null && excerptValue.isNotEmpty) {
      return excerptValue;
    }

    return categoryTitle ?? 'Материал базы знаний';
  }

  String get snippetText => _plainTextFromHtml(snippet);

  String get bodyText {
    final plain = plainText?.trim();
    if (plain != null && plain.isNotEmpty) {
      return plain;
    }

    return _plainTextFromHtml(content);
  }

  factory KnowledgeArticleModel.fromJson(Map<String, dynamic> json) {
    final category = _mapValue(json['category']);

    return KnowledgeArticleModel(
      id: _intValue(json['id']),
      title: _stringValue(json['title'], fallback: 'Статья базы знаний'),
      slug: _stringValue(json['slug']),
      kind: _stringOrNull(json['kind']),
      kindLabel: _stringOrNull(json['kind_label']),
      excerpt: _stringOrNull(json['excerpt']),
      categoryTitle: _stringOrNull(category['title']),
      parentId: _nullableInt(json['parent_id']),
      depth: _intValue(json['depth']),
      readingTime: _intValue(json['reading_time'], fallback: 1),
      isPinned: json['is_pinned'] == true,
      tags: _stringList(json['tags']),
      moduleSlugs: _stringList(json['module_slugs']),
      contextKeys: _stringList(json['context_keys']),
      snippet: _stringOrNull(json['snippet']),
      searchRank: _doubleOrNull(json['search_rank']),
      content: _stringOrNull(json['content']),
      plainText: _stringOrNull(json['plain_text']),
      tableOfContents:
          _mapList(json['table_of_contents'])
              .map(KnowledgeArticleTocItem.fromJson)
              .toList(growable: false),
      children:
          _mapList(json['children'])
              .map(KnowledgeArticleModel.fromJson)
              .toList(growable: false),
      related:
          _mapList(json['related'])
              .map(KnowledgeArticleModel.fromJson)
              .toList(growable: false),
    );
  }
}

class KnowledgeArticleTocItem {
  const KnowledgeArticleTocItem({
    required this.level,
    required this.title,
    required this.anchor,
  });

  final int level;
  final String title;
  final String anchor;

  factory KnowledgeArticleTocItem.fromJson(Map<String, dynamic> json) {
    return KnowledgeArticleTocItem(
      level: _intValue(json['level'], fallback: 2),
      title: _stringValue(json['title']),
      anchor: _stringValue(json['anchor']),
    );
  }
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((item) => item.map((key, entry) => MapEntry(key.toString(), entry)))
      .toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }

  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _stringValue(dynamic value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';

  return normalized.isNotEmpty ? normalized : fallback;
}

String? _stringOrNull(dynamic value) {
  final normalized = value?.toString().trim() ?? '';

  return normalized.isNotEmpty ? normalized : null;
}

int _intValue(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _nullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  return _intValue(value);
}

double? _doubleOrNull(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '');
}

String _plainTextFromHtml(String? html) {
  if (html == null || html.trim().isEmpty) {
    return '';
  }

  final withBreaks = html
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*(p|div|li|h[1-6])\s*>', caseSensitive: false), '\n');
  final withoutTags = withBreaks.replaceAll(RegExp(r'<[^>]+>'), ' ');

  return withoutTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .join(' ');
}
