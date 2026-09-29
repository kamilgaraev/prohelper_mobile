import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_models.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_repository.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_models.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_provider.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_record.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_service.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_store.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_transport.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_viewer_surface.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../test/helpers/mobile_integration_test_helpers.dart';

const _stage = String.fromEnvironment('BIM_COLD_STAGE');
const _runId = String.fromEnvironment('BIM_COLD_RUN_ID');
const _configUrl = String.fromEnvironment('BIM_API_CONFIG_URL');
const _applicationId = 'ru.prohelper.prohelpers_mobile.bimacceptance';
const _isarName = 'bim-cold-private';
int _configurationRequests = 0;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'BIM offline survives a real Android process restart',
    (tester) async {
      expect(Platform.isAndroid, true);
      expect(_stage, anyOf('save', 'reopen'));
      expect(
        RegExp(r'^[a-z0-9][a-z0-9-]{5,47}$').hasMatch(_runId),
        true,
        reason: 'Pass a fresh short BIM_COLD_RUN_ID for both stages.',
      );
      final process = await _native(tester, _processIdentity);
      expect(
        process['command'],
        _applicationId,
        reason:
            'Use the isolated acceptance applicationId; never the installed QA application.',
      );
      final support = await _native(tester, getApplicationSupportDirectory);
      final root = Directory('${support.path}/bim-cold-$_runId');
      final report = <String, dynamic>{
        'stage': _stage,
        'run_id': _runId,
        'process': process,
        'application_id': _applicationId,
        'native_key_store':
            'FlutterSecureStorage default; no serialized AES key',
        'os_network_disabled': false,
      };
      binding.reportData = report;
      if (_stage == 'save') {
        await _saveStage(tester, root, process, report);
      } else {
        expect(
          _configUrl,
          isEmpty,
          reason: 'The reopen APK must omit BIM_API_CONFIG_URL.',
        );
        await _reopenStage(tester, root, report);
      }
      debugPrint('BIM_COLD_DEVICE_RESULT ${jsonEncode(report)}');
    },
    skip: _stage.isEmpty,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _saveStage(
  WidgetTester tester,
  Directory root,
  Map<String, dynamic> process,
  Map<String, dynamic> report,
) async {
  expect(
    await _native(tester, root.exists),
    false,
    reason: 'Do not overwrite a previous acceptance run.',
  );
  final config = await _native(tester, _configuration);
  await _native(tester, () => root.create(recursive: true));
  final api = _api(config);
  final downloads = Dio(
    BaseOptions(receiveTimeout: const Duration(minutes: 2)),
  );
  var apiRequests = 0;
  var downloadRequests = 0;
  api.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        apiRequests++;
        handler.next(options);
      },
    ),
  );
  downloads.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        downloadRequests++;
        handler.next(options);
      },
    ),
  );
  final files = _files(root);
  final userId = _id(config, 'USER_ID');
  final organizationId = _id(config, 'ORGANIZATION_ID');
  final projectId = _id(config, 'PROJECT_ID');
  final setId = _id(config, 'SET_ID');
  final revision = _id(config, 'SET_REVISION');
  final scope = '$userId:$organizationId:$_runId';
  final isar = await _native(tester, () => _openIsar(root));
  var online = true;
  final service = BimOfflineService(
    store: IsarBimOfflineStore(isar),
    files: files,
    transport: DioBimOfflineTransport(api, downloads: downloads),
    currentScope: () => scope,
    canUseOffline: () async => true,
    isOnline: () async => online,
    verifyOnline: () async => online,
  );
  var completed = false;
  try {
    final context = BimViewContext.fromJson(
      await _native(tester, () => BimRepository(api).openSet(setId, revision)),
    );
    expect(context.versionIds, hasLength(greaterThanOrEqualTo(2)));
    final revisionId = _id(config, 'MODEL_SET_REVISION_ID');
    expect(context.modelSetRevisionId, revisionId);
    final versionId = _id(config, 'VERSION_ID');
    expect(context.versionIds, contains(versionId));
    await _native(
      tester,
      () => service.saveVersion(
        versionId,
        projectId: projectId,
        title: 'Приёмка: модель',
      ),
    );
    await _native(
      tester,
      () => service.saveSet(
        projectId: projectId,
        setId: setId,
        modelSetRevisionId: revisionId,
        title: 'Приёмка: точный набор',
        versionIds: context.versionIds,
        transforms: context.transforms,
      ),
    );
    online = false;
    final saved = (await _native(tester, service.savedSets)).single;
    expect(saved.isReady, true);
    final document = await _native(tester, () => _document(service, saved));
    final proof = <String, dynamic>{
      'run_id': _runId,
      'scope': scope,
      'user_id': userId,
      'organization_id': organizationId,
      'project_id': projectId,
      'set_id': setId,
      'revision_id': revisionId,
      'version_id': versionId,
      'express_id': _id(config, 'EXPRESS_ID'),
      'set_local_id': saved.localId,
      'version_ids': context.versionIds,
      'transforms': {
        for (final id in context.versionIds)
          '$id': (context.transforms[id] ?? const BimTransform()).toJson(),
      },
      'saved_process': process,
      'auth': {
        'token': config['BIM_API_TOKEN'],
        'user_id': userId,
        'organization_id': organizationId,
        'session_id': _runId,
        'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      },
    };
    final viewer = await _openViewer(tester, document, api, proof);
    try {
      await _native(tester, () => viewer.controller.setCameraPreset('front'));
      final offset =
          (config['BIM_COLD_SECTION_OFFSET'] as num?)?.toDouble() ?? 2.74891;
      await _native(tester, () => viewer.controller.setSection('x', offset));
      final selected = await _native(tester, viewer.controller.getViewState);
      selected['selection'] = [
        {'version_id': '$versionId', 'element_id': proof['express_id']},
      ];
      await _native(tester, () => viewer.controller.applyViewState(selected));
      final snapshot = await _native(
        tester,
        viewer.controller.captureViewSnapshot,
      );
      expect(snapshot.viewState['sections'], isNotEmpty);
      await _native(tester, () => _checkPng(snapshot.bytes));
      await _native(tester, viewer.controller.clearSections);
      await _native(tester, () => viewer.controller.setCameraPreset('top'));
      final photo = await _native(tester, viewer.controller.captureSnapshot);
      await _native(tester, () => _checkPng(photo));
      final snapshotPath = File('${root.path}/snapshot.png');
      final photoPath = File('${root.path}/photo.png');
      await _native(tester, () async {
        await snapshotPath.writeAsBytes(snapshot.bytes, flush: true);
        await photoPath.writeAsBytes(photo, flush: true);
      });
      final draft = await _native(
        tester,
        () => service.createDraft(
          versionId: versionId,
          payload: {
            'project_id': projectId,
            'title': 'Холодный запуск $_runId',
            'severity': 'minor',
            'description': 'Зашифрованное замечание до перезапуска процесса.',
            'express_id': proof['express_id'],
            'model_set_revision_id': revisionId,
            'view_state': snapshot.viewState,
          },
          attachments: [
            BimDraftAttachmentInput(
              path: snapshotPath.path,
              filename: 'snapshot.png',
              mime: 'image/png',
              kind: 'snapshot',
            ),
            BimDraftAttachmentInput(
              path: photoPath.path,
              filename: 'photo.png',
              mime: 'image/png',
            ),
          ],
        ),
      );
      expect(draft.attempted, false);
      proof['draft_id'] = draft.localId;
      proof['draft_payload'] = draft.payload;
      proof['view_state'] = snapshot.viewState;
      proof['attachment_sha256'] = {
        'snapshot': sha256.convert(snapshot.bytes).toString(),
        'photo': sha256.convert(photo).toString(),
      };
      await _native(tester, () async {
        await snapshotPath.delete();
        await photoPath.delete();
      });
      final bootstrap = await _native(tester, () => _writeProof(files, proof));
      await _native(
        tester,
        () => File(
          '${root.path}/bootstrap.json',
        ).writeAsString(jsonEncode(bootstrap), flush: true),
      );
      final records = await _native(
        tester,
        () => IsarBimOfflineStore(isar).records(scope),
      );
      for (final record in records) {
        expect(record.encryptedPath.startsWith(root.path), true);
      }
      report.addAll({
        'version_ids': context.versionIds,
        'set_revision_id': revisionId,
        'draft_attachments': 2,
        'api_requests': apiRequests,
        'geometry_requests': downloadRequests,
        'configuration_requests': _configurationRequests,
        'cache_preserved_for_next_process': true,
      });
      expect(apiRequests, greaterThan(0));
      expect(downloadRequests, greaterThan(0));
      completed = true;
      debugPrint('BIM_COLD_STAGE_SAVED run=$_runId pid=${process['pid']}');
    } finally {
      await _closeViewer(tester, viewer);
    }
  } finally {
    service.dispose();
    await _native(tester, () => isar.close());
    api.close(force: true);
    downloads.close(force: true);
    if (!completed) await _native(tester, () => _cleanup(root, files, scope));
  }
}

