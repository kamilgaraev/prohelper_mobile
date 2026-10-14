import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/data/drawing_annotations.dart';
import 'package:prohelpers_mobile/features/design_management/data/drawing_sync_models.dart';
import 'package:prohelpers_mobile/features/design_management/domain/drawing_sync_provider.dart';

final annotation = DrawingAnnotations.page(1, 1000, 700, [
  const DrawingStroke(
    tool: DrawingTool.line,
    points: [DrawingPoint(.1, .2), DrawingPoint(.8, .9)],
  ),
]);

SyncedDrawingStroke record(
  String id,
  int revision, {
  bool deleted = false,
  bool own = true,
}) => SyncedDrawingStroke(
  clientId: id,
  versionId: 22,
  revision: revision,
  authorId: own ? 7 : 8,
  authorName: own ? 'Иван' : 'Мария',
  createdAt: DateTime.utc(2026, 10, 14),
  canDelete: own,
  annotations: deleted ? null : annotation,
  deletedAt: deleted ? DateTime.utc(2026, 10, 14, 1) : null,
);

class FakeDrawingApi implements DrawingStrokeApi {
  final createIds = <String>[];
  final deletedIds = <String>[];
  final cursors = <int>[];
  Future<SyncedDrawingStroke> Function(String)? createHandler;
  Future<DrawingStrokeDelta> Function(int)? readHandler;
  @override
  Future<SyncedDrawingStroke> createDrawingStroke(
    int versionId,
    String clientId,
    DrawingAnnotations annotations,
  ) async {
    createIds.add(clientId);
    return createHandler != null
        ? await createHandler!(clientId)
        : record(clientId, 5);
  }

  @override
  Future<SyncedDrawingStroke> deleteDrawingStroke(
    int versionId,
    String clientId,
  ) async {
    deletedIds.add(clientId);
    return record(clientId, 6, deleted: true);
  }

  @override
  Future<DrawingStrokeDelta> drawingChanges(
    int versionId,
    int afterRevision,
  ) async {
    cursors.add(afterRevision);
    return readHandler != null
        ? await readHandler!(afterRevision)
        : const DrawingStrokeDelta(
          items: [],
          revision: 0,
          hasMore: false,
          canAnnotate: true,
        );
  }
}

void main() {
  late FakeDrawingApi api;
  late DrawingSyncNotifier sync;
  setUp(() {
    api = FakeDrawingApi();
    sync = DrawingSyncNotifier(api, 22, authorId: 7, authorName: 'Иван')
      ..start(poll: false);
  });
  tearDown(() {
    if (sync.mounted) sync.dispose();
  });

  test(
    'stroke autosaves without a comment and retry keeps the same UUID',
    () async {
      api.createHandler = (_) async => throw StateError('Connection lost');
      sync.add(annotation);
      expect(await sync.flush(), isFalse);
      expect(sync.state.pending, 1);
      expect(sync.state.items.single.authorName, 'Иван');
      final id = api.createIds.single;
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      api.createHandler = null;
      expect(await sync.flush(), isTrue);
      expect(api.createIds, [id, id]);
      expect(sync.state.pending, 0);
      expect(sync.state.saveError, isNull);
    },
  );

  test('POST acknowledgement cannot skip another participant delta', () async {
    sync.add(annotation);
    await sync.flush();
    api.readHandler =
        (_) async => DrawingStrokeDelta(
          items: [record('other', 4, own: false)],
          revision: 5,
          hasMore: false,
          canAnnotate: true,
        );
    await sync.refresh();
    expect(api.cursors, [0]);
    expect(sync.state.items.map((item) => item.authorName), contains('Мария'));
  });

  test('equal timestamps retain server order for undo', () async {
    api.readHandler =
        (_) async => DrawingStrokeDelta(
          items: [record('z-first', 1), record('a-last', 2)],
          revision: 2,
          hasMore: false,
          canAnnotate: true,
        );
    await sync.refresh();
    expect(sync.state.items.last.clientId, 'a-last');
    sync.remove(sync.state.items.last.clientId);
    await sync.flush();
    expect(api.deletedIds, ['a-last']);
  });

  test('delta pagination follows the GET cursor', () async {
    api.readHandler =
        (cursor) async => DrawingStrokeDelta(
          items: [record('p$cursor', cursor + 1)],
          revision: cursor + 1,
          hasMore: cursor == 0,
          canAnnotate: true,
        );
    await sync.refresh();
    expect(api.cursors, [0, 1]);
    expect(sync.state.items, hasLength(2));
  });

  test('late GET cannot resurrect a deleted stroke', () async {
    api.readHandler =
        (_) async => DrawingStrokeDelta(
          items: [record('own', 1)],
          revision: 1,
          hasMore: false,
          canAnnotate: true,
        );
    await sync.refresh();
    final reading = Completer<DrawingStrokeDelta>();
    api.readHandler = (_) => reading.future;
    final pendingRead = sync.refresh();
    sync.remove('own');
    await sync.flush();
    reading.complete(
      DrawingStrokeDelta(
        items: [record('own', 1)],
        revision: 1,
        hasMore: false,
        canAnnotate: true,
      ),
    );
    await pendingRead;
    expect(sync.state.items, isEmpty);
  });

  test(
    'undo during a lost POST response sends an authoritative tombstone',
    () async {
      final writing = Completer<SyncedDrawingStroke>();
      api.createHandler = (_) => writing.future;
      sync.add(annotation);
      final id = api.createIds.single;
      sync.remove(id);
      writing.completeError(StateError('Response lost'));
      expect(await sync.flush(), isTrue);
      expect(api.deletedIds, [id]);
      expect(sync.state.items, isEmpty);
      expect(sync.state.pending, 0);
    },
  );

  test(
    'foreign strokes cannot be removed and role revocation pauses writes',
    () async {
      api.readHandler =
          (_) async => DrawingStrokeDelta(
            items: [record('foreign', 1, own: false)],
            revision: 1,
            hasMore: false,
            canAnnotate: false,
          );
      await sync.refresh();
      sync.remove('foreign');
      sync.add(annotation);
      expect(await sync.flush(), isFalse);
      expect(api.deletedIds, isEmpty);
      expect(api.createIds, isEmpty);
      expect(sync.state.saveError, isNotNull);
    },
  );

  test(
    'disposed session drops late responses and sends no further strokes',
    () async {
      final reading = Completer<DrawingStrokeDelta>();
      api.readHandler = (_) => reading.future;
      final pendingRead = sync.refresh();
      sync.dispose();
      sync.add(annotation);
      reading.complete(
        DrawingStrokeDelta(
          items: [record('old-session', 1)],
          revision: 1,
          hasMore: false,
          canAnnotate: true,
        ),
      );
      await pendingRead;
      expect(api.createIds, isEmpty);
    },
  );

  test('wire record preserves authors and accepts cancellation tombstones', () {
    final json = <String, dynamic>{
      'client_id': 'stroke',
      'version_id': 22,
      'revision': 6,
      'author': {'id': 7, 'name': 'Иван'},
      'created_at': '2026-10-14T00:00:00Z',
      'deleted_at': null,
      'can_delete': true,
      'annotations': annotation.toJson(),
    };
    final parsed = SyncedDrawingStroke.fromJson(json);
    expect(parsed.annotations!.strokes.single.points.last.x, .8);
    expect(parsed.authorId, 7);
    final tombstone = SyncedDrawingStroke.fromJson({
      ...json,
      'deleted_at': '2026-10-14T01:00:00Z',
      'annotations': null,
    });
    expect(tombstone.annotations, isNull);
    expect(tombstone.deletedAt, isNotNull);
  });
}
