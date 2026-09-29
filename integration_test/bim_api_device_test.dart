import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prohelpers_mobile/core/network/mobile_api_response.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_repository.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_models.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_record.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_service.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_store.dart';
import 'package:prohelpers_mobile/features/design_management/offline/bim_offline_transport.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_viewer_surface.dart';

import '../test/helpers/mobile_integration_test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'actual API persists and syncs encrypted BIM offline draft',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final config = await _run(tester, _configuration);
      final projectId = _id(config, 'PROJECT_ID');
      final versionId = _id(config, 'VERSION_ID');
      final expressId = _id(config, 'EXPRESS_ID', fallback: 2863);
      final wallId = _id(config, 'WALL_EXPRESS_ID', fallback: 12954);
      final revisionId = _id(config, 'MODEL_SET_REVISION_ID', fallback: 0);
      final organizationId = _id(config, 'ORGANIZATION_ID');
      final userId = _id(config, 'USER_ID');
      final scope = '$userId:$organizationId';
      final network = _NetworkFaults();
      final api = _dio(config, 'BASE_URL', 'TOKEN')
        ..interceptors.add(network.interceptor);
      final downloads = Dio()..interceptors.add(network.interceptor);
      final admin = _dio(config, 'ADMIN_BASE_URL', 'ADMIN_TOKEN');
      addTearDown(() {
        api.close(force: true);
        downloads.close(force: true);
        admin.close(force: true);
      });
      final root = await _run(tester, () async {
        final temporary = await getTemporaryDirectory();
        return temporary.createTemp('bim-api-device-');
      });
      final isarName = 'bim-api-${DateTime.now().microsecondsSinceEpoch}';
      var isar = await _run(tester, () => _openIsar(root, isarName));
      final files = EncryptedLocalFileCache(
        keyStore: _IsolatedKeys(),
        directoryProvider: () async => root,
        temporaryDirectoryProvider: () async => root,
      );
      BimOfflineService service() => BimOfflineService(
        store: IsarBimOfflineStore(isar),
        files: files,
        transport: DioBimOfflineTransport(api, downloads: downloads),
        currentScope: () => scope,
        canUseOffline: () async => true,
        isOnline: () async => network.online,
        verifyOnline: () async => network.online,
      );
      var offline = service();
      addTearDown(() async {
        offline.dispose();
        if (isar.isOpen) await isar.close();
        expect(root.path, contains('/bim-api-device-'));
        if (await root.exists()) await root.delete(recursive: true);
      });
      final report = <String, dynamic>{
        'backend': 'actual opt-in Laravel API and canonical PostgreSQL test DB',
        'offline': 'Dio network rejection; local WebView loopback available',
        'keys':
            'isolated in-memory key store; production AES-GCM implementation',
        'isar_name': isarName,
      };
      binding.reportData = report;
      final repository = BimRepository(api);
      final catalog = await _run(tester, () => repository.versions(projectId));
      expect(catalog.items.any((version) => version.id == versionId), isTrue);
      final manifest = BimPackageManifest(
        await _run(tester, () => repository.offlinePackage(versionId)),
      );
      expect(manifest.projectId, projectId);
      expect(manifest.organizationId, organizationId);
      await _run(
        tester,
        () => offline.saveVersion(versionId, projectId: projectId),
      );
      expect((await _run(tester, offline.packages)).single.isReady, isTrue);
      final records = await _run(
        tester,
        () => IsarBimOfflineStore(isar).records(scope),
      );
      final package = records.singleWhere((record) => record.kind == 'package');
      for (final path in [package.encryptedPath, package.propertiesPath]) {
        expect(path.startsWith(root.path), isTrue);
        final header = await _run(tester, () async {
          final handle = await File(path).open();
          try {
            return await handle.read(8);
          } finally {
            await handle.close();
          }
        });
        expect(header, utf8.encode('MOSTENC1'));
      }
      offline.dispose();
      await _run(tester, () => isar.close());
      isar = await _run(tester, () => _openIsar(root, isarName));
      offline = service();
      network.online = false;
      final requestsBeforeOffline = network.requests.length;
      final local = await _run(tester, () => offline.cachedVersion(versionId));
      expect(local, isNotNull);
      final geometry = await _run(tester, () async {
        final result = BytesBuilder(copy: false);
        await for (final chunk in local!.geometry()) {
          result.add(chunk);
        }
        return result.takeBytes();
      });
      expect(sha256.convert(geometry).toString(), manifest.geometry.sha256);
      final properties = await _run(
        tester,
        () => offline.elementProperties(versionId, expressId),
      );
      expect(properties?['express_id'], expressId);
      final wall = await _run(
        tester,
        () => offline.elementProperties(versionId, wallId),
      );
      expect(wall?['express_id'], wallId);
      expect(
        await _run(tester, () => offline.elementProperties(versionId, 0)),
        isNull,
      );
      final controller = BimViewerController();
      addTearDown(controller.dispose);
      var ready = false;
      final errors = <String>[];
      final subscription = controller.events.listen((event) {
        if (event['type'] == 'ready') ready = true;
      });
      addTearDown(subscription.cancel);
      final user =
          MostTestData.user()
            ..serverId = userId
            ..currentOrganizationId = organizationId;
      await tester.pumpWidget(
        ProviderScope(
          overrides: mostCoreOverrides(
            selectedProject: MostTestData.project(id: projectId),
            user: user,
            dio: api,
          ),
          child: MaterialApp(
            home: Scaffold(
              body: BimViewerSurface(
                controller: controller,
                document: BimViewerDocument(
                  modelSetRevisionId: revisionId > 0 ? revisionId : null,
                  models: [
                    BimViewerModel.local(
                      versionId: versionId,
                      source: BimViewerBinarySource(
                        length: local!.length,
                        mime: local.mime,
                        read:
                            (start, end) =>
                                local.geometry(start: start, end: end),
                      ),
                    ),
                  ],
                ),
                onError: errors.add,
              ),
            ),
          ),
        ),
      );
      final watch = Stopwatch()..start();
      while (!ready && errors.isEmpty && watch.elapsed.inSeconds < 90) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(errors, isEmpty);
      expect(ready, isTrue);
      final state = await _run(tester, controller.getViewState);
      state['selection'] = [
        {'version_id': '$versionId', 'element_id': expressId},
      ];
      await _run(tester, () => controller.applyViewState(state));
      final frame = await _run(tester, controller.captureViewSnapshot);
      expect(frame.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final snapshotFile = File('${root.path}/snapshot.png');
      await _run(tester, () => snapshotFile.writeAsBytes(frame.bytes));
      await _run(tester, () => controller.setCameraPreset('top'));
      final photo = await _run(tester, controller.captureSnapshot);
      final photoFile = File('${root.path}/field-photo.png');
      await _run(tester, () => photoFile.writeAsBytes(photo));
      final title = 'Android BIM ${DateTime.now().microsecondsSinceEpoch}';
      const description =
          'Замечание сохранено без сети и отправлено с устройства.';
      final draft = await _run(
        tester,
        () => offline.createDraft(
          versionId: versionId,
          payload: {
            'project_id': projectId,
            'version_id': versionId,
            'title': title,
            'description': description,
            'severity': 'minor',
            'bim_element_id': '$expressId',
            'elements': [
              {'version_id': versionId, 'element_id': expressId},
            ],
            'camera': frame.viewState,
            if (revisionId > 0)
              'model_set_revision_id': revisionId
            else
              'view_models': [
                {
                  'version_id': versionId,
                  'transform': {
                    'shift': [0, 0, 0],
                    'rotation': 0,
                  },
                },
              ],
          },
          attachments: [
            BimDraftAttachmentInput(
              path: snapshotFile.path,
              filename: 'snapshot.png',
              mime: 'image/png',
              kind: 'snapshot',
            ),
            BimDraftAttachmentInput(
              path: photoFile.path,
              filename: 'field-photo.png',
              mime: 'image/png',
            ),
          ],
        ),
      );
      expect(draft.status, 'queued');
      expect(draft.attachments, hasLength(2));
      expect(draft.serverId, isNull);
      expect(network.requests.length, requestsBeforeOffline);
      await _run(tester, () => snapshotFile.delete());
      await _run(tester, () => photoFile.delete());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      offline.dispose();
      await _run(tester, () => isar.close());
      isar = await _run(tester, () => _openIsar(root, isarName));
      offline = service();
      final persisted = (await _run(tester, offline.drafts)).single;
      expect(persisted.localId, draft.localId);
      expect(persisted.payload['description'], description);
      expect(persisted.attachments, hasLength(2));
      report['encrypted_cache_and_draft_persist_after_reopen'] = true;
      report['cached_geometry_sha256'] = manifest.geometry.sha256;
      report['offline_properties_express_ids'] = [expressId, wallId];
      report['photo_source'] =
          'second rendered PNG; camera/gallery not exercised';
      debugPrint('BIM_API_DEVICE_PHASE offline_draft_persisted');

      network.online = true;
      network.dropCreateAcknowledgement = true;
      await _run(tester, offline.syncPending);
      final retryable = (await _run(tester, offline.drafts)).single;
      expect(retryable.status, 'queued');
      expect(retryable.attempted, isTrue);
      expect(network.createdBeforeLostAcknowledgement, greaterThan(0));
      await _run(tester, offline.syncPending);
      final completed = (await _run(tester, offline.drafts)).single;
      expect(completed.status, 'completed', reason: completed.lastError);
      expect(completed.serverId, network.createdBeforeLostAcknowledgement);
      final issueId = completed.serverId!;
      final mobileIssue = await _run(tester, () => repository.issue(issueId));
      expect(mobileIssue.description, description);
      expect(mobileIssue.photos, hasLength(1));
      expect(mobileIssue.photos.single['size_bytes'], photo.length);
      expect(mobileIssue.photos.single['mime_type'], 'image/png');
      expect(mobileIssue.snapshotUrl, isNotNull);
      final snapshotDownload = await _run(
        tester,
        () => downloads.get<List<int>>(
          mobileIssue.snapshotUrl.toString(),
          options: Options(responseType: ResponseType.bytes),
        ),
      );
      final photoDownload = await _run(
        tester,
        () => downloads.get<List<int>>(
          mobileIssue.photos.single['url'] as String,
          options: Options(responseType: ResponseType.bytes),
        ),
      );
      expect(
        sha256.convert(snapshotDownload.data!).toString(),
        sha256.convert(frame.bytes).toString(),
      );
      expect(
        sha256.convert(photoDownload.data!).toString(),
        sha256.convert(photo).toString(),
      );
      report['server_issue_id'] = issueId;
      report['actual_mobile_api_sync'] = true;
      report['snapshot_sha256'] = sha256.convert(frame.bytes).toString();
      report['photo_sha256'] = sha256.convert(photo).toString();
      debugPrint('BIM_API_DEVICE_PHASE mobile_sync_verified issue=$issueId');
      final adminResponse = await _run(
        tester,
        () => admin.get('/design-management/issues/$issueId'),
      );
      final adminIssue = MobileApiResponse.dataMap(adminResponse.data);
      expect(adminIssue['id'], issueId);
      expect(adminIssue['description'], description);
      expect(adminIssue['snapshot_url'], isNotNull);
      final context = adminIssue['context'] as Map;
      expect(context['camera'], frame.viewState);
      final adminViewResponse = await _run(
        tester,
        () => admin.get('/design-management/issues/$issueId/bim-context'),
      );
      final adminView = MobileApiResponse.dataMap(adminViewResponse.data);
      expect(adminView['camera'], frame.viewState);
      expect(adminView['elements'], [
        {'version_id': versionId, 'element_id': expressId},
      ]);
      expect(adminView['snapshot_url'], isNotNull);
      final creations =
          network.requests
              .where(
                (request) =>
                    request['method'] == 'POST' &&
                    request['path'] == '/design-management/project-issues',
              )
              .toList();
      expect(creations, hasLength(2));
      expect(creations.first['key'], creations.last['key']);
      final requestCount = network.requests.length;
      await _run(tester, offline.syncPending);
      expect(network.requests.length, requestCount);
      final issues = await _run(tester, () => repository.issues(projectId));
      expect(issues.items.where((issue) => issue.title == title), hasLength(1));
      final unchanged = await _run(tester, () => repository.issue(issueId));
      expect(unchanged.photos, hasLength(1));
      expect(unchanged.revision, mobileIssue.revision);
      report['server_issue_id'] = issueId;
      report['issue_id'] = issueId;
      report['client_operation_id'] = creations.first['key'];
      report['actual_api_sync_and_admin_visibility'] = true;
      report['lost_create_ack_idempotency_no_duplicate'] = true;
      report['snapshot_sha256'] = sha256.convert(frame.bytes).toString();
      report['photo_sha256'] = sha256.convert(photo).toString();
      final checks = <String, dynamic>{
        'actual_api_sync_and_admin_visibility': true,
        'lost_create_ack_idempotency_no_duplicate': true,
        'attachment_bytes_verified': true,
      };
      report['checks'] = checks;
      final controlUrl = config['BIM_API_CONTROL_URL'];
      if (controlUrl is String && controlUrl.isNotEmpty) {
        final control = Dio();
        try {
          await _run(
            tester,
            () => control.post(
              controlUrl,
              data: {
                'actor': 'mobile',
                'phase': 'apiComplete',
                'issue_id': issueId,
                'client_operation_id': creations.first['key'],
                'snapshot_sha256': report['snapshot_sha256'],
                'photo_sha256': report['photo_sha256'],
                'checks': checks,
              },
            ),
          );
        } finally {
          control.close(force: true);
        }
      }
      debugPrint('BIM_API_DEVICE_RESULT ${jsonEncode(report)}');
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<T> _run<T>(WidgetTester tester, Future<T> Function() action) async {
  T? result;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    try {
      result = await action().timeout(const Duration(seconds: 90));
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
  });
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack!);
  }
  return result as T;
}