Future<void> _reopenStage(
  WidgetTester tester,
  Directory root,
  Map<String, dynamic> report,
) async {
  expect(
    await _native(tester, root.exists),
    true,
    reason: 'Run stage save without uninstalling or clearing application data.',
  );
  final files = _files(root);
  final bootstrap = await _native(
    tester,
    () async => Map<String, dynamic>.from(
      jsonDecode(await File('${root.path}/bootstrap.json').readAsString())
          as Map,
    ),
  );
  expect(bootstrap['run_id'], _runId);
  expect((bootstrap['encrypted_path'] as String).startsWith(root.path), true);
  final proof = await _native(tester, () => _readProof(files, bootstrap));
  final previous = proof['saved_process'] as Map;
  final current = report['process'] as Map;
  expect(
    '${current['pid']}:${current['start_ticks']}',
    isNot('${previous['pid']}:${previous['start_ticks']}'),
    reason:
        'Force-stop the save process; hot reload or reopening Isar is not a cold launch.',
  );
  expect(proof['run_id'], _runId);
  final scope = proof['scope'] as String;
  final auth = Map<String, dynamic>.from(proof['auth'] as Map);
  expect(bimOfflineAuthIsValid(auth, DateTime.now(), scope), true);
  final barrier = _OfflineAdapter();
  final api = Dio()..httpClientAdapter = barrier;
  final isar = await _native(tester, () => _openIsar(root));
  final service = BimOfflineService(
    store: IsarBimOfflineStore(isar),
    files: files,
    transport: DioBimOfflineTransport(api, downloads: api),
    currentScope: () => scope,
    canUseOffline:
        () async => bimOfflineAuthIsValid(auth, DateTime.now(), scope),
    isOnline: () async => false,
    verifyOnline: () async {
      fail('Offline reopen must not verify against the API.');
    },
  );
  try {
    final saved = await _native(
      tester,
      () => service.cachedSet(proof['set_local_id'] as String),
    );
    expect(saved, isNotNull);
    expect(saved!.versionIds, proof['version_ids']);
    expect(saved.projectId, proof['project_id']);
    expect(saved.setId, proof['set_id']);
    expect(saved.modelSetRevisionId, proof['revision_id']);
    _expectState({
      for (final id in saved.versionIds) '$id': saved.transforms[id]!.toJson(),
    }, proof['transforms']);
    final store = IsarBimOfflineStore(isar);
    final records = await _native(tester, () => store.records(scope));
    for (final record in records.where((item) => item.kind == 'package')) {
      final manifest = BimPackageManifest(
        Map<String, dynamic>.from(jsonDecode(record.manifestJson) as Map),
      );
      final local = await _native(
        tester,
        () => service.cachedVersion(record.versionId),
      );
      expect(local, isNotNull);
      final hash = await _native(
        tester,
        () => sha256.bind(local!.geometry()).first,
      );
      expect(hash.toString(), manifest.geometry.sha256);
      final propertiesHash = await _native(
        tester,
        () =>
            sha256
                .bind(
                  files.decryptStream(
                    ownerIdentity: 'bim:$scope',
                    encryptedPath: record.propertiesPath,
                    context: '${record.key}:${manifest.generation}:properties',
                    totalLength: manifest.properties.size,
                  ),
                )
                .first,
      );
      expect(propertiesHash.toString(), manifest.properties.sha256);
    }
    final properties = await _native(
      tester,
      () => service.elementProperties(
        proof['version_id'] as int,
        proof['express_id'] as int,
      ),
    );
    expect(properties?['express_id'], proof['express_id']);
    final drafts = await _native(tester, service.drafts);
    final draft = drafts.singleWhere(
      (item) => item.localId == proof['draft_id'],
    );
    expect(draft.attempted, false);
    expect(draft.status, 'queued');
    expect(draft.serverId, isNull);
    expect(draft.attachments, hasLength(2));
    _expectState(draft.payload, proof['draft_payload']);
    for (final attachment in draft.attachments) {
      final hash = await _native(
        tester,
        () =>
            sha256
                .bind(
                  files.decryptStream(
                    ownerIdentity: 'bim:$scope',
                    encryptedPath: attachment['path'] as String,
                    context: attachment['context'] as String,
                    totalLength: attachment['size'] as int,
                  ),
                )
                .first,
      );
      expect(
        hash.toString(),
        (proof['attachment_sha256'] as Map)[attachment['kind']],
      );
    }
    final document = await _native(tester, () => _document(service, saved));
    final viewer = await _openViewer(tester, document, api, proof);
    try {
      await _native(
        tester,
        () => viewer.controller.restoreIssueView(
          Map<String, dynamic>.from(proof['view_state'] as Map),
        ),
      );
      _expectState(
        await _native(tester, viewer.controller.getViewState),
        proof['view_state'],
      );
      final png = await _native(tester, viewer.controller.captureSnapshot);
      await _native(tester, () => _checkPng(png));
      final resources = await _native(tester, () => _inspect(viewer));
      final origin = Uri.parse(resources['url'] as String).origin;
      expect(Uri.parse(origin).host, '127.0.0.1');
      expect(resources['webgl2'], true);
      for (final resource in resources['resources'] as List) {
        final uri = Uri.parse(resource as String);
        expect(
          uri.scheme == 'blob' || uri.scheme == 'data' || uri.origin == origin,
          true,
          reason: 'WebView resource must be bundled/local: ${uri.scheme}.',
        );
      }
      report['webview_resources_local'] = true;
      report['native_webgl_camera_sections_restored'] = true;
    } finally {
      await _closeViewer(tester, viewer);
    }
    final first = records.firstWhere((item) => item.kind == 'package');
    await _native(tester, () => _corruptCiphertext(first.encryptedPath));
    final corrupted = await _native(
      tester,
      () => service.cachedVersion(first.versionId),
    );
    expect(corrupted, isNotNull);
    await _native(tester, () async {
      await expectLater(corrupted!.geometry().drain<void>(), throwsA(anything));
    });
    final failed = await _openViewer(
      tester,
      document,
      api,
      proof,
      expectFailure: true,
    );
    await _closeViewer(tester, failed);
    expect(barrier.requests, isEmpty);
    expect(_configurationRequests, 0);
    report.addAll({
      'saved_process': previous,
      'process_restart_verified': true,
      'version_ids': saved.versionIds,
      'set_revision_id': saved.modelSetRevisionId,
      'configuration_requests': _configurationRequests,
      'native_http_requests': barrier.requests.length,
      'external_webview_http_resources': 0,
      'corrupted_ciphertext_refused_by_stream_and_viewer': true,
      'draft_and_both_images_restored': true,
      'network_proof':
          'offline service guard and rejecting native Dio adapter; observed WebView HTTP resources loopback only; OS connectivity was not changed',
    });
    debugPrint('BIM_COLD_STAGE_REOPENED run=$_runId pid=${current['pid']}');
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    await _native(tester, () => isar.close());
    api.close(force: true);
    await _native(tester, () => _cleanup(root, files, scope));
    report['private_run_cache_cleaned'] = true;
  }
}

