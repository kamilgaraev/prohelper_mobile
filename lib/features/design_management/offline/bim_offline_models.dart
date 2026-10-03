import 'dart:async';
import 'dart:convert';
import '../data/bim_models.dart';

class BimPackageAsset {
  const BimPackageAsset({
    required this.url,
    required this.sha256,
    required this.size,
    required this.mime,
  });
  final String url;
  final String sha256;
  final int size;
  final String mime;
  factory BimPackageAsset.fromJson(Map<String, dynamic> json) {
    final asset = BimPackageAsset(
      url: json['url'] as String,
      sha256: json['sha256'] as String,
      size: json['size'] as int,
      mime: json['mime'] as String,
    );
    final uri = Uri.parse(asset.url);
    if (asset.size <= 0 ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(asset.sha256) ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const FormatException('Некорректный пакет модели.');
    }
    return asset;
  }
}

class BimPackageManifest {
  BimPackageManifest(this.json) {
    if (json['schema_version'] != 1 ||
        json['version_id'] is! int ||
        json['project_id'] is! int ||
        json['organization_id'] is! int ||
        json['generation'] == null ||
        json['derivative_id'] == null ||
        json['converter_version'] == null ||
        json['runtime'] is! Map ||
        DateTime.tryParse(json['expires_at']?.toString() ?? '') == null) {
      throw const FormatException('Неподдерживаемый пакет модели.');
    }
    geometry = BimPackageAsset.fromJson(
      Map<String, dynamic>.from(json['geometry'] as Map),
    );
    properties = BimPackageAsset.fromJson(
      Map<String, dynamic>.from(json['properties'] as Map),
    );
  }
  final Map<String, dynamic> json;
  late final BimPackageAsset geometry;
  late final BimPackageAsset properties;
  int get versionId => json['version_id'] as int;
  int get projectId => json['project_id'] as int;
  int get organizationId => json['organization_id'] as int;
  String get generation => json['generation'].toString();
  String get fingerprint =>
      '${json['organization_id']}:${json['project_id']}:${json['version_id']}:${json['generation']}:${json['derivative_id']}:${json['converter_version']}:${geometry.sha256}:${geometry.size}:${properties.sha256}:${properties.size}:${jsonEncode(_canonical(json['runtime']))}:${jsonEncode(_canonical(json['transform']))}';
  int get totalBytes => geometry.size + properties.size;
  dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}

class BimOfflinePackage {
  const BimOfflinePackage({
    required this.versionId,
    required this.title,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.manifest,
    this.lastError,
  });
  final int versionId;
  final String title;
  final String status;
  final int downloadedBytes;
  final int totalBytes;
  final Map<String, dynamic> manifest;
  final String? lastError;
  bool get isReady => status == 'ready';
  double get progress => totalBytes == 0 ? 0 : downloadedBytes / totalBytes;
}

class BimDraftAttachmentInput {
  const BimDraftAttachmentInput({
    required this.path,
    required this.filename,
    required this.mime,
    this.kind = 'photo',
  });
  final String path;
  final String filename;
  final String mime;
  final String kind;
}

class BimIssueReceipt {
  const BimIssueReceipt(this.id, this.revision);
  final int id;
  final int revision;
}

class BimIssueDraft {
  const BimIssueDraft({
    required this.localId,
    required this.versionId,
    required this.payload,
    required this.attachments,
    required this.attempted,
    required this.status,
    this.serverId,
    this.lastError,
  });
  final String localId;
  final int versionId;
  final Map<String, dynamic> payload;
  final List<Map<String, dynamic>> attachments;
  final bool attempted;
  final String status;
  final int? serverId;
  final String? lastError;
  bool get editable => !attempted;
}

class BimLocalVersion {
  const BimLocalVersion({
    required this.versionId,
    required this.length,
    required this.mime,
    required this.manifest,
    required this.geometry,
  });
  final int versionId;
  final int length;
  final String mime;
  final Map<String, dynamic> manifest;
  final Stream<List<int>> Function({int start, int? end}) geometry;
}

class BimSavedSet {
  const BimSavedSet({
    required this.localId,
    required this.projectId,
    required this.setId,
    required this.modelSetRevisionId,
    required this.title,
    required this.versionIds,
    required this.transforms,
    required this.status,
    required this.completedModels,
    required this.totalModels,
    this.lastError,
  });
  final String localId;
  final int projectId;
  final int setId;
  final int modelSetRevisionId;
  final String title;
  final List<int> versionIds;
  final Map<int, BimTransform> transforms;
  final String status;
  final int completedModels;
  final int totalModels;
  final String? lastError;
  bool get isReady => status == 'ready' && completedModels == totalModels;
}

bool bimRuntimeCompatible(Map<String, dynamic> manifest) {
  final runtime = manifest['runtime'];
  return runtime is Map &&
      runtime['fragments'] == '3.4.5' &&
      runtime['web_ifc'] == '0.0.77' &&
      runtime['three'] == '0.184.0';
}
