import 'dart:io';

import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/encrypted_local_file_cache.dart';
import '../../../core/storage/entity_snapshot_service.dart';
import 'incoming_control_model.dart';
import 'incoming_control_upload.dart';

class IncomingControlSavedDraft {
  const IncomingControlSavedDraft(this.state, this.files);
  final Map<String, dynamic> state;
  final List<IncomingControlUpload> files;
}

class IncomingControlRestoredFileLease {
  IncomingControlRestoredFileLease(this.files, this._release);
  final List<IncomingControlUpload> files;
  final Future<void> Function(List<IncomingControlUpload>) _release;
  bool _released = false;
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _release(files);
  }
}

class IncomingControlDraftStore {
  IncomingControlDraftStore({
    required Future<EntitySnapshotService> snapshots,
    required EncryptedLocalFileCache files,
    required String? Function() ownerScope,
  }) : _snapshots = snapshots,
       _files = files,
       _ownerScope = ownerScope;
  final Future<EntitySnapshotService> _snapshots;
  final EncryptedLocalFileCache _files;
  final String? Function() _ownerScope;
  static const type = 'incoming_control_draft';

  Future<IncomingControlSavedDraft?> read(String id, int projectId) async {
    final scope = _ownerScope();
    if (scope == null) return null;
    final snapshots = await _snapshots;
    final entity = await snapshots.getOne(type, id, projectId: projectId);
    if (entity == null || scope != _ownerScope()) return null;
    final payload = decodeSnapshotPayload(entity);
    if (payload['owner_scope'] != scope || payload['cleared'] == true) {
      return null;
    }
    final restored = <IncomingControlUpload>[];
    for (final file in incomingMaps(payload['files'])) {
      final path = await _files.materialize(
        ownerIdentity: scope,
        encryptedPath: file['encrypted_path'].toString(),
        context: file['context'].toString(),
        fileName: file['filename']?.toString(),
      );
      if (scope != _ownerScope()) {
        await releaseFiles([
          ...restored,
          IncomingControlUpload(path: path, kind: file['kind'].toString()),
        ]);
        throw const SnapshotOwnerChangedException();
      }
      restored.add(
        IncomingControlUpload(
          path: path,
          originalFilename: file['filename']?.toString(),
          kind: file['kind'].toString(),
          metadata: incomingMap(
            file['metadata'],
          ).map((key, value) => MapEntry(key, value.toString())),
        ),
      );
    }
    return IncomingControlSavedDraft(incomingMap(payload['state']), restored);
  }

  Future<void> save(
    String id,
    int projectId,
    Map<String, dynamic> state,
    List<IncomingControlUpload> files,
  ) async {
    final scope = _ownerScope();
    if (scope == null) throw const SnapshotOwnerChangedException();
    final snapshots = await _snapshots;
    final owner = snapshots.currentOwner;
    if (owner == null || scope != _ownerScope()) {
      throw const SnapshotOwnerChangedException();
    }
    final previous = await snapshots.getOne(type, id, projectId: projectId);
    final previousFiles =
        previous == null
            ? const <Map<String, dynamic>>[]
            : incomingMaps(decodeSnapshotPayload(previous)['files']);
    final manifest = <Map<String, dynamic>>[];
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final context = 'incoming-control-draft:$projectId:$id:$index';
      final path = await _files.stageQueuedAttachment(
        ownerIdentity: scope,
        context: context,
        sourcePath: file.path,
      );
      manifest.add({
        'encrypted_path': path,
        'context': context,
        'filename': file.filename,
        'kind': file.kind,
        'metadata': file.metadata,
      });
    }
    if (scope != _ownerScope()) throw const SnapshotOwnerChangedException();
    await snapshots.putSnapshot(
      cachedEntityFromPayload(
        type: type,
        remoteId: id,
        projectId: projectId,
        payload: {'owner_scope': scope, 'state': state, 'files': manifest},
      ),
      expectedOwner: owner,
    );
    for (final previousFile in previousFiles) {
      if (!manifest.any(
        (file) => file['encrypted_path'] == previousFile['encrypted_path'],
      )) {
        await _files.deleteStagedUpload(
          previousFile['encrypted_path'].toString(),
        );
      }
    }
  }

  Future<void> clear(String id, int projectId) async {
    final scope = _ownerScope();
    final snapshots = await _snapshots;
    final owner = snapshots.currentOwner;
    if (scope == null || owner == null) return;
    final previous = await snapshots.getOne(type, id, projectId: projectId);
    if (scope != _ownerScope()) throw const SnapshotOwnerChangedException();
    await snapshots.putSnapshot(
      cachedEntityFromPayload(
        type: type,
        remoteId: id,
        projectId: projectId,
        payload: {'owner_scope': scope, 'cleared': true},
      ),
      expectedOwner: owner,
    );
    if (previous != null) {
      for (final file in incomingMaps(
        decodeSnapshotPayload(previous)['files'],
      )) {
        await _files.deleteStagedUpload(file['encrypted_path'].toString());
      }
    }
  }

  Future<void> releaseFiles(List<IncomingControlUpload> files) async {
    for (final file in files) {
      try {
        await _files.deleteStagedUpload(file.path);
      } on FileSystemException {
        continue;
      }
    }
  }
}
