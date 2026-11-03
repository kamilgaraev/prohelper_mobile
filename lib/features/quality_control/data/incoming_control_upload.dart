import 'package:dio/dio.dart';

import '../../../core/sync/sync_queue_draft.dart';

class IncomingControlUpload {
  const IncomingControlUpload({
    required this.path,
    required this.kind,
    this.metadata = const {},
    this.originalFilename,
  });
  final String path;
  final String kind;
  final Map<String, String> metadata;
  final String? originalFilename;
  String get filename =>
      originalFilename ?? path.replaceAll('\\', '/').split('/').last;

  Map<String, dynamic> fields(String prefix) => {
    '$prefix[kind]': kind,
    for (final entry in metadata.entries) '$prefix[${entry.key}]': entry.value,
  };
  SyncAttachmentRef attachment(String prefix) =>
      SyncAttachmentRef(field: '$prefix[file]', path: path, filename: filename);
}

Map<String, dynamic> flattenIncomingControlFields(
  Map<String, dynamic> payload,
) {
  final result = <String, dynamic>{};
  void add(String key, dynamic value) {
    if (value is Map) {
      for (final entry in value.entries) {
        add('$key[${entry.key}]', entry.value);
      }
    } else if (value is List) {
      for (var index = 0; index < value.length; index++) {
        add('$key[$index]', value[index]);
      }
    } else if (value != null) {
      result[key] = value is bool ? (value ? '1' : '0') : value.toString();
    }
  }

  for (final entry in payload.entries) {
    add(entry.key, entry.value);
  }
  return result;
}

Future<FormData> incomingControlMultipart(
  Map<String, dynamic> fields,
  List<SyncAttachmentRef> attachments,
) async {
  final form = FormData.fromMap(fields);
  for (final attachment in attachments) {
    form.files.add(
      MapEntry(
        attachment.field,
        await MultipartFile.fromFile(
          attachment.path,
          filename: attachment.filename,
        ),
      ),
    );
  }
  return form;
}
