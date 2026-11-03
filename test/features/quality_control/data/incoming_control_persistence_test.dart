import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_draft_store.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_file_service.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_upload.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  test(
    'WebP фото и точная историческая evidence версия открываются с авторизацией',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'most-incoming-webp-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final adapter = _AttachmentAdapter(
        bytes: const [82, 73, 70, 70],
        mime: 'image/webp',
      );
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://mobile-api.test/api/v1/mobile',
          headers: {'Authorization': 'Bearer test-only'},
        ),
      )..httpClientAdapter = adapter;
      final opened = <String>[];
      final service = IncomingControlFileService(
        dio,
        temporaryDirectory: () async => directory,
        openFile: (path) async {
          opened.add(path);
          expect(await File(path).readAsBytes(), [82, 73, 70, 70]);
          return true;
        },
      );
      await service.openAttachment(11, {
        'url': '/api/v1/mobile/quality-control/incoming-controls/11/evidence/5',
        'name': 'photo.webp',
        'mime': 'image/webp',
      });
      expect(
        adapter.request!.uri.path,
        '/api/v1/mobile/quality-control/incoming-controls/11/evidence/5',
      );
      expect(adapter.request!.headers['Authorization'], 'Bearer test-only');
      expect(adapter.request!.headers['Accept'], 'image/webp');
    expect(adapter.request!.followRedirects, false);
      expect(opened.single, endsWith('.webp'));
      await service.dispose();
      expect(await File(opened.single).exists(), false);
    },
  );
  test(
    'относительная защищённая ссылка скачивается с Bearer и открывается локально',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'most-incoming-download-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final adapter = _AttachmentAdapter();
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://mobile-api.test/api/v1/mobile',
          headers: {'Authorization': 'Bearer test-only'},
        ),
      )..httpClientAdapter = adapter;
      String? opened;
      final service = IncomingControlFileService(
        dio,
        temporaryDirectory: () async => directory,
        openFile: (path) async {
          opened = path;
          expect(await File(path).readAsBytes(), [37, 80, 68, 70]);
          return true;
        },
      );
      await service.openAttachment(11, {
        'url':
            '/api/v1/mobile/quality-control/incoming-controls/11/attachments/5',
        'name': '../../passport.exe',
        'mime': 'application/pdf',
      });
      expect(
        adapter.request!.uri.toString(),
        'https://mobile-api.test/api/v1/mobile/quality-control/incoming-controls/11/attachments/5',
      );
      expect(adapter.request!.headers['Authorization'], 'Bearer test-only');
      expect(opened, endsWith('-passport.pdf'));
      expect(File(opened!).parent.path, directory.path);
      await service.dispose();
      expect(await File(opened!).exists(), false);
    },
  );

  test('чужой origin и исполняемый MIME не получают токен скачивания', () async {
    final adapter = _AttachmentAdapter();
    final dio = Dio(
      BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
    )..httpClientAdapter = adapter;
    final service = IncomingControlFileService(dio);
    await expectLater(
      service.openAttachment(11, {
        'url':
            'https://other.test/api/v1/mobile/quality-control/incoming-controls/11/attachments/5',
        'name': 'file.pdf',
        'mime': 'application/pdf',
      }),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      service.openAttachment(11, {
        'url':
            '/api/v1/mobile/quality-control/incoming-controls/11/attachments/5',
        'name': 'file.exe',
        'mime': 'application/x-msdownload',
      }),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.request, null);
    await service.dispose();
  });

  test(
    'черновик и зашифрованный паспорт восстанавливаются после пересоздания хранилища',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'most-incoming-draft-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = await File(
        '${directory.path}/passport.pdf',
      ).writeAsString('private-passport');
      final keyStore = _Keys();
      final snapshotStore = MemoryEntitySnapshotStore();
      var owner = const EntitySnapshotOwner(userId: 1, orgId: 4);
      var scope = '1:4:session';
      IncomingControlDraftStore createStore() => IncomingControlDraftStore(
        snapshots: Future.value(
          EntitySnapshotService(
            store: snapshotStore,
            resolveOwner: () => owner,
          ),
        ),
        files: EncryptedLocalFileCache(
          keyStore: keyStore,
          directoryProvider: () async => directory,
          temporaryDirectoryProvider: () async => directory,
        ),
        ownerScope: () => scope,
      );
      await createStore().save(
        'project_delivery:12',
        9,
        {
          'values': {'batch_number': 'П-12', 'presented_quantity': '1000'},
          'context': {'operation_key': 'same-operation', 'warehouse_id': 3},
        },
        [
          IncomingControlUpload(
            path: source.path,
            kind: 'quality_document',
            metadata: const {
              'document_number': '12',
              'coverage_batch_number': 'П-12',
            },
          ),
        ],
      );
      await source.delete();
      final store = createStore();
      final restored = await store.read('project_delivery:12', 9);
      expect(restored!.state['context']['operation_key'], 'same-operation');
      expect(restored.state['values']['batch_number'], 'П-12');
      expect(restored.files.single.kind, 'quality_document');
      expect(restored.files.single.filename, 'passport.pdf');
      expect(
        await File(restored.files.single.path).readAsString(),
        'private-passport',
      );
      expect(await store.read('project_delivery:12', 10), null);
      owner = const EntitySnapshotOwner(userId: 2, orgId: 5);
      scope = '2:5:session';
      expect(await store.read('project_delivery:12', 9), null);
      owner = const EntitySnapshotOwner(userId: 1, orgId: 4);
      scope = '1:4:new-session';
      expect(await store.read('project_delivery:12', 9), null);
      scope = '1:4:session';
      await store.clear('project_delivery:12', 9);
      expect(await store.read('project_delivery:12', 9), null);
      await store.releaseFiles(restored.files);
    },
  );
}

class _Keys implements SecureFileKeyStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _AttachmentAdapter implements HttpClientAdapter {
  _AttachmentAdapter({
    this.bytes = const [37, 80, 68, 70],
    this.mime = 'application/pdf',
  });
  final List<int> bytes;
  final String mime;
  RequestOptions? request;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: [mime],
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }
}
