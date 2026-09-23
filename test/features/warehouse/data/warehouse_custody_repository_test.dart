import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_scan_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';

void main() {
  test('write-off sends a stable idempotency key with the operation', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return const <String, dynamic>{'success': true, 'data': {}};
    });

    await WarehouseRepository(dio).writeOff(
      warehouseId: 5,
      materialId: 19,
      quantity: 2,
      reason: 'Повреждение',
    );

    final payload = Map<String, dynamic>.from(request.data as Map);
    expect(request.path, '/warehouse/operations/write-off');
    expect(payload['warehouse_id'], 5);
    expect(payload['material_id'], 19);
    expect(payload['reason'], 'Повреждение');
    expect(payload['idempotency_key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(request.headers['Idempotency-Key'], payload['idempotency_key']);
  });

  test(
    'custody issue sends the same idempotency key in body and header',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return const <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{},
        };
      });

      await WarehouseRepository(dio).issueToResponsible(
        projectId: 10,
        projectWarehouseId: 20,
        materialId: 30,
        responsibleUserId: 40,
        quantity: 2.5,
      );

      final payload = Map<String, dynamic>.from(request.data as Map);
      expect(request.path, '/warehouse/custody/issue');
      expect(payload['idempotency_key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(request.headers['Idempotency-Key'], payload['idempotency_key']);
    },
  );

  test(
    'custody return queues the original idempotency key on network error',
    () async {
      final store = _MemorySyncQueueStore();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _NetworkErrorAdapter();
      final repository = WarehouseRepository(
        dio,
        syncQueueServiceFuture: Future.value(
          SyncQueueService(store: store, dio: dio),
        ),
      );

      await expectLater(
        repository.returnFromResponsible(
          projectId: 10,
          custodyWarehouseId: 21,
          materialId: 30,
          quantity: 1,
        ),
        throwsA(isA<SyncQueuedException>()),
      );

      final queued = (await store.all()).single;
      expect(queued.moduleSlug, 'warehouse');
      expect(queued.operationType, 'custody_return');
      expect(queued.endpoint, '/warehouse/custody/return');
      expect(queued.payload['idempotency_key'], isNotEmpty);
    },
  );

  test(
    'manual receipt sends the same idempotency key in body and header',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return const <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'movement_id': 101},
        };
      });

      await WarehouseRepository(dio).createReceipt(
        const WarehouseReceiptPayload(
          warehouseId: 10,
          materialId: 20,
          quantity: 2.5,
          price: 150,
          photos: <String>[],
        ),
      );

      final formData = request.data as FormData;
      final fields = <String, String>{
        for (final field in formData.fields) field.key: field.value,
      };
      expect(fields['idempotency_key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(request.headers['Idempotency-Key'], fields['idempotency_key']);
    },
  );

  test('manual transfer queues its idempotency key on network error', () async {
    final store = _MemorySyncQueueStore();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _NetworkErrorAdapter();
    final repository = WarehouseRepository(
      dio,
      syncQueueServiceFuture: Future.value(
        SyncQueueService(store: store, dio: dio),
      ),
    );

    await expectLater(
      repository.createTransfer(
        const WarehouseTransferPayload(
          fromWarehouseId: 10,
          toWarehouseId: 11,
          materialId: 20,
          quantity: 1,
        ),
      ),
      throwsA(isA<SyncQueuedException>()),
    );

    final queued = (await store.all()).single;
    expect(queued.operationType, 'create_transfer');
    expect(queued.endpoint, '/warehouse/operations/transfer');
    expect(
      queued.payload['idempotency_key'],
      matches(RegExp(r'^[0-9a-f-]{36}$')),
    );
  });

  test(
    'project delivery receipt queues its idempotency key on network error',
    () async {
      final store = _MemorySyncQueueStore();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _NetworkErrorAdapter();
      final repository = WarehouseRepository(
        dio,
        syncQueueServiceFuture: Future.value(
          SyncQueueService(store: store, dio: dio),
        ),
      );

      await expectLater(
        repository.receiveProjectMaterialDelivery(
          deliveryId: 42,
          quantity: 1.5,
          notes: 'Принято на объекте',
        ),
        throwsA(isA<SyncQueuedException>()),
      );

      final queued = (await store.all()).single;
      expect(queued.operationType, 'receive_project_delivery');
      expect(
        queued.endpoint,
        '/warehouse/project-material-deliveries/42/receive',
      );
      expect(
        queued.payload['idempotency_key'],
        matches(RegExp(r'^[0-9a-f-]{36}$')),
      );
    },
  );
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _NetworkErrorAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }
}

class _MemorySyncQueueStore implements SyncQueueStore {
  final _operations = <int, QueuedSyncOperation>{};
  var _nextId = 1;

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (operation.id == Isar.autoIncrement) {
      operation.id = _nextId++;
    }
    _operations[operation.id] = operation;
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async {
    final operations =
        _operations.values.toList()
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return operations;
  }

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async => all();

  @override
  Future<QueuedSyncOperation?> get(int id) async => _operations[id];

  @override
  Future<void> delete(int id) async {
    _operations.remove(id);
  }
}