Future<Isar> _openIsar(Directory directory, String name) => Isar.open(
  [BimOfflineRecordSchema, BimElementIndexSchema],
  directory: directory.path,
  name: name,
);

int _id(Map<String, dynamic> config, String key, {int? fallback}) {
  final value = config['BIM_API_$key'];
  final result = value is num ? value.toInt() : int.tryParse('$value');
  if (result != null) return result;
  if (fallback != null) return fallback;
  throw StateError('Missing BIM_API_$key test descriptor field.');
}

Dio _dio(Map<String, dynamic> config, String base, String token) {
  final baseUrl = '${config['BIM_API_$base'] ?? ''}';
  final uri = Uri.parse(baseUrl);
  expect(uri.scheme, 'http');
  expect(uri.host, '127.0.0.1');
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${config['BIM_API_$token']}',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
    ),
  );
}

Future<Map<String, dynamic>> _configuration() async {
  const url = String.fromEnvironment('BIM_API_CONFIG_URL');
  if (url.isNotEmpty) {
    final uri = Uri.parse(url);
    expect(uri.host, '127.0.0.1');
    final dio = Dio();
    try {
      final response = await dio.get<dynamic>(url);
      return Map<String, dynamic>.from(response.data as Map);
    } finally {
      dio.close(force: true);
    }
  }
  return {
    'BIM_API_BASE_URL': const String.fromEnvironment('BIM_API_BASE_URL'),
    'BIM_API_ADMIN_BASE_URL': const String.fromEnvironment(
      'BIM_API_ADMIN_BASE_URL',
    ),
    'BIM_API_TOKEN': const String.fromEnvironment('BIM_API_TOKEN'),
    'BIM_API_ADMIN_TOKEN': const String.fromEnvironment('BIM_API_ADMIN_TOKEN'),
    'BIM_API_USER_ID': const int.fromEnvironment('BIM_API_USER_ID'),
    'BIM_API_ORGANIZATION_ID': const int.fromEnvironment(
      'BIM_API_ORGANIZATION_ID',
    ),
    'BIM_API_PROJECT_ID': const int.fromEnvironment('BIM_API_PROJECT_ID'),
    'BIM_API_VERSION_ID': const int.fromEnvironment('BIM_API_VERSION_ID'),
    'BIM_API_EXPRESS_ID': const int.fromEnvironment(
      'BIM_API_EXPRESS_ID',
      defaultValue: 2863,
    ),
    'BIM_API_WALL_EXPRESS_ID': const int.fromEnvironment(
      'BIM_API_WALL_EXPRESS_ID',
      defaultValue: 12954,
    ),
    'BIM_API_MODEL_SET_REVISION_ID': const int.fromEnvironment(
      'BIM_API_MODEL_SET_REVISION_ID',
    ),
  };
}

class _IsolatedKeys implements SecureFileKeyStore {
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

class _NetworkFaults {
  bool online = true;
  bool dropCreateAcknowledgement = false;
  int? createdBeforeLostAcknowledgement;
  final requests = <Map<String, dynamic>>[];
  late final interceptor = InterceptorsWrapper(
    onRequest: (options, handler) {
      if (!online) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('BIM acceptance network disabled'),
          ),
        );
        return;
      }
      requests.add({
        'method': options.method,
        'path': options.path,
        'key': options.headers['Idempotency-Key'],
      });
      handler.next(options);
    },
    onResponse: (response, handler) {
      final options = response.requestOptions;
      if (dropCreateAcknowledgement &&
          options.method == 'POST' &&
          options.path == '/design-management/project-issues') {
        dropCreateAcknowledgement = false;
        createdBeforeLostAcknowledgement =
            MobileApiResponse.dataMap(response.data)['id'] as int;
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('BIM acceptance acknowledgement lost'),
          ),
        );
        return;
      }
      handler.next(response);
    },
  );
}
