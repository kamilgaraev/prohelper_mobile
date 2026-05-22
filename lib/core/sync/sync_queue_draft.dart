import 'dart:convert';

class SyncQueueDraft {
  const SyncQueueDraft({
    required this.moduleSlug,
    required this.operationType,
    required this.method,
    required this.endpoint,
    required this.payload,
    this.attachments = const <SyncAttachmentRef>[],
  });

  final String moduleSlug;
  final String operationType;
  final String method;
  final String endpoint;
  final Map<String, dynamic> payload;
  final List<SyncAttachmentRef> attachments;

  List<String> get localAttachments {
    final paths = <String>{};
    for (final attachment in attachments) {
      paths.add(attachment.path);
    }

    return paths.toList();
  }

  String encodePayload() => jsonEncode(payload);

  String encodeAttachments() {
    return jsonEncode(
      attachments.map((attachment) => attachment.toJson()).toList(),
    );
  }
}

class SyncAttachmentRef {
  const SyncAttachmentRef({
    required this.field,
    required this.path,
    this.filename,
  });

  final String field;
  final String path;
  final String? filename;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'field': field,
      'path': path,
      if (filename != null && filename!.trim().isNotEmpty)
        'filename': filename!.trim(),
    };
  }

  factory SyncAttachmentRef.fromJson(Map<String, dynamic> json) {
    final field = json['field']?.toString().trim() ?? '';
    final path = json['path']?.toString().trim() ?? '';

    if (field.isEmpty || path.isEmpty) {
      throw const FormatException(
        'Sync attachment field and path are required.',
      );
    }

    final filename = json['filename']?.toString().trim();

    return SyncAttachmentRef(
      field: field,
      path: path,
      filename: filename == null || filename.isEmpty ? null : filename,
    );
  }

  static List<SyncAttachmentRef> decodeList(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Sync attachment list must be an array.');
    }

    return decoded.map((item) {
      if (item is Map<String, dynamic>) {
        return SyncAttachmentRef.fromJson(item);
      }

      if (item is Map) {
        return SyncAttachmentRef.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const FormatException('Sync attachment must be an object.');
    }).toList();
  }
}
