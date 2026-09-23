import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/core/sync/isar_sync_queue_store.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_model.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_repository.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_snapshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'очередь переживает перезапуск, повторяет согласование и оригинал идемпотентно',
    (tester) async {
      final root = await getTemporaryDirectory();
      final directory = await Directory(
        '${root.path}/legal-queue-restart-test',
      ).create(recursive: true);
      const owner = '27:4:queue-session-a';
      var now = DateTime.utc(2026, 9, 23, 9);
      final keyStore = _MemoryKeyStore();
      final cache = EncryptedLocalFileCache(
        keyStore: keyStore,
        directoryProvider: () async => directory,
        temporaryDirectoryProvider: () async => directory,
      );
      final original = File('${directory.path}/paper-original.pdf');
      await original.writeAsBytes(List<int>.generate(120000, (i) => i % 251));
      var isar = await _openQueueIsar(directory.path);
      final offlineDio = _dio(_FakeAdapter((_) => _AdapterResult.network()));
      var currentIdentity = owner;

      try {
        var service = _queueService(
          isar: isar,
          adapter: _FakeAdapter((_) => _AdapterResult.network()),
          cache: cache,
          now: () => now,
          currentIdentity: () => currentIdentity,
        );
        var repository = _repository(
          offlineDio,
          service,
          cache,
          currentIdentity: () => currentIdentity,
        );
        await expectLater(
          repository.performAction(documentId: 81, action: _approveAction()),
          throwsA(isA<SyncQueuedException>()),
        );
        await expectLater(
          repository.uploadPaperOriginal(
            documentId: 81,
            signatureRequestId: 812,
            filePath: original.path,
            signedAt: DateTime.utc(2026, 9, 20),
            documentLockVersion: 12,
            idempotencyKey: 'paper-original-once',
          ),
          throwsA(isA<SyncQueuedException>()),
        );

        final queuedBeforeRestart = await service.all();
        expect(queuedBeforeRestart, hasLength(2));
        final staged =
            queuedBeforeRestart
                .singleWhere(
                  (operation) =>
                      operation.operationType == 'upload_paper_original',
                )
                .attachments
                .single;
        expect(staged.encrypted, isTrue);
        expect(await File(staged.path).exists(), isTrue);

        await isar.close();
        isar = await _openQueueIsar(directory.path);
        final server = _IdempotentLegalServer();
        service = _queueService(
          isar: isar,
          adapter: _FakeAdapter(server.handle),
          cache: cache,
          now: () => now,
          currentIdentity: () => currentIdentity,
        );

        final firstFlush = await service.retryDueOperations();
        expect(firstFlush.retryCount, 1);
        expect(server.approvalEffects, 1);
        final pendingApproval = (await service.all()).singleWhere(
          (operation) => operation.operationType == 'approve',
        );
        final approvalKey = pendingApproval.payload['idempotency_key'];
        expect(approvalKey, isA<String>());
        expect(pendingApproval.payload['queue_scope'], owner);
        expect(pendingApproval.payload['queue_owner_identity'], owner);

        now = now.add(const Duration(minutes: 2));
        final secondFlush = await service.retryDueOperations();
        expect(secondFlush.retryCount, 1);
        expect(server.approvalEffects, 1);
        expect(server.approvalRequests, 2);
        expect(server.paperEffects, 1);
        expect(server.paperRequests, 1);
        expect(server.approvalKeys.toSet(), {approvalKey});
        expect(server.paperKeys, ['paper-original-once']);
        expect(await service.all(), hasLength(1));

        now = now.add(const Duration(minutes: 2));
        final thirdFlush = await service.retryDueOperations();
        expect(thirdFlush.successCount, 1);
        expect(server.paperEffects, 1);
        expect(server.paperRequests, 2);
        expect(await service.all(), isEmpty);
        expect(await File(staged.path).exists(), isFalse);
      } finally {
        await isar.close(deleteFromDisk: true);
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    '409 и 403 блокируют queued action; смена identity запрещает отправку',
    (tester) async {
      final root = await getTemporaryDirectory();
      final directory = await Directory(
        '${root.path}/legal-queue-conflict-test',
      ).create(recursive: true);
      const owner = '27:4:queue-session-a';
      const otherOwner = '28:9:queue-session-b';
      final cache = EncryptedLocalFileCache(
        keyStore: _MemoryKeyStore(),
        directoryProvider: () async => directory,
        temporaryDirectoryProvider: () async => directory,
      );
      var currentIdentity = owner;
      var isar = await _openQueueIsar(directory.path);
      try {
        final store = IsarSyncQueueStore(isar);
        var service = _queueService(
          isar: isar,
          adapter: _FakeAdapter((_) => _AdapterResult.network()),
          cache: cache,
          currentIdentity: () => currentIdentity,
        );
        final repository = _repository(
          _dio(_FakeAdapter((_) => _AdapterResult.network())),
          service,
          cache,
          currentIdentity: () => currentIdentity,
        );
        await expectLater(
          repository.performAction(documentId: 90, action: _approveAction()),
          throwsA(isA<SyncQueuedException>()),
        );
        var operation = (await service.all()).single;

        service = _queueService(
          isar: isar,
          adapter: _FakeAdapter((_) => const _AdapterResult(statusCode: 409)),
          cache: cache,
          currentIdentity: () => currentIdentity,
        );
        await service.retryDueOperations();
        operation = (await store.get(operation.id))!;
        expect(operation.status, SyncOperationStatuses.conflict);
        expect(operation.payload['instance_lock_version'], 6);

        await store.delete(operation.id);
        final secondRepository = _repository(
          _dio(_FakeAdapter((_) => _AdapterResult.network())),
          service = _queueService(
            isar: isar,
            adapter: _FakeAdapter((_) => _AdapterResult.network()),
            cache: cache,
            currentIdentity: () => currentIdentity,
          ),
          cache,
          currentIdentity: () => currentIdentity,
        );
        await expectLater(
          secondRepository.performAction(
            documentId: 90,
            action: _approveAction(),
          ),
          throwsA(isA<SyncQueuedException>()),
        );
        operation = (await service.all()).single;

        var forbiddenRequests = 0;
        service = _queueService(
          isar: isar,
          adapter: _FakeAdapter((_) {
            forbiddenRequests++;
            return const _AdapterResult(statusCode: 403);
          }),
          cache: cache,
          currentIdentity: () => currentIdentity,
        );
        await service.retryDueOperations();
        operation = (await store.get(operation.id))!;
        expect(operation.status, SyncOperationStatuses.permissionDenied);
        expect(forbiddenRequests, 1);

        await store.delete(operation.id);
        final original = File('${directory.path}/pending-paper.pdf');
        await original.writeAsBytes([5, 8, 13, 21]);
        await expectLater(
          secondRepository.uploadPaperOriginal(
            documentId: 90,
            signatureRequestId: 901,
            filePath: original.path,
            signedAt: DateTime.utc(2026, 9, 20),
            documentLockVersion: 6,
            idempotencyKey: 'pending-paper-original',
          ),
          throwsA(isA<SyncQueuedException>()),
        );
        final pendingUpload = (await service.all()).single;
        final stagedPath = pendingUpload.attachments.single.path;
        expect(await File(stagedPath).exists(), isTrue);
        await expectLater(
          secondRepository.performAction(
            documentId: 90,
            action: _approveAction(),
          ),
          throwsA(isA<SyncQueuedException>()),
        );
        final beforeSwitch = await service.all();
        expect(beforeSwitch, hasLength(2));
        final idBeforeSwitch = beforeSwitch.first.id;
        currentIdentity = otherOwner;
        var crossIdentityRequests = 0;
        service = _queueService(
          isar: isar,
          adapter: _FakeAdapter((_) {
            crossIdentityRequests++;
            return const _AdapterResult(statusCode: 200);
          }),
          cache: cache,
          currentIdentity: () => currentIdentity,
        );
        await service.retryDueOperations();
        expect(crossIdentityRequests, 0);
        expect(
          (await store.get(idBeforeSwitch))?.status,
          SyncOperationStatuses.permissionDenied,
        );
        await service.clearScope(owner);
        expect(await store.all(), isEmpty);
        await cache.clearIdentity(owner);
        expect(await File(stagedPath).exists(), isFalse);
      } finally {
        await isar.close(deleteFromDisk: true);
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('офлайн-вход прекращается после 14 дней', (tester) async {
    final freshStorage = _MemorySecureStorage(
      confirmedAt: DateTime.now().toUtc().subtract(const Duration(days: 13)),
    );
    final fresh = AuthNotifier(
      _OfflineAuthRepository(freshStorage),
      freshStorage,
      autoCheckAuth: false,
    );
    await fresh.checkAuth();
    expect(fresh.state, isA<AuthAuthenticated>());
    expect((fresh.state as AuthAuthenticated).isOnlineVerified, isFalse);
    fresh.dispose();

    final expiredStorage = _MemorySecureStorage(
      confirmedAt: DateTime.now().toUtc().subtract(const Duration(days: 15)),
    );
    final expired = AuthNotifier(
      _OfflineAuthRepository(expiredStorage),
      expiredStorage,
      autoCheckAuth: false,
    );
    await expired.checkAuth();
    expect(expired.state, isA<AuthError>());
    expired.dispose();
  });
}

Future<Isar> _openQueueIsar(String directory) => Isar.open(
  [QueuedSyncOperationSchema, LegalDocumentSnapshotSchema],
  directory: directory,
  name: 'legal-queue-offline-integration',
);

SyncQueueService _queueService({
  required Isar isar,
  required HttpClientAdapter adapter,
  required EncryptedLocalFileCache cache,
  required String? Function() currentIdentity,
  DateTime Function()? now,
}) => SyncQueueService(
  store: IsarSyncQueueStore(isar),
  dio: _dio(adapter),
  now: now,
  currentScope: currentIdentity,
  onlineVerified: () => true,
  verifyOnline: () async => true,
  materializeAttachment:
      (attachment, owner) => cache.materialize(
        ownerIdentity: owner,
        encryptedPath: attachment.path,
        context: attachment.context ?? '',
        fileName: attachment.filename,
      ),
  deleteMaterializedAttachment: cache.deleteStagedUpload,
  deleteQueuedAttachment:
      (attachment) => cache.deleteStagedUpload(attachment.path),
);

LegalDocumentRepository _repository(
  Dio dio,
  SyncQueueService queue,
  EncryptedLocalFileCache cache, {
  required String? Function() currentIdentity,
}) => LegalDocumentRepository(
  dio,
  syncQueueService: () async => queue,
  currentOwnerIdentity: currentIdentity,
  fileCache: cache,
);

Dio _dio(HttpClientAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;

LegalDocumentAction _approveAction() => const LegalDocumentAction(
  action: 'approve',
  label: 'Согласовать',
  enabled: true,
  blockers: [],
  targetStepId: 701,
  expectedInstanceLockVersion: 6,
  expectedStepLockVersion: 3,
);

class _IdempotentLegalServer {
  final acceptedKeys = <String>{};
  final approvalKeys = <String>[];
  final paperKeys = <String>[];
  int approvalEffects = 0;
  int approvalRequests = 0;
  int paperEffects = 0;
  int paperRequests = 0;
  bool _lostApprovalReply = false;
  bool _lostPaperReply = false;

  _AdapterResult handle(RequestOptions options) {
    final key = options.headers['Idempotency-Key']?.toString() ?? '';
    if (options.path.endsWith('/actions/approve')) {
      approvalRequests++;
      approvalKeys.add(key);
      if (acceptedKeys.add(key)) approvalEffects++;
      if (!_lostApprovalReply) {
        _lostApprovalReply = true;
        return _AdapterResult.network();
      }
      return const _AdapterResult(statusCode: 200);
    }
    if (options.path.endsWith('/upload-original')) {
      paperRequests++;
      paperKeys.add(key);
      if (acceptedKeys.add(key)) paperEffects++;
      if (!_lostPaperReply) {
        _lostPaperReply = true;
        return _AdapterResult.network();
      }
      return const _AdapterResult(statusCode: 201);
    }
    throw StateError('unexpected_endpoint_${options.path}');
  }
}

class _AdapterResult {
  const _AdapterResult({required this.statusCode});

  const _AdapterResult.network() : statusCode = 0;

  final int statusCode;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final _AdapterResult Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) await requestStream.drain<void>();
    final result = handler(options);
    if (result.statusCode == 0) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'simulated_lost_response',
      );
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      result.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryKeyStore implements SecureFileKeyStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage({required DateTime confirmedAt})
    : offlineRecord = _offlineRecord(confirmedAt);

  Map<String, dynamic>? offlineRecord;

  static Map<String, dynamic> _offlineRecord(DateTime confirmedAt) => {
    'token': 'offline-token',
    'session_id': 'offline-session',
    'user_id': 27,
    'organization_id': 4,
    'confirmed_at': confirmedAt.toIso8601String(),
    'user': {
      'server_id': 27,
      'email': 'offline@example.test',
      'name': 'Offline User',
      'organization_id': 4,
      'organization_name': 'Организация',
      'organizations_json': '[]',
      'roles': <String>['organization_owner'],
      'permissions_json': '{}',
    },
  };

  @override
  Future<String?> getToken() async => 'offline-token';

  @override
  Future<Map<String, dynamic>?> getOfflineAuth() async => offlineRecord;

  @override
  Future<void> saveOfflineAuth(Map<String, dynamic> value) async {
    offlineRecord = value;
  }

  @override
  Future<void> clearToken() async {
    offlineRecord = null;
  }

  @override
  Future<void> clearOfflineAuth() async {
    offlineRecord = null;
  }
}

class _OfflineAuthRepository extends AuthRepository {
  _OfflineAuthRepository(SecureStorageService storage) : super(Dio(), storage);

  @override
  Future<User> getMe({String? token}) async {
    throw const ApiException('Сеть недоступна.');
  }
}