EncryptedLocalFileCache _files(Directory root) => EncryptedLocalFileCache(
  directoryProvider: () async => root,
  temporaryDirectoryProvider: () async => root,
);
Future<Isar> _openIsar(Directory root) => Isar.open(
  [BimOfflineRecordSchema, BimElementIndexSchema],
  directory: root.path,
  name: _isarName,
);
String get _proofOwner => 'bim-cold-proof:$_runId';
String get _proofContext => 'cold-proof:$_runId';

Future<Map<String, dynamic>> _writeProof(
  EncryptedLocalFileCache files,
  Map<String, dynamic> proof,
) async {
  final bytes = utf8.encode(jsonEncode(proof));
  final path = await files.streamPath(
    ownerIdentity: _proofOwner,
    context: _proofContext,
  );
  await files.appendEncryptedStream(
    ownerIdentity: _proofOwner,
    context: _proofContext,
    encryptedPath: path,
    totalLength: bytes.length,
    source: Stream.value(bytes),
  );
  return {
    'schema_version': 1,
    'run_id': _runId,
    'encrypted_path': path,
    'length': bytes.length,
  };
}

Future<Map<String, dynamic>> _readProof(
  EncryptedLocalFileCache files,
  Map<String, dynamic> bootstrap,
) async {
  expect(bootstrap['schema_version'], 1);
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in files.decryptStream(
    ownerIdentity: _proofOwner,
    context: _proofContext,
    encryptedPath: bootstrap['encrypted_path'] as String,
    totalLength: bootstrap['length'] as int,
  )) {
    bytes.add(chunk);
  }
  return Map<String, dynamic>.from(
    jsonDecode(utf8.decode(bytes.takeBytes())) as Map,
  );
}

