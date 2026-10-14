import 'drawing_annotations.dart';

class SyncedDrawingStroke {
  const SyncedDrawingStroke({
    required this.clientId,
    required this.versionId,
    required this.revision,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.canDelete,
    this.annotations,
    this.deletedAt,
    this.pending = false,
  });
  final String clientId;
  final int versionId;
  final int revision;
  final int? authorId;
  final String authorName;
  final DateTime createdAt;
  final bool canDelete;
  final DrawingAnnotations? annotations;
  final DateTime? deletedAt;
  final bool pending;

  factory SyncedDrawingStroke.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final deletedAt =
        json['deleted_at'] == null
            ? null
            : DateTime.tryParse(json['deleted_at'].toString());
    final annotations = DrawingAnnotations.tryParse(json['annotations']);
    final createdAt = DateTime.tryParse(json['created_at'].toString());
    if (json['client_id'] is! String ||
        json['version_id'] is! int ||
        json['revision'] is! int ||
        author is! Map ||
        author['name'] is! String ||
        createdAt == null ||
        (json['deleted_at'] != null && deletedAt == null) ||
        (deletedAt == null && annotations == null)) {
      throw const FormatException('Invalid shared drawing stroke');
    }
    return SyncedDrawingStroke(
      clientId: json['client_id'],
      versionId: json['version_id'],
      revision: json['revision'],
      authorId: author['id'] is int ? author['id'] as int : null,
      authorName: author['name'],
      createdAt: createdAt,
      annotations: annotations,
      deletedAt: deletedAt,
      canDelete: json['can_delete'] == true,
    );
  }

  SyncedDrawingStroke withPending(bool value) => SyncedDrawingStroke(
    clientId: clientId,
    versionId: versionId,
    revision: revision,
    authorId: authorId,
    authorName: authorName,
    createdAt: createdAt,
    canDelete: canDelete,
    annotations: annotations,
    deletedAt: deletedAt,
    pending: value,
  );
}

class DrawingStrokeDelta {
  const DrawingStrokeDelta({
    required this.items,
    required this.revision,
    required this.hasMore,
    required this.canAnnotate,
  });
  final List<SyncedDrawingStroke> items;
  final int revision;
  final bool hasMore;
  final bool canAnnotate;
  factory DrawingStrokeDelta.fromJson(Map<String, dynamic> json) {
    if (json['items'] is! List ||
        json['revision'] is! int ||
        json['has_more'] is! bool) {
      throw const FormatException('Invalid drawing changes');
    }
    return DrawingStrokeDelta(
      items:
          (json['items'] as List)
              .map(
                (item) => SyncedDrawingStroke.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
      revision: json['revision'],
      hasMore: json['has_more'],
      canAnnotate: json['can_annotate'] == true,
    );
  }
}

abstract interface class DrawingStrokeApi {
  Future<DrawingStrokeDelta> drawingChanges(int versionId, int afterRevision);
  Future<SyncedDrawingStroke> createDrawingStroke(
    int versionId,
    String clientId,
    DrawingAnnotations annotations,
  );
  Future<SyncedDrawingStroke> deleteDrawingStroke(
    int versionId,
    String clientId,
  );
}
