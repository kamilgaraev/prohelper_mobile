import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_models.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_provider.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_record.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_service.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_store.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_transport.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_models.dart';

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

class _Store implements BimOfflineStore {
  final values = <String, BimOfflineRecord>{};
  final elements = <BimElementIndex>[];
  void Function(BimOfflineRecord)? onPut;
  @override
  Future<List<BimOfflineRecord>> records(String scope) async =>
      values.values.where((item) => item.scope == scope).toList();
  @override
  Future<BimOfflineRecord?> get(String key) async => values[key];
  @override
  Future<void> put(BimOfflineRecord record) async {
    values[record.key] = record;
    onPut?.call(record);
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> putElements(List<BimElementIndex> items) async {
    elements.addAll(items);
  }

  @override
  Future<BimElementIndex?> element(String key, int id) async {
    for (final item in elements) {
      if (item.packageKey == key && item.expressId == id) return item;
    }
    return null;
  }

  @override
  Future<void> clearElements(String key) async {
    elements.removeWhere((item) => item.packageKey == key);
  }
}

class _Transport implements BimOfflineTransport {
  final geometry = List<int>.generate(180000, (index) => index % 251);
  final properties = utf8.encode(
    '${jsonEncode({
      'express_id': 42,
      'name': 'Стена',
      'properties': {'secret': 'private BIM value'},
    })}\n',
  );
  String generation = 'generation1';
  String runtimeFragments = '3.4.5';
  int? interruptVersion;
  bool interrupt = false;
  bool corrupt = false;
  bool deny = false;
  bool loseCreateResponse = false;
  bool loseAttachmentResponse = false;
  Completer<void>? downloadStarted;
  Completer<void>? allowDownload;
  int? blockVersion;
  bool deferCancellation = false;
  final offsets = <int>[];
  final createKeys = <String>[];
  final createPayloads = <String>[];
  final attachmentKeys = <String>[];
  final attachmentRevisions = <int>[];
  int createResources = 0;
  int attachmentResources = 0;
  final created = <String, BimIssueReceipt>{};
  final attached = <String, int>{};
  @override
  Future<BimPackageManifest> manifest(int id, CancelToken token) async {
    if (deny) {
      throw DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 403),
      );
    }
    return BimPackageManifest({
      'schema_version': 1,
      'generation': generation,
      'version_id': id,
      'project_id': 22,
      'organization_id': 2,
      'derivative_id': 8,
      'converter_version': 6,
      'runtime': {
        'fragments': runtimeFragments,
        'web_ifc': '0.0.77',
        'three': '0.184.0',
      },
      'expires_at': '2030-01-01T00:00:00Z',
      'geometry': {
        'url': 'https://example.test/model?version=$id',
        'sha256': sha256.convert(geometry).toString(),
        'size': geometry.length,
        'mime': 'application/octet-stream',
      },
      'properties': {
        'url': 'https://example.test/properties',
        'sha256': sha256.convert(properties).toString(),
        'size': properties.length,
        'mime': 'application/x-ndjson',
      },
      'localization': {
        'schema_version': 1,
        'locale': 'ru',
        'labels': {'expressid': 'Номер элемента IFC', 'name': 'Название'},
      },
    });
  }

  @override
  Future<Stream<List<int>>> download(
    BimPackageAsset asset,
    int offset,
    CancelToken token,
  ) async {
    offsets.add(offset);
    final bytes = asset.url.contains('/model') ? geometry : properties;
    if (allowDownload != null &&
        bytes == geometry &&
        (blockVersion == null ||
            blockVersion ==
                int.tryParse(
                  Uri.parse(asset.url).queryParameters['version'] ?? '',
                ))) {
      final gate = allowDownload!;
      allowDownload = null;
      return (() async* {
        yield bytes.sublist(offset, offset + 65536);
        downloadStarted?.complete();
        if (deferCancellation) {
          await gate.future;
        } else {
          await Future.any([gate.future, token.whenCancel]);
        }
        if (token.isCancelled) throw StateError('cancelled');
        yield bytes.sublist(offset + 65536);
      })();
    }
    if ((interrupt ||
            interruptVersion ==
                int.tryParse(
                  Uri.parse(asset.url).queryParameters['version'] ?? '',
                )) &&
        bytes == geometry) {
      interrupt = false;
      interruptVersion = null;
      return (() async* {
        yield bytes.sublist(offset, offset + 65536);
        throw const SocketException('lost network');
      })();
    }
    final result = bytes.sublist(offset);
    if (corrupt && bytes == geometry) result[0] ^= 1;
    return Stream.value(result);
  }

  @override
  Future<BimIssueReceipt> createIssue(
    Map<String, dynamic> payload,
    String key,
    CancelToken token,
  ) async {
    createKeys.add(key);
    createPayloads.add(jsonEncode(payload));
    final receipt = created.putIfAbsent(key, () {
      createResources++;
      return BimIssueReceipt(100, 1);
    });
    if (loseCreateResponse) {
      loseCreateResponse = false;
      throw const SocketException('lost acknowledgement');
    }
    return receipt;
  }

  @override
  Future<int> attach(
    int id,
    int revision,
    Map<String, dynamic> attachment,
    Stream<List<int>> Function() bytes,
    String key,
    CancelToken token,
  ) async {
    await bytes().drain<void>();
    attachmentKeys.add(key);
    attachmentRevisions.add(revision);
    final result = attached.putIfAbsent(key, () {
      attachmentResources++;
      return revision + 1;
    });
    if (loseAttachmentResponse) {
      loseAttachmentResponse = false;
      throw const SocketException('lost attachment acknowledgement');
    }
    return result;
  }
}