Future<void> _cleanup(
  Directory root,
  EncryptedLocalFileCache files,
  String scope,
) async {
  final support = await getApplicationSupportDirectory();
  expect(root.absolute.path, '${support.path}/bim-cold-$_runId');
  if (await root.exists()) {
    expect(
      await root.resolveSymbolicLinks(),
      '${await support.resolveSymbolicLinks()}/bim-cold-$_runId',
    );
  }
  await files.clearIdentity('bim:$scope');
  await files.clearIdentity(_proofOwner);
  if (await root.exists()) await root.delete(recursive: true);
}

Future<Map<String, dynamic>> _configuration() async {
  expect(_stage, 'save');
  expect(_configUrl, isNotEmpty);
  final uri = Uri.parse(_configUrl);
  expect(
    uri.host,
    '127.0.0.1',
    reason:
        'Use the private opt-in fixture descriptor through device forwarding.',
  );
  _configurationRequests++;
  final dio = Dio();
  try {
    return Map<String, dynamic>.from(
      (await dio.get<dynamic>(_configUrl)).data as Map,
    );
  } finally {
    dio.close(force: true);
  }
}

int _id(Map<String, dynamic> config, String name) {
  final id = bimInt(config['BIM_API_$name']);
  if (id <= 0) {
    throw StateError(
      'Missing positive BIM_API_$name acceptance descriptor field.',
    );
  }
  return id;
}

