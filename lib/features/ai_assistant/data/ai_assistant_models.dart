class AiUsageModel {
  const AiUsageModel({
    required this.monthlyLimit,
    required this.used,
    required this.remaining,
    required this.percentageUsed,
  });

  final int monthlyLimit;
  final int used;
  final int remaining;
  final double percentageUsed;

  factory AiUsageModel.fromJson(Map<String, dynamic> json) {
    return AiUsageModel(
      monthlyLimit: _intValue(json['monthly_limit']),
      used: _intValue(json['used']),
      remaining: _intValue(json['remaining']),
      percentageUsed: _doubleValue(json['percentage_used']),
    );
  }
}

class AiConversationModel {
  const AiConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.messagesCount = 0,
  });

  final int id;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int messagesCount;

  factory AiConversationModel.fromJson(Map<String, dynamic> json) {
    return AiConversationModel(
      id: _intValue(json['id']),
      title: (json['title'] as String? ?? '').trim(),
      createdAt: _dateTimeValue(json['created_at']),
      updatedAt: _dateTimeValue(json['updated_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: _dateTimeValue(json['last_message_at']),
      messagesCount: _intValue(json['messages_count']),
    );
  }
}

class AiMessageModel {
  const AiMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata,
    this.structuredPayload,
  });

  final int id;
  final String role;
  final String content;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;
  final AiAssistantStructuredPayload? structuredPayload;

  bool get isUser => role == 'user';
  List<AiAssistantArtifact> get artifacts =>
      structuredPayload?.artifacts ?? const <AiAssistantArtifact>[];

  factory AiMessageModel.fromJson(Map<String, dynamic> json) {
    final metadata = _nullableMap(json['metadata']);

    return AiMessageModel(
      id: _intValue(json['id']),
      role: (json['role'] as String? ?? '').trim(),
      content: (json['content'] as String? ?? '').trim(),
      createdAt: _dateTimeValue(json['created_at']),
      metadata: metadata,
      structuredPayload: AiAssistantStructuredPayload.fromMetadata(metadata),
    );
  }
}

class AiAssistantStructuredPayload {
  const AiAssistantStructuredPayload({
    this.answer,
    this.artifacts = const <AiAssistantArtifact>[],
    this.raw = const <String, dynamic>{},
  });

  final String? answer;
  final List<AiAssistantArtifact> artifacts;
  final Map<String, dynamic> raw;

  factory AiAssistantStructuredPayload.fromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null || metadata.isEmpty) {
      return const AiAssistantStructuredPayload();
    }

    final nested = _nullableMap(metadata['structured_payload']);
    final payload =
        nested == null ? metadata : <String, dynamic>{...metadata, ...nested};
    final artifacts = _asList(payload['artifacts'])
        .map(AiAssistantArtifact.fromJson)
        .where((artifact) => artifact != null)
        .cast<AiAssistantArtifact>()
        .toList(growable: false);

    return AiAssistantStructuredPayload(
      answer: _stringValue(payload['answer']),
      artifacts: artifacts,
      raw: payload,
    );
  }
}

class AiAssistantArtifact {
  const AiAssistantArtifact({
    this.id,
    this.title,
    this.name,
    this.filename,
    this.fileName,
    this.type,
    this.mimeType,
    this.url,
    this.href,
    this.path,
    this.downloadUrl,
    this.storageDisk,
    this.storagePath,
    this.expiresAt,
    this.reportType,
    this.filters = const <String, dynamic>{},
    this.sourceTool,
    this.reportFileId,
    this.size,
    this.raw = const <String, dynamic>{},
  });

  final Object? id;
  final String? title;
  final String? name;
  final String? filename;
  final String? fileName;
  final String? type;
  final String? mimeType;
  final String? url;
  final String? href;
  final String? path;
  final String? downloadUrl;
  final String? storageDisk;
  final String? storagePath;
  final String? expiresAt;
  final String? reportType;
  final Map<String, dynamic> filters;
  final String? sourceTool;
  final Object? reportFileId;
  final int? size;
  final Map<String, dynamic> raw;

  bool get isReport =>
      reportType != null ||
      (sourceTool?.startsWith('generate_') ?? false) ||
      (storagePath?.contains('/reports/') ?? false);

  String? get trustedUrl {
    final candidate = downloadUrl ?? url ?? href ?? path;
    final uri = Uri.tryParse(candidate ?? '');

    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    return uri.toString();
  }

  String get displayTitle {
    final value = title ?? name ?? filename ?? fileName;

    if (value == null || value.trim().isEmpty) {
      return 'Отчет';
    }

    return value.trim();
  }

  static AiAssistantArtifact? fromJson(dynamic value) {
    final json = _nullableMap(value);
    if (json == null) {
      return null;
    }

    return AiAssistantArtifact(
      id: json['id'] is int || json['id'] is String ? json['id'] : null,
      title: _stringValue(json['title']),
      name: _stringValue(json['name']),
      filename: _stringValue(json['filename']),
      fileName: _stringValue(json['file_name']),
      type: _stringValue(json['type']),
      mimeType: _stringValue(json['mime_type']),
      url: _stringValue(json['url']),
      href: _stringValue(json['href']),
      path: _stringValue(json['path']),
      downloadUrl: _stringValue(json['download_url']),
      storageDisk: _stringValue(json['storage_disk']),
      storagePath: _stringValue(json['storage_path']),
      expiresAt: _stringValue(json['expires_at']),
      reportType: _stringValue(json['report_type']),
      filters: _nullableMap(json['filters']) ?? const <String, dynamic>{},
      sourceTool: _stringValue(json['source_tool']),
      reportFileId:
          json['report_file_id'] is int || json['report_file_id'] is String
              ? json['report_file_id']
              : null,
      size: _nullableInt(json['size']),
      raw: json,
    );
  }
}

class AiConversationDetailsModel {
  const AiConversationDetailsModel({
    required this.conversation,
    required this.messages,
  });

  final AiConversationModel conversation;
  final List<AiMessageModel> messages;
}

class AiAssistantHomeModel {
  const AiAssistantHomeModel({
    required this.usage,
    required this.conversations,
  });

  final AiUsageModel usage;
  final List<AiConversationModel> conversations;
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleValue(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTimeValue(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw);
}

Map<String, dynamic>? _nullableMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return null;
}

List<dynamic> _asList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }

  if (value is List) {
    return value.cast<dynamic>();
  }

  return const <dynamic>[];
}

String? _stringValue(dynamic value) {
  final raw = value?.toString().trim();

  if (raw == null || raw.isEmpty) {
    return null;
  }

  return raw;
}

int? _nullableInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}