void main() {
  late Directory directory;
  late EncryptedLocalFileCache files;
  late _Store store;
  late _Transport transport;
  late BimOfflineService service;
  late String? scope;
  late bool access;
  late bool online;
  late DateTime now;
  BimOfflineService create() => BimOfflineService(
    store: store,
    files: files,
    transport: transport,
    currentScope: () => scope,
    canUseOffline: () async => access,
    isOnline: () async => online,
    verifyOnline: () async => true,
    clock: () => now,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('most-bim-test-');
    files = EncryptedLocalFileCache(
      keyStore: _Keys(),
      directoryProvider: () async => directory,
    );
    store = _Store();
    transport = _Transport();
    scope = '1:2:session';
    access = true;
    online = true;
    now = DateTime.utc(2026, 9, 29);
    service = create();
  });
  tearDown(() async {
    service.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'download resumes after service restart; geometry stays encrypted; index reads properties',
    () async {
      transport.interrupt = true;
      await expectLater(
        service.saveVersion(7),
        throwsA(isA<SocketException>()),
      );
      service.dispose();
      service = create();
      await service.saveVersion(7);
      expect(transport.offsets, contains(65536));
      final local = await service.cachedVersion(7);
      final bytes = await local!
          .geometry(start: 65000, end: 67000)
          .fold<List<int>>([], (all, part) => all..addAll(part));
      expect(bytes, transport.geometry.sublist(65000, 67000));
      final properties = await service.elementProperties(7, 42);
      expect(properties!['name'], 'Стена');
      expect(properties['display']['locale'], 'ru');
      expect(properties['display']['fields'][0]['label'], 'Номер элемента IFC');
      expect(store.elements.single.expressId, 42);
      final record = store.values.values.single;
      final encrypted = await File(record.propertiesPath).readAsBytes();
      expect(
        utf8.decode(encrypted, allowMalformed: true),
        isNot(contains('private BIM value')),
      );
      expect((await service.packages()).single.status, 'ready');
    },
  );
  test('two model versions can save in parallel', () async {
    await Future.wait([service.saveVersion(7), service.saveVersion(8)]);
    expect((await service.packages()).where((item) => item.isReady).length, 2);
  });
  test(
    'set components from another project are rejected before geometry download',
    () async {
      await expectLater(
        service.saveSet(
          projectId: 33,
          setId: 9,
          modelSetRevisionId: 14,
          title: 'Неверный проект',
          versionIds: [7],
        ),
        throwsStateError,
      );
      expect(transport.offsets, isEmpty);
      expect((await service.savedSets()).single.isReady, false);
      expect(await service.cachedSet('33:9:14'), isNull);
    },
  );
  test(
    'saved set survives cold restart with exact order, revision and transforms and resumes partial model',
    () async {
      transport.blockVersion = 7;
      transport.downloadStarted = Completer<void>();
      transport.allowDownload = Completer<void>();
      final pending = service.saveSet(
        projectId: 22,
        setId: 9,
        modelSetRevisionId: 14,
        title: 'Точный набор',
        versionIds: [8, 7],
        transforms: {
          8: const BimTransform(shift: [12.5, -2, 10], rotation: 37.5),
        },
      );
      await transport.downloadStarted!.future;
      expect((await service.savedSets()).single.completedModels, 1);
      expect(await service.cachedSet('22:9:14'), isNull);
      service.stopOperations();
      await pending;
      service.dispose();
      service = create();
      online = false;
      final partial = (await service.savedSets()).single;
      expect(partial.versionIds, [8, 7]);
      expect(partial.modelSetRevisionId, 14);
      expect(partial.transforms[8]!.shift, [12.5, -2, 10]);
      expect(partial.transforms[8]!.rotation, 37.5);
      expect(partial.isReady, false);
      final encrypted =
          await File(
            store.values.values
                .firstWhere((item) => item.kind == 'saved_set')
                .encryptedPath,
          ).readAsBytes();
      expect(
        utf8.decode(encrypted, allowMalformed: true),
        isNot(contains('model_set_revision_id')),
      );
      online = true;
      await service.resumeInterruptedDownloads();
      final ready = await service.cachedSet('22:9:14');
      expect(ready!.isReady, true);
      expect(ready.versionIds, [8, 7]);
      expect(ready.transforms[8]!.rotation, 37.5);
      expect(transport.offsets, contains(65536));
      scope = '1:3:session';
      expect(await service.savedSets(), isEmpty);
      scope = '1:2:session';
      await service.removeVersion(7);
      expect(await service.cachedSet('22:9:14'), isNull);
    },
  );
  test('removing saved set preserves shared version caches', () async {
    await service.saveSet(
      projectId: 22,
      setId: 9,
      modelSetRevisionId: 14,
      title: 'Набор',
      versionIds: [7, 8],
    );
    await service.removeSet('22:9:14');
    expect(await service.savedSets(), isEmpty);
    expect((await service.packages()).length, 2);
  });
  test(
    'renderer runtime mismatch cannot be saved or served silently',
    () async {
      transport.runtimeFragments = '3.3.0';
      await expectLater(service.saveVersion(7), throwsStateError);
      expect(await service.cachedVersion(7), isNull);
      transport.runtimeFragments = '3.4.5';
      await service.saveVersion(7);
      final record = store.values.values.single;
      final json = jsonDecode(record.manifestJson) as Map<String, dynamic>;
      (json['runtime'] as Map)['fragments'] = '3.3.0';
      record.manifestJson = jsonEncode(json);
      online = false;
      await expectLater(service.cachedVersion(7), throwsStateError);
    },
  );
  test(
    'quick foreground waits for cancelling download then starts a replacement',
    () async {
      transport.downloadStarted = Completer<void>();
      final release = Completer<void>();
      transport.allowDownload = release;
      transport.deferCancellation = true;
      final pending = service.saveVersion(7);
      await transport.downloadStarted!.future;
      service.stopOperations();
      final resuming = service.resumeInterruptedDownloads();
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait([pending, resuming]);
      expect(transport.offsets, contains(65536));
      expect((await service.packages()).single.isReady, true);
    },
  );
  test(
    'background during draft commit rolls back complete draft and encrypted attachments',
    () async {
      final source = File('${directory.path}/photo.png');
      await source.writeAsBytes([137, 80, 78, 71]);
      store.onPut = (record) {
        if (record.kind == 'draft') {
          store.onPut = null;
          service.stopOperations();
        }
      };
      await expectLater(
        service.createDraft(
          versionId: 7,
          payload: {'title': 'photo'},
          attachments: [
            BimDraftAttachmentInput(
              path: source.path,
              filename: 'photo.png',
              mime: 'image/png',
            ),
          ],
        ),
        throwsStateError,
      );
      expect(await service.drafts(), isEmpty);
      expect(store.values, isEmpty);
      final encrypted =
          await directory
              .list(recursive: true)
              .where((item) => item is File && item.path.endsWith('.enc'))
              .toList();
      expect(encrypted, isEmpty);
    },
  );
  test(
    'SHA mismatch deletes corrupted geometry and never marks ready',
    () async {
      transport.corrupt = true;
      await expectLater(
        service.saveVersion(7),
        throwsA(isA<FormatException>()),
      );
      expect((await service.packages()).single.status, 'error');
      expect(
        await File(store.values.values.single.encryptedPath).exists(),
        false,
      );
      expect(await service.cachedVersion(7), isNull);
    },
  );
  test('explicit cancel is paused and removable after restart', () async {
    transport.downloadStarted = Completer<void>();
    transport.allowDownload = Completer<void>();
    final pending = service.saveVersion(7);
    await transport.downloadStarted!.future;
    service.cancelVersion(7);
    await pending;
    expect((await service.packages()).single.status, 'paused');
    service.dispose();
    service = create();
    await service.resumeInterruptedDownloads();
    expect(transport.offsets.length, 1);
    await service.removeVersion(7);
    expect(await service.packages(), isEmpty);
    expect(store.elements, isEmpty);
  });
  test(
    'background interruption resumes in foreground using encrypted persisted offset',
    () async {
      transport.downloadStarted = Completer<void>();
      transport.allowDownload = Completer<void>();
      final pending = service.saveVersion(7);
      await transport.downloadStarted!.future;
      service.stopOperations();
      await pending;
      await service.resumeInterruptedDownloads();
      expect(transport.offsets, contains(65536));
      expect((await service.packages()).single.status, 'ready');
    },
  );
  test(
    'stream refuses reads after context change and stops before yielding bytes',
    () async {
      await service.saveVersion(7);
      final local = await service.cachedVersion(7);
      scope = '1:3:session';
      await expectLater(local!.geometry().drain<void>(), throwsStateError);
    },
  );
  test('generation change discards partial and downloads from zero', () async {
    transport.interrupt = true;
    await expectLater(service.saveVersion(7), throwsA(isA<SocketException>()));
    transport.generation = 'generation2';
    await service.saveVersion(7);
    expect(transport.offsets.take(2), [0, 0]);
  });
  test('online 403 blocks cached viewing and element reads', () async {
    await service.saveVersion(7);
    transport.deny = true;
    await expectLater(service.cachedVersion(7), throwsA(isA<DioException>()));
    expect(await service.elementProperties(7, 42), isNull);
    expect((await service.packages()).single.status, 'blocked');
  });
  test(
    'expired auth and another organization cannot read local model',
    () async {
      await service.saveVersion(7);
      scope = '1:3:session';
      expect(await service.cachedVersion(7), isNull);
      expect(await service.packages(), isEmpty);
      scope = '1:2:session';
      access = false;
      await expectLater(service.cachedVersion(7), throwsStateError);
    },
  );
  test(
    'draft editable before first attempt; lost create ack reuses frozen payload and key',
    () async {
      final draft = await service.createDraft(
        versionId: 7,
        payload: {'project_id': 1, 'title': 'first', 'express_id': 42},
      );
      await service.updateDraft(
        draft.localId,
        payload: {'project_id': 1, 'title': 'edited', 'express_id': 42},
      );
      transport.loseCreateResponse = true;
      await service.syncPending();
      expect((await service.drafts()).single.attempted, true);
      await expectLater(
        service.updateDraft(draft.localId, payload: {'title': 'changed'}),
        throwsStateError,
      );
      now = now.add(const Duration(minutes: 10));
      service.dispose();
      service = create();
      await service.syncPending();
      expect(transport.createKeys[0], transport.createKeys[1]);
      expect(transport.createPayloads[0], transport.createPayloads[1]);
      expect(transport.createResources, 1);
      expect((await service.drafts()).single.status, 'completed');
    },
  );
  test(
    'attachment retry preserves key and expected revision, complete only after all acks',
    () async {
      final source = File('${directory.path}/photo.png');
      await source.writeAsBytes([137, 80, 78, 71]);
      await service.createDraft(
        versionId: 7,
        payload: {'project_id': 1, 'title': 'photo'},
        attachments: [
          BimDraftAttachmentInput(
            path: source.path,
            filename: 'photo.png',
            mime: 'image/png',
            kind: 'snapshot',
          ),
        ],
      );
      transport.loseAttachmentResponse = true;
      await service.syncPending();
      expect((await service.drafts()).single.status, 'queued');
      expect((await service.drafts()).single.serverId, 100);
      now = now.add(const Duration(minutes: 10));
      await service.syncPending();
      expect(transport.createKeys.length, 1);
      expect(transport.attachmentKeys[0], transport.attachmentKeys[1]);
      expect(transport.attachmentRevisions, [1, 1]);
      expect(transport.attachmentResources, 1);
      expect((await service.drafts()).single.status, 'completed');
    },
  );
  test(
    'oversized photo is rejected before draft persistence or create request',
    () async {
      final source = File('${directory.path}/large.png');
      final file = await source.open(mode: FileMode.write);
      await file.truncate(10 * 1024 * 1024 + 1);
      await file.close();
      await expectLater(
        service.createDraft(
          versionId: 7,
          payload: {'project_id': 1, 'title': 'large photo'},
          attachments: [
            BimDraftAttachmentInput(
              path: source.path,
              filename: 'large.png',
              mime: 'image/png',
            ),
          ],
        ),
        throwsStateError,
      );
      expect(await service.drafts(), isEmpty);
      expect(transport.createResources, 0);
    },
  );
  test(
    'context transition requires explicit discard and retains pending after rejection',
    () async {
      await service.createDraft(
        versionId: 7,
        payload: {'project_id': 1, 'title': 'retain'},
      );
      await expectLater(service.prepareContextChange(), throwsStateError);
      expect(await service.hasPending(), true);
      await service.prepareContextChange(discard: true);
      expect(await service.drafts(), isEmpty);
    },
  );
  test(
    'offline auth window includes fourteen days and excludes expired, future and mismatched scope',
    () {
      final record = {
        'token': 'present',
        'user_id': 1,
        'organization_id': 2,
        'session_id': 'session',
        'confirmed_at':
            now.subtract(const Duration(days: 14)).toIso8601String(),
      };
      expect(bimOfflineAuthIsValid(record, now, '1:2:session'), true);
      expect(
        bimOfflineAuthIsValid(
          record,
          now.add(const Duration(seconds: 1)),
          '1:2:session',
        ),
        false,
      );
      expect(bimOfflineAuthIsValid(record, now, '1:3:session'), false);
      record['confirmed_at'] =
          now.add(const Duration(seconds: 1)).toIso8601String();
      expect(bimOfflineAuthIsValid(record, now, '1:2:session'), false);
    },
  );
}