Dio _api(Map<String, dynamic> config) {
  final base = '${config['BIM_API_BASE_URL']}';
  expect(Uri.parse(base).host, '127.0.0.1');
  expect('${config['BIM_API_TOKEN']}', isNotEmpty);
  return Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 2),
      headers: {
        'Authorization': 'Bearer ${config['BIM_API_TOKEN']}',
        'X-Organization-ID': '${config['BIM_API_ORGANIZATION_ID']}',
        'Accept': 'application/json',
      },
    ),
  );
}

Future<Map<String, dynamic>> _processIdentity() async {
  final command =
      utf8
          .decode(await File('/proc/self/cmdline').readAsBytes())
          .split('\u0000')
          .first;
  final stat = await File('/proc/self/stat').readAsString();
  final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
  return {'pid': pid, 'start_ticks': fields[19], 'command': command};
}

class _OfflineAdapter implements HttpClientAdapter {
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.origin);
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: const SocketException('Cold reopen forbids native HTTP.'),
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<BimViewerDocument> _document(
  BimOfflineService service,
  BimSavedSet saved,
) async {
  final models = <BimViewerModel>[];
  for (final id in saved.versionIds) {
    final local = await service.cachedVersion(id);
    expect(local, isNotNull);
    models.add(
      BimViewerModel.local(
        versionId: id,
        transform: saved.transforms[id]!.toJson(),
        source: BimViewerBinarySource(
          length: local!.length,
          mime: local.mime,
          read: (start, end) => local.geometry(start: start, end: end),
        ),
      ),
    );
  }
  return BimViewerDocument(
    modelSetRevisionId: saved.modelSetRevisionId,
    models: models,
  );
}

class _Viewer {
  _Viewer(this.controller, this.webview);
  final BimViewerController controller;
  final WebViewWidget? webview;
}

Future<Map<String, dynamic>> _inspect(_Viewer viewer) async {
  Object? value = await viewer.webview!.platform.params.controller
      .runJavaScriptReturningResult(
        "JSON.stringify({url:location.href,resources:performance.getEntriesByType('resource').map(x=>x.name),webgl2:!!document.querySelector('canvas')?.getContext('webgl2')})",
      );
  for (var depth = 0; depth < 3 && value is String; depth++) {
    value = jsonDecode(value);
  }
  if (value is! Map) {
    throw StateError('WebView diagnostics must decode to an object.');
  }
  return Map<String, dynamic>.from(value);
}

Future<_Viewer> _openViewer(
  WidgetTester tester,
  BimViewerDocument document,
  Dio api,
  Map<String, dynamic> proof, {
  bool expectFailure = false,
}) async {
  final controller = BimViewerController();
  var ready = false;
  final errors = <String>[];
  final subscription = controller.events.listen((event) {
    if (event['type'] == 'ready') ready = true;
  });
  final user =
      MostTestData.user()
        ..serverId = proof['user_id'] as int
        ..currentOrganizationId = proof['organization_id'] as int;
  await tester.pumpWidget(
    ProviderScope(
      overrides: mostCoreOverrides(
        selectedProject: MostTestData.project(id: proof['project_id'] as int),
        user: user,
        dio: api,
      ),
      child: MaterialApp(
        home: Scaffold(
          body: BimViewerSurface(
            document: document,
            controller: controller,
            onError: errors.add,
          ),
        ),
      ),
    ),
  );
  try {
    final watch = Stopwatch()..start();
    while (!ready &&
        errors.isEmpty &&
        watch.elapsed < const Duration(seconds: 90)) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(
      ready,
      !expectFailure,
      reason:
          'Real WebView must finish loading, or explicitly reject the damaged model.',
    );
    expect(errors, expectFailure ? isNotEmpty : isEmpty);
    return _Viewer(
      controller,
      expectFailure
          ? null
          : tester.widget<WebViewWidget>(find.byType(WebViewWidget)),
    );
  } catch (_) {
    await controller.dispose();
    rethrow;
  } finally {
    await subscription.cancel();
  }
}

Future<void> _closeViewer(WidgetTester tester, _Viewer viewer) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
  await _native(tester, viewer.controller.dispose);
}

Future<void> _corruptCiphertext(String path) async {
  final temporary = File('$path.corrupt');
  final sink = temporary.openWrite();
  var position = 0;
  await sink.addStream(
    File(path).openRead().map((chunk) {
      final bytes = Uint8List.fromList(chunk);
      if (position <= 36 && position + bytes.length > 36) {
        bytes[36 - position] ^= 1;
      }
      position += bytes.length;
      return bytes;
    }),
  );
  await sink.flush();
  await sink.close();
  expect(position, greaterThan(36));
  await temporary.rename(path);
}

Future<void> _checkPng(Uint8List bytes) async {
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, greaterThan(100));
      expect(frame.image.height, greaterThan(100));
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final colors = <int>{};
      for (var index = 0; index + 3 < pixels!.lengthInBytes; index += 64) {
        colors.add(pixels.getUint32(index));
      }
      expect(
        colors.length,
        greaterThan(3),
        reason: 'The PNG must contain rendered model pixels.',
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void _expectState(dynamic actual, dynamic expected, [String path = 'state']) {
  if (expected is num) {
    expect(actual, closeTo(expected.toDouble(), 0.001), reason: path);
  } else if (expected is Map) {
    expect(actual, isA<Map>(), reason: path);
    expect((actual as Map).keys, unorderedEquals(expected.keys), reason: path);
    for (final key in expected.keys) {
      _expectState(actual[key], expected[key], '$path.$key');
    }
  } else if (expected is List) {
    expect(actual, isA<List>(), reason: path);
    expect((actual as List).length, expected.length, reason: path);
    for (var index = 0; index < expected.length; index++) {
      _expectState(actual[index], expected[index], '$path[$index]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

Future<T> _native<T>(WidgetTester tester, Future<T> Function() action) async {
  Object? failure;
  StackTrace? failureStack;
  final result = await tester.runAsync<Object?>(() async {
    try {
      return await action().timeout(const Duration(minutes: 4));
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
      return null;
    }
  });
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack!);
  }
  return result as T;
}
